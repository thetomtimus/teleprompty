import Foundation
import TeleprompterCore

@MainActor
final class AppEffectAdapter {
    private let snapshotStore: SnapshotStore
    private let overlayController: OverlayPanelController
    private weak var model: AppModel?
    private weak var controllerWindowController: ControllerWindowController?
    private let frameClockFactory: FrameClockFactory
    private let readerViewportProvider: @MainActor () -> ReaderViewport?
    private var scrollSession: ScrollSessionController?
    private weak var scrollSessionViewport: AnyObject?
    private var pendingViewportReplacementCapture: ScrollTerminalCapture?
    private var persistenceTask: Task<Void, Never>?
    private var persistenceGeneration: UInt64 = 0
    private var isTerminationDraining = false
    private var terminalFlushStarted = false
    private var terminalFlushSucceeded = false
    lazy var carbonHotKeyService = CarbonHotKeyService(
        registrar: CarbonHotKeyRegistrar(),
        dispatch: { [weak self] action in
            self?.model?.send(.performShortcut(action))
        }
    )
    #if DEBUG
    private var handleDepth = 0
    private(set) var maximumHandleDepth = 0
    private(set) var scrollSessionConstructionCount = 0
    var activeScrollSessionCount: Int { scrollSession == nil ? 0 : 1 }
    var scrollSessionForTesting: ScrollSessionController? { scrollSession }
    #endif
    private let terminationFlushOverride: (@Sendable () async -> Bool)?
    #if DEBUG
    private let diagnosticRecorder: DiagnosticEvidenceRecorder?
    #endif

    #if DEBUG
    convenience init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        diagnosticRecorder: DiagnosticEvidenceRecorder? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil,
        readerViewportProvider: (@MainActor () -> ReaderViewport?)? = nil,
        frameClockFactory: @escaping FrameClockFactory = { view, onTick in
            DisplayLinkFrameClock.make(attachedTo: view, onTick: onTick)
        }
    ) {
        self.init(
            snapshotStore: snapshotStore,
            overlayController: overlayController,
            diagnosticRecorderObject: diagnosticRecorder,
            terminationFlushOverride: terminationFlushOverride,
            readerViewportProvider: readerViewportProvider,
            frameClockFactory: frameClockFactory
        )
    }
    #else
    convenience init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil,
        frameClockFactory: @escaping FrameClockFactory = { view, onTick in
            DisplayLinkFrameClock.make(attachedTo: view, onTick: onTick)
        }
    ) {
        self.init(
            snapshotStore: snapshotStore,
            overlayController: overlayController,
            diagnosticRecorderObject: nil,
            terminationFlushOverride: terminationFlushOverride,
            readerViewportProvider: nil,
            frameClockFactory: frameClockFactory
        )
    }
    #endif

    private init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        diagnosticRecorderObject: AnyObject?,
        terminationFlushOverride: (@Sendable () async -> Bool)?,
        readerViewportProvider: (@MainActor () -> ReaderViewport?)?,
        frameClockFactory: @escaping FrameClockFactory
    ) {
        self.snapshotStore = snapshotStore
        self.overlayController = overlayController
        #if DEBUG
        diagnosticRecorder = diagnosticRecorderObject as? DiagnosticEvidenceRecorder
        #endif
        self.terminationFlushOverride = terminationFlushOverride
        self.frameClockFactory = frameClockFactory
        self.readerViewportProvider = readerViewportProvider ?? { [weak overlayController] in
            overlayController?.readerTextSystem.viewportAdapter
        }
    }

    func connect(model: AppModel, controller: ControllerWindowController) {
        self.model = model
        controllerWindowController = controller
        overlayController.readerTextSystem.onResyncRequested = { [weak model] revision in
            model?.send(.readerResyncRequested(appliedRevision: revision))
        }
        overlayController.onReaderAttachmentChanged = { [weak model] isAttached in
            model?.send(.readerAttachmentChanged(isAttached: isAttached))
        }
        overlayController.onReaderScreenChanged = { [weak model] in
            model?.send(.readerScreenChanged)
        }
        overlayController.onReaderBoundsWillChange = { [weak model] in
            model?.send(.readerBoundsWillChange)
        }
        overlayController.onReaderBoundsChanged = { [weak model] in
            model?.send(.readerBoundsChanged)
        }
        overlayController.onAppliedFrame = { [weak model] record in
            guard let displayID = record.displayID else { return }
            Task { @MainActor [weak model] in
                await Task.yield()
                model?.send(
                    .panelFrameChanged(
                        displayID: displayID,
                        frame: record.appliedFrame
                    ))
            }
        }
        overlayController.readerTextSystem.replaceAuthoritatively(
            text: model.document.text,
            revision: model.document.revision,
            reason: .initial
        )
        overlayController.readerTextSystem.updateAttributes(
            fontSize: model.preferences.fontSizePoints,
            alignment: model.preferences.textAlignment
        )
        overlayController.readerTextSystem.setActiveBandEnabled(
            model.preferences.isActiveBandEnabled
        )
    }

    func handle(_ effect: AppEffect) {
        #if DEBUG
        handleDepth += 1
        maximumHandleDepth = max(maximumHandleDepth, handleDepth)
        defer { handleDepth -= 1 }
        #endif
        #if DEBUG
        let correlationID = model?.diagnosticCorrelationID
        diagnosticRecorder?.record(
            kind: .effectApplyBefore,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(effect: effect.diagnosticName)
        )
        #endif
        switch effect {
        case .startScrollSession(let binding, let uptime):
            guard let session = session() else {
                model?.send(
                    .scrollTerminal(
                        ScrollTerminalResult(
                            generation: binding.generation,
                            reason: .clockUnavailable,
                            anchor: binding.anchor,
                            pixelOffset: binding.offset
                        )
                    )
                )
                break
            }
            let viewportBinding = bindingForCurrentViewport(binding)
            let restored = session.start(binding: viewportBinding, uptime: uptime)
            model?.send(
                .scrollMutationCompleted(
                    ScrollMutationResult(
                        generation: binding.generation,
                        anchor: restored.anchor,
                        pixelOffset: restored.offset,
                        outcome: .restored,
                        mayResume: false
                    )
                )
            )
        case .stopScrollSession(
            let retiring,
            let replacement,
            let reason,
            let fallbackAnchor,
            let fallbackOffset
        ):
            let capture = scrollSession?.stopAndCapture(
                retiring: retiring,
                replacement: replacement,
                reason: reason,
                fallbackAnchor: fallbackAnchor,
                fallbackOffset: fallbackOffset
            ) ?? ScrollTerminalCapture(
                retiringGeneration: retiring,
                replacementGeneration: replacement,
                reason: reason,
                anchor: fallbackAnchor,
                pixelOffset: fallbackOffset
            )
            model?.send(.scrollTerminalCapture(capture))
        case .updateScrollSpeed(let generation, let speed, let uptime):
            scrollSession?.setSpeed(
                generation: generation,
                pointsPerSecond: speed,
                uptime: uptime
            )
        case .moveScrollSession(let binding, let direction, let uptime):
            guard let session = session() else { break }
            if !session.isBound(to: binding.generation) {
                reconcileAndReport(binding, using: session)
            }
            session.move(
                generation: binding.generation,
                direction: direction,
                uptime: uptime
            )
        case .readerAttachmentChanged(let isAttached, let binding):
            guard isAttached else {
                invalidateViewportBoundSession()
                break
            }
            guard let session = session() else { break }
            reconcileAndReport(binding, using: session)
        case .readerScreenChanged(let binding), .restoreScrollLayout(let binding):
            guard let session = session() else { break }
            reconcileAndReport(binding, using: session)
        case .teardownScrollSession(let generation):
            scrollSession?.teardown(generation: generation)
            scrollSession = nil
            scrollSessionViewport = nil
            pendingViewportReplacementCapture = nil
        case .applyReaderEdit(
            let edit,
            let preEditDocument,
            let postEditDocument,
            let generation,
            let wasPlaying
        ):
            let result: ScrollMutationResult
            if let session = session() {
                if !session.isBound(to: generation) {
                    _ = session.reconcilePaused(
                        bindingForCurrentViewport(binding(
                            generation: generation,
                            anchor: model?.overlaySession.readingAnchor
                        ))
                    )
                }
                result = session.applyReaderEdit(
                    edit,
                    preEditDocument: preEditDocument,
                    postEditDocument: postEditDocument,
                    generation: generation,
                    readerSystem: overlayController.readerTextSystem,
                    wasPlaying: wasPlaying
                )
            } else {
                let prior = model?.overlaySession.readingAnchor ?? ReadingAnchor()
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
                overlayController.readerTextSystem.apply(edit)
                result = ScrollMutationResult(
                    generation: generation,
                    anchor: mapping.anchor,
                    pixelOffset: model?.overlaySession.pixelOffset ?? 0,
                    outcome: mapping.requiresPause ? .adjusted : .restored,
                    mayResume: false
                )
            }
            model?.send(.scrollMutationCompleted(result))
        case .replaceReader(let text, let revision, let reason, let generation, let anchor):
            overlayController.readerTextSystem.replaceAuthoritatively(
                text: text,
                revision: revision,
                reason: reason
            )
            if let viewport = overlayController.readerTextSystem.viewportAdapter {
                let restoredAnchor = anchor
                    ?? scrollSession?.lastTerminalCapture?.anchor
                    ?? model?.overlaySession.readingAnchor
                    ?? ReadingAnchor()
                let offset: Double
                if let session = session() {
                    let restored = session.reconcilePaused(
                        bindingForCurrentViewport(
                            binding(generation: generation, anchor: restoredAnchor)
                        )
                    )
                    offset = restored.offset
                } else {
                    viewport.ensureLayout()
                    offset = viewport.restore(anchor: restoredAnchor)
                }
                model?.send(
                    .scrollMutationCompleted(
                        ScrollMutationResult(
                            generation: generation,
                            anchor: restoredAnchor,
                            pixelOffset: offset,
                            outcome: .restored,
                            mayResume: false
                        )
                    )
                )
            }
        case .updateReaderAttributes(
            let fontSize,
            let alignment,
            let activeBandEnabled,
            let generation,
            let requestedAnchor
        ):
            overlayController.readerTextSystem.updateAttributes(
                fontSize: fontSize,
                alignment: alignment
            )
            overlayController.readerTextSystem.setActiveBandEnabled(activeBandEnabled)
            let restored: (anchor: ReadingAnchor, offset: Double)?
            if let requestedAnchor,
                let viewport = overlayController.readerTextSystem.viewportAdapter
            {
                if let session = session() {
                    restored = session.reconcilePaused(
                        bindingForCurrentViewport(
                            binding(generation: generation, anchor: requestedAnchor)
                        )
                    )
                } else {
                    viewport.ensureLayout()
                    restored = (requestedAnchor, viewport.restore(anchor: requestedAnchor))
                }
            } else {
                let restoredAnchor = scrollSession?.lastTerminalCapture?.anchor
                    ?? model?.overlaySession.readingAnchor
                if let restoredAnchor, let session = session() {
                    restored = session.reconcilePaused(
                        bindingForCurrentViewport(
                            binding(generation: generation, anchor: restoredAnchor)
                        )
                    )
                } else {
                    restored = nil
                }
            }
            if let restored {
                model?.send(
                    .scrollMutationCompleted(
                        ScrollMutationResult(
                            generation: generation,
                            anchor: restored.anchor,
                            pixelOffset: restored.offset,
                            outcome: .restored,
                            mayResume: false
                        )
                    )
                )
            }
        case .scheduleSnapshot(let snapshot):
            enqueuePersistence { store in
                try await store.scheduleSave(snapshot)
            }
        case .flushSnapshot(let token, let requiredRevision):
            enqueuePersistence { [weak self] store in
                do {
                    try await store.flush()
                    let status = await store.status()
                    let persistedRevision = status.persistedRevision ?? 0
                    await self?.completeClear(
                        token: token,
                        persistedRevision: persistedRevision,
                        succeeded: status.persistedRevision == requiredRevision
                    )
                } catch {
                    await self?.completeClear(
                        token: token,
                        persistedRevision: requiredRevision,
                        succeeded: false
                    )
                }
            }
        case .saveSnapshotImmediately(let snapshot):
            enqueuePersistence(allowDuringTermination: true) { store in
                try await store.scheduleSave(snapshot)
                try await store.flush()
            }
        case .flushPersistence:
            enqueuePersistence { store in
                try await store.flush()
            }
        case .reconfigureHotKeys(let bindings):
            model?.send(
                .hotKeyReconfigurationCompleted(
                    carbonHotKeyService.reconfigure(bindings)
                )
            )
        case .retryHotKeys:
            model?.send(
                .hotKeyReconfigurationCompleted(carbonHotKeyService.retry())
            )
        case .stagePanelHidden(let display, let proposedFrame):
            #if DEBUG
            recordPanelOperation(.stageHidden, correlationID: correlationID)
            #endif
            overlayController.stageHidden(
                proposedFrame: proposedFrame
                    ?? overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame,
                fullFrame: display.frame,
                displayID: display.id
            )
        case .showPanel(let display, let proposedFrame):
            #if DEBUG
            let operation: DiagnosticPanelOperationName =
                overlayController.orderingMode == .front
                ? .orderFront
                : .orderFrontRegardless
            recordPanelOperation(operation, correlationID: correlationID)
            #endif
            overlayController.show(
                proposedFrame: proposedFrame
                    ?? overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame,
                fullFrame: display.frame,
                displayID: display.id
            )
        case .hidePanel:
            #if DEBUG
            recordPanelOperation(.orderOut, correlationID: correlationID)
            #endif
            overlayController.hide()
        case .setPanelLocked(let locked):
            #if DEBUG
            recordPanelOperation(.setLocked, correlationID: correlationID)
            #endif
            overlayController.setLocked(locked)
        case .moveControllerWhileShielded(let display):
            controllerWindowController?.placeControllerWhileShielded(on: display)
            let model = model
            Task { @MainActor in
                await Task.yield()
                model?.send(.completeShieldedMove(screenID: display.id))
            }
        case .resetViewport(let generation):
            scrollSession?.restart(generation: generation)
            overlayController.readerTextSystem.viewportAdapter?.setClipOriginY(0)
        case .reassessPrivacy, .queryTopology, .evaluatePrivacy:
            break
        }
        #if DEBUG
        diagnosticRecorder?.record(
            kind: .effectApplyAfter,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(effect: effect.diagnosticName)
        )
        #endif
    }

    func flushForTermination() async -> Bool {
        // Reject new durable intent at the model boundary, but drain any completion
        // causally owned by an already-enqueued operation (notably pre-clear flush).
        // Each such completion synchronously extends `persistenceGeneration` before
        // its predecessor task returns, so the loop cannot miss its immediate save.
        isTerminationDraining = true

        while true {
            let observedGeneration = persistenceGeneration
            let observedTask = persistenceTask
            _ = await observedTask?.value
            await Task.yield()
            guard observedGeneration == persistenceGeneration else { continue }
            break
        }

        // This is the terminal barrier. `enqueuePersistence` refuses every later
        // operation once it is set, and this flush is appended after the stable tail.
        terminalFlushStarted = true
        let precedingTask = persistenceTask
        let snapshotStore = snapshotStore
        let terminationFlushOverride = terminationFlushOverride
        let expectedRevision = model?.snapshotRevision ?? 0
        persistenceGeneration += 1
        let terminalTask = Task { @MainActor [weak self] in
            _ = await precedingTask?.value
            let didFlush: Bool
            if let terminationFlushOverride {
                didFlush = await terminationFlushOverride()
            } else {
                do {
                    try await snapshotStore.flush()
                    let status = await snapshotStore.status()
                    didFlush =
                        status.persistedRevision == expectedRevision
                        || (expectedRevision == 0 && status.persistedRevision == nil)
                } catch {
                    didFlush = false
                }
            }
            self?.terminalFlushSucceeded = didFlush
        }
        persistenceTask = terminalTask
        _ = await terminalTask.value
        return terminalFlushSucceeded
    }

    private func session() -> ScrollSessionController? {
        guard let viewport = readerViewportProvider() else {
            invalidateViewportBoundSession()
            return nil
        }
        if let scrollSession,
            let scrollSessionViewport,
            scrollSessionViewport === (viewport as AnyObject)
        {
            return scrollSession
        }
        invalidateViewportBoundSession()
        let session = ScrollSessionController(
            viewport: viewport,
            clockFactory: frameClockFactory,
            onEvent: { [weak model] event in
                switch event {
                case .checkpoint(let checkpoint):
                    model?.send(.scrollCheckpoint(checkpoint))
                case .terminal(let result):
                    model?.send(.scrollTerminal(result))
                }
            }
        )
        scrollSession = session
        scrollSessionViewport = viewport
        #if DEBUG
        scrollSessionConstructionCount += 1
        #endif
        return session
    }

    private func invalidateViewportBoundSession() {
        if let capture = scrollSession?.invalidateForViewportReplacement() {
            pendingViewportReplacementCapture = capture
        }
        scrollSession = nil
        scrollSessionViewport = nil
    }

    private func bindingForCurrentViewport(
        _ binding: ScrollSessionBinding
    ) -> ScrollSessionBinding {
        guard let capture = pendingViewportReplacementCapture else { return binding }
        pendingViewportReplacementCapture = nil
        guard capture.replacementGeneration == binding.generation else { return binding }
        return ScrollSessionBinding(
            generation: binding.generation,
            anchor: capture.anchor,
            offset: capture.pixelOffset,
            speed: binding.speed
        )
    }

    private func binding(
        generation: ScrollSessionGeneration,
        anchor: ReadingAnchor?
    ) -> ScrollSessionBinding {
        ScrollSessionBinding(
            generation: generation,
            anchor: anchor ?? model?.overlaySession.readingAnchor ?? ReadingAnchor(),
            offset: model?.overlaySession.pixelOffset ?? 0,
            speed: model?.preferences.speedPointsPerSecond
                ?? TeleprompterPreferences.defaultSpeedPointsPerSecond
        )
    }

    private func reconcileAndReport(
        _ binding: ScrollSessionBinding,
        using session: ScrollSessionController
    ) {
        let restored = session.reconcilePaused(bindingForCurrentViewport(binding))
        model?.send(
            .scrollMutationCompleted(
                ScrollMutationResult(
                    generation: binding.generation,
                    anchor: restored.anchor,
                    pixelOffset: restored.offset,
                    outcome: .restored,
                    mayResume: false
                )
            )
        )
    }

    private func enqueuePersistence(
        allowDuringTermination: Bool = false,
        _ operation: @escaping @Sendable (SnapshotStore) async throws -> Void
    ) {
        guard
            !isTerminationDraining
                || (allowDuringTermination && !terminalFlushStarted)
        else { return }
        let precedingTask = persistenceTask
        let snapshotStore = snapshotStore
        persistenceGeneration += 1
        persistenceTask = Task { @MainActor in
            _ = await precedingTask?.value
            do {
                try await operation(snapshotStore)
            } catch {
                // SnapshotStore retains pending data for retry and exposes only
                // content-neutral diagnostics. No script content is surfaced here.
            }
        }
    }

    private func completeClear(
        token: ClearToken,
        persistedRevision: UInt64,
        succeeded: Bool
    ) {
        model?.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: persistedRevision,
                succeeded: succeeded
            ))
    }

    #if DEBUG
    private func recordPanelOperation(
        _ operation: DiagnosticPanelOperationName,
        correlationID: UUID?
    ) {
        diagnosticRecorder?.record(
            kind: .panelOperation,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(
                panelOperation: operation,
                panelState: overlayController.teleprompterPanel.diagnosticState
            )
        )
    }
    #endif
}

@MainActor
final class DependencyContainer {
    let snapshotStore: SnapshotStore
    let overlayController: OverlayPanelController
    let displayService: SystemDisplayService
    let effectAdapter: AppEffectAdapter
    #if DEBUG
    let diagnosticRecorder: DiagnosticEvidenceRecorder?
    #endif
    private(set) var appModelConstructionCount = 0

    #if DEBUG
    convenience init(
        proofLevel: OverlayPanelLevel,
        orderingMode: OverlayPanelOrderingMode = .frontRegardless,
        diagnosticRecorder: DiagnosticEvidenceRecorder? = nil,
        snapshotStore: SnapshotStore? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            proofLevel: proofLevel,
            orderingModeObject: orderingMode,
            diagnosticRecorderObject: diagnosticRecorder,
            snapshotStore: snapshotStore,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #else
    convenience init(
        proofLevel: OverlayPanelLevel,
        snapshotStore: SnapshotStore? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            proofLevel: proofLevel,
            orderingModeObject: nil,
            diagnosticRecorderObject: nil,
            snapshotStore: snapshotStore,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #endif

    private init(
        proofLevel: OverlayPanelLevel,
        orderingModeObject: Any?,
        diagnosticRecorderObject: AnyObject?,
        snapshotStore: SnapshotStore?,
        terminationFlushOverride: (@Sendable () async -> Bool)?
    ) {
        #if DEBUG
        let orderingMode =
            orderingModeObject as? OverlayPanelOrderingMode
            ?? .frontRegardless
        let diagnosticRecorder = diagnosticRecorderObject as? DiagnosticEvidenceRecorder
        #endif
        let resolvedStore: SnapshotStore
        if let snapshotStore {
            resolvedStore = snapshotStore
        } else if let productionStore = try? SnapshotStore.production() {
            resolvedStore = productionStore
        } else {
            // A path-resolution failure remains fail-closed: this unusable root
            // causes content-neutral load/save failures rather than alternate storage.
            resolvedStore = SnapshotStore(
                rootURL: URL(fileURLWithPath: "/dev/null/private-presenter-unavailable")
            )
        }

        self.snapshotStore = resolvedStore
        #if DEBUG
        self.diagnosticRecorder = diagnosticRecorder
        overlayController = OverlayPanelController(
            proofLevel: proofLevel,
            orderingMode: orderingMode,
            appliedFrameRecorder: { record in
                diagnosticRecorder?.record(
                    kind: .panelOperation,
                    payload: DiagnosticEventPayload(
                        panelOperation: .applyContainedFrame,
                        selectedFullFrame: DiagnosticRect(record.selectedFullFrame),
                        selectedVisibleFrame: DiagnosticRect(record.selectedVisibleFrame),
                        containmentFrame: DiagnosticRect(record.containmentFrame),
                        appliedFrame: DiagnosticRect(record.appliedFrame)
                    )
                )
            }
        )
        #else
        overlayController = OverlayPanelController(proofLevel: proofLevel)
        #endif
        displayService = SystemDisplayService()
        #if DEBUG
        effectAdapter = AppEffectAdapter(
            snapshotStore: resolvedStore,
            overlayController: overlayController,
            diagnosticRecorder: diagnosticRecorder,
            terminationFlushOverride: terminationFlushOverride
        )
        #else
        effectAdapter = AppEffectAdapter(
            snapshotStore: resolvedStore,
            overlayController: overlayController,
            terminationFlushOverride: terminationFlushOverride
        )
        #endif
    }

    func makeAppModel(restorationRequired: Bool = true) -> AppModel {
        appModelConstructionCount += 1
        let adapter = effectAdapter
        #if DEBUG
        return AppModel(
            overlayController: overlayController,
            restorationRequired: restorationRequired,
            diagnosticEvidenceRecorder: diagnosticRecorder,
            effectHandler: { [weak adapter] effect in
                adapter?.handle(effect)
            }
        )
        #else
        return AppModel(
            overlayController: overlayController,
            restorationRequired: restorationRequired,
            effectHandler: { [weak adapter] effect in
                adapter?.handle(effect)
            }
        )
        #endif
    }
}
