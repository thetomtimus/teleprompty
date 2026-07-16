import AppKit
import TeleprompterCore

enum ScrollRetirementReason: String, Equatable, Sendable {
    case commandPause
    case restart
    case hide
    case topology
    case privacy
    case clear
    case restore
    case readerEdit
    case readerReplacement
    case readerAttributes
    case resize
    case attachment
    case screenMove
    case resync
    case teardown
}

enum ScrollManualDirection: Equatable, Sendable {
    case backward
    case forward
}

struct ScrollSessionBinding: Equatable, Sendable {
    let generation: ScrollSessionGeneration
    let anchor: ReadingAnchor
    let offset: Double
    let speed: Double
}

struct ScrollCheckpoint: Equatable, Sendable {
    let generation: ScrollSessionGeneration
    let anchor: ReadingAnchor
    let pixelOffset: Double
    let uptime: TimeInterval
}

struct ScrollTerminalResult: Equatable, Sendable {
    let generation: ScrollSessionGeneration
    let reason: ScrollStopReason
    let anchor: ReadingAnchor
    let pixelOffset: Double
}

struct ScrollTerminalCapture: Equatable, Sendable {
    let retiringGeneration: ScrollSessionGeneration
    let replacementGeneration: ScrollSessionGeneration
    let reason: ScrollRetirementReason
    let anchor: ReadingAnchor
    let pixelOffset: Double
}

enum ScrollMutationOutcome: Equatable, Sendable {
    case restored
    case adjusted
    case failed
}

struct ScrollMutationResult: Equatable, Sendable {
    let generation: ScrollSessionGeneration
    let anchor: ReadingAnchor
    let pixelOffset: Double
    let outcome: ScrollMutationOutcome
    let mayResume: Bool
}

enum ScrollSessionEvent: Equatable, Sendable {
    case checkpoint(ScrollCheckpoint)
    case terminal(ScrollTerminalResult)
}

@MainActor
final class ScrollSessionController {
    private let viewport: ReaderViewport
    private let clockFactory: FrameClockFactory
    private let performanceRegistry: PerformanceIntervalRegistry
    private let onEvent: @MainActor (ScrollSessionEvent) -> Void
    private var engine = ScrollEngine()
    private var clock: FrameClock?
    private var currentGeneration: ScrollSessionGeneration?
    private var lastCheckpointUptime: TimeInterval?
    private var viewportFraction = 0.5
    private var didPublishTerminal = false
    private var scrollSessionInterval: PerformanceIntervalHandle?
    private(set) var lastTerminalCapture: ScrollTerminalCapture?

    init(
        viewport: ReaderViewport,
        clockFactory: @escaping FrameClockFactory = { view, onTick in
            DisplayLinkFrameClock.make(attachedTo: view, onTick: onTick)
        },
        performanceSignposter: any PerformanceSignposting = DisabledPerformanceSignposter(),
        performanceRegistry: PerformanceIntervalRegistry? = nil,
        onEvent: @escaping @MainActor (ScrollSessionEvent) -> Void
    ) {
        self.viewport = viewport
        self.clockFactory = clockFactory
        self.performanceRegistry = performanceRegistry
            ?? PerformanceIntervalRegistry(signposter: performanceSignposter)
        self.onEvent = onEvent
    }

    var isPlaying: Bool { engine.phase == .playing }

    @discardableResult
    func start(
        binding: ScrollSessionBinding,
        uptime: TimeInterval
    ) -> (anchor: ReadingAnchor, offset: Double) {
        guard binding.generation != currentGeneration else {
            return (binding.anchor, viewport.clipOriginY)
        }
        let reconciled = reconcilePaused(binding)
        didPublishTerminal = false
        lastCheckpointUptime = uptime
        scrollSessionInterval = performanceRegistry.begin(.scrollSession, reason: nil)
        _ = engine.apply(.start(at: uptime))
        guard let attachmentView = viewport.attachmentView else {
            publishClockUnavailable(generation: binding.generation)
            return reconciled
        }
        guard let newClock = clockFactory(
            attachmentView,
            { [weak self] timestamp in
                self?.receiveTick(timestamp, generation: binding.generation)
            }
        ) else {
            publishClockUnavailable(generation: binding.generation)
            return reconciled
        }
        clock = newClock
        return reconciled
    }

    @discardableResult
    func start(
        generation: ScrollSessionGeneration,
        offset: Double,
        speed: Double,
        uptime: TimeInterval,
        anchor: ReadingAnchor? = nil
    ) -> (anchor: ReadingAnchor, offset: Double) {
        start(
            binding: ScrollSessionBinding(
                generation: generation,
                anchor: anchor ?? ReadingAnchor(viewportFraction: viewportFraction),
                offset: offset,
                speed: speed
            ),
            uptime: uptime
        )
    }

    func isBound(to generation: ScrollSessionGeneration) -> Bool {
        currentGeneration == generation
    }

    @discardableResult
    func reconcilePaused(
        _ binding: ScrollSessionBinding
    ) -> (anchor: ReadingAnchor, offset: Double) {
        endScrollSession(outcome: .cancelled)
        invalidateClock()
        _ = engine.apply(.pause)
        let generationChanged = currentGeneration != binding.generation
        viewport.ensureLayout()
        let anchor = lastTerminalCapture.flatMap { capture in
            capture.replacementGeneration == binding.generation ? capture.anchor : nil
        } ?? (generationChanged && currentGeneration != nil
            ? viewport.captureAnchor(viewportFraction: viewportFraction)
            : binding.anchor)
        viewportFraction = anchor.viewportFraction
        let restoredOffset = viewport.restore(anchor: anchor)
        let fallbackOffset = binding.offset.isFinite ? max(binding.offset, 0) : 0
        let offset = restoredOffset.isFinite ? max(restoredOffset, 0) : fallbackOffset
        if viewport.clipOriginY != offset {
            viewport.setClipOriginY(offset)
        }
        engine = ScrollEngine(
            offset: offset,
            speedPointsPerSecond: binding.speed,
            maximumOffset: viewport.maximumOffset
        )
        currentGeneration = binding.generation
        didPublishTerminal = false
        lastTerminalCapture = nil
        if generationChanged {
            lastCheckpointUptime = nil
        }
        return (anchor, offset)
    }

    @discardableResult
    func reconcilePaused(
        generation: ScrollSessionGeneration,
        anchor: ReadingAnchor,
        offset: Double,
        speed: Double
    ) -> (anchor: ReadingAnchor, offset: Double) {
        reconcilePaused(
            ScrollSessionBinding(
                generation: generation,
                anchor: anchor,
                offset: offset,
                speed: speed
            )
        )
    }

    @discardableResult
    func stopAndCapture(
        retiring: ScrollSessionGeneration,
        replacement: ScrollSessionGeneration,
        reason: ScrollRetirementReason,
        fallbackAnchor: ReadingAnchor = ReadingAnchor(),
        fallbackOffset: Double = 0
    ) -> ScrollTerminalCapture {
        let anchor: ReadingAnchor
        let offset: Double
        if currentGeneration == retiring {
            anchor = viewport.captureAnchor(viewportFraction: viewportFraction)
            offset = viewport.clipOriginY
            _ = engine.apply(.pause)
        } else {
            anchor = fallbackAnchor
            offset = fallbackOffset
        }
        invalidateClock()
        endScrollSession(outcome: .success)
        currentGeneration = replacement
        didPublishTerminal = true
        lastCheckpointUptime = nil
        let capture = ScrollTerminalCapture(
            retiringGeneration: retiring,
            replacementGeneration: replacement,
            reason: reason,
            anchor: anchor,
            pixelOffset: offset
        )
        lastTerminalCapture = capture
        return capture
    }

    func setSpeed(
        generation: ScrollSessionGeneration,
        pointsPerSecond: Double,
        uptime: TimeInterval
    ) {
        guard generation == currentGeneration else { return }
        apply(
            engine.apply(.setSpeed(pointsPerSecond: pointsPerSecond, at: uptime)),
            uptime: uptime,
            generation: generation
        )
    }

    func move(
        generation: ScrollSessionGeneration,
        direction: ScrollManualDirection,
        uptime: TimeInterval
    ) {
        guard generation == currentGeneration else { return }
        let distance = viewport.threeCompleteLineStep()
        let points = direction == .forward ? distance : -distance
        let transition = engine.apply(.moveBy(points: points, at: uptime))
        apply(
            transition,
            uptime: uptime,
            generation: generation
        )
        if engine.phase == .paused,
            transition.didChangeOffset,
            transition.stopReason == nil
        {
            publishCheckpointIfDue(uptime: uptime, generation: generation)
        }
    }

    func attachmentDidChange(generation: ScrollSessionGeneration) {
        suspend(generation: generation)
    }

    func screenDidChange(generation: ScrollSessionGeneration) {
        suspend(generation: generation)
    }

    func restoreLastCapture() -> (anchor: ReadingAnchor, offset: Double)? {
        guard let capture = lastTerminalCapture else { return nil }
        return restore(anchor: capture.anchor)
    }

    func restore(anchor: ReadingAnchor) -> (anchor: ReadingAnchor, offset: Double) {
        viewport.ensureLayout()
        viewportFraction = anchor.viewportFraction
        let offset = viewport.restore(anchor: anchor)
        engine = ScrollEngine(
            offset: offset,
            speedPointsPerSecond: engine.speedPointsPerSecond,
            maximumOffset: viewport.maximumOffset
        )
        return (anchor, offset)
    }

    func applyReaderEdit(
        _ edit: ScriptTextEdit,
        preEditDocument: String,
        postEditDocument: String,
        generation: ScrollSessionGeneration,
        readerSystem: ReaderTextSystem,
        wasPlaying: Bool
    ) -> ScrollMutationResult {
        let prior = lastTerminalCapture?.anchor
            ?? viewport.captureAnchor(viewportFraction: viewportFraction)
        let mapping = ReadingPositionMapper.map(
            anchor: prior,
            editedRangeUTF16: NSRange(
                location: edit.range.location,
                length: edit.range.length
            ),
            replacement: edit.replacement,
            preEditDocument: preEditDocument,
            postEditDocument: postEditDocument
        )
        readerSystem.apply(edit)
        let offset = restore(anchor: mapping.anchor).offset
        lastTerminalCapture = nil
        let succeeded = readerSystem.textStorage.string == postEditDocument
        return ScrollMutationResult(
            generation: generation,
            anchor: mapping.anchor,
            pixelOffset: offset,
            outcome: succeeded
                ? (mapping.requiresPause ? .adjusted : .restored)
                : .failed,
            mayResume: succeeded && wasPlaying && !mapping.requiresPause
        )
    }

    func teardown(generation: ScrollSessionGeneration) {
        guard generation == currentGeneration else { return }
        endScrollSession(outcome: .cancelled)
        invalidateClock()
        _ = engine.apply(.suspend(.explicitSuspension))
        currentGeneration = nil
        lastTerminalCapture = nil
        lastCheckpointUptime = nil
    }

    @discardableResult
    func invalidateForViewportReplacement() -> ScrollTerminalCapture? {
        let capture = lastTerminalCapture
        endScrollSession(outcome: .cancelled)
        invalidateClock()
        _ = engine.apply(.suspend(.explicitSuspension))
        currentGeneration = nil
        lastTerminalCapture = nil
        lastCheckpointUptime = nil
        return capture
    }

    func restart(generation: ScrollSessionGeneration) {
        guard generation == currentGeneration else { return }
        endScrollSession(outcome: .cancelled)
        invalidateClock()
        _ = engine.apply(.restart)
        viewport.setClipOriginY(0)
        lastTerminalCapture = nil
        lastCheckpointUptime = nil
    }

    private func suspend(generation: ScrollSessionGeneration) {
        guard generation == currentGeneration else { return }
        endScrollSession(outcome: .cancelled)
        invalidateClock()
        _ = engine.apply(.suspend(.explicitSuspension))
        lastCheckpointUptime = nil
    }

    private func receiveTick(
        _ uptime: TimeInterval,
        generation: ScrollSessionGeneration
    ) {
        guard generation == currentGeneration, engine.phase == .playing else { return }
        let tickInterval = performanceRegistry.isEnabled
            ? performanceRegistry.begin(.scrollTick, reason: nil) : nil
        defer { performanceRegistry.end(tickInterval, outcome: .success) }
        apply(engine.apply(.tick(at: uptime)), uptime: uptime, generation: generation)
    }

    private func apply(
        _ transition: ScrollTransition,
        uptime: TimeInterval,
        generation: ScrollSessionGeneration
    ) {
        if transition.didChangeOffset {
            viewport.setClipOriginY(transition.offset)
        }
        if let reason = transition.stopReason {
            publishTerminal(reason: reason, generation: generation)
            return
        }
        guard engine.phase == .playing else { return }
        publishCheckpointIfDue(uptime: uptime, generation: generation)
    }

    private func publishCheckpointIfDue(
        uptime: TimeInterval,
        generation: ScrollSessionGeneration
    ) {
        guard generation == currentGeneration, uptime.isFinite else { return }
        if let lastCheckpointUptime {
            guard uptime >= lastCheckpointUptime,
                uptime - lastCheckpointUptime >= 1
            else { return }
        }
        lastCheckpointUptime = uptime
        publishCheckpoint(uptime: uptime, generation: generation)
    }

    private func publishCheckpoint(
        uptime: TimeInterval,
        generation: ScrollSessionGeneration
    ) {
        onEvent(
            .checkpoint(
                ScrollCheckpoint(
                    generation: generation,
                    anchor: viewport.captureAnchor(
                        viewportFraction: viewportFraction
                    ),
                    pixelOffset: viewport.clipOriginY,
                    uptime: uptime
                )
            )
        )
    }

    private func publishClockUnavailable(generation: ScrollSessionGeneration) {
        _ = engine.apply(.suspend(.clockUnavailable))
        publishTerminal(reason: .clockUnavailable, generation: generation)
    }

    private func publishTerminal(
        reason: ScrollStopReason,
        generation: ScrollSessionGeneration
    ) {
        guard !didPublishTerminal else { return }
        didPublishTerminal = true
        endScrollSession(
            outcome: reason == .clockUnavailable ? .failure : .success
        )
        let anchor = viewport.captureAnchor(viewportFraction: viewportFraction)
        let offset = viewport.clipOriginY
        invalidateClock()
        lastCheckpointUptime = nil
        onEvent(
            .terminal(
                ScrollTerminalResult(
                    generation: generation,
                    reason: reason,
                    anchor: anchor,
                    pixelOffset: offset
                )
            )
        )
    }

    private func invalidateClock() {
        clock?.invalidate()
        clock = nil
    }

    private func endScrollSession(outcome: PerformanceSignpostOutcome) {
        performanceRegistry.end(scrollSessionInterval, outcome: outcome)
        scrollSessionInterval = nil
    }

    deinit {
        clock?.invalidate()
        performanceRegistry.end(scrollSessionInterval, outcome: .cancelled)
    }
}
