import AppKit
import Foundation
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class PerformanceSignposterTests: XCTestCase {
    func testSignpostIntervalsBalanceForEveryTerminalPath() throws {
        let recorder = M5PerformanceRecorder()
        let registry = PerformanceIntervalRegistry(signposter: recorder)
        let terminals: [(
            operation: PerformanceSignpostOperation,
            reason: PerformanceSignpostReason?,
            outcome: PerformanceSignpostOutcome
        )] = [
            (.restoreToInteractive, .initial, .success),
            (.readerLayout, .restore, .failure),
            (.editToVisible, nil, .cancelled),
            (.editToVisible, nil, .failure),       // rejected edit
            (.readerLayout, .resync, .success),   // resync completion
            (.snapshotWrite, .debounced, .cancelled), // superseded save
        ]

        for terminal in terminals {
            let handle = try XCTUnwrap(
                registry.begin(terminal.operation, reason: terminal.reason)
            )
            registry.end(handle, outcome: terminal.outcome)
        }
        _ = registry.begin(.scrollSession, reason: nil)
        registry.cancelAll() // teardown owns the final cancellation edge

        let viewport = M5PerformanceViewport()
        let clockFactory = M5PerformanceFrameClockFactory()
        var publishedEvents: [ScrollSessionEvent] = []
        let session = ScrollSessionController(
            viewport: viewport,
            clockFactory: clockFactory.make,
            performanceSignposter: recorder,
            onEvent: { publishedEvents.append($0) }
        )
        let generation = ScrollSessionGeneration()
        _ = session.start(
            binding: ScrollSessionBinding(
                generation: generation,
                anchor: ReadingAnchor(viewportFraction: 0.5),
                offset: 0,
                speed: 60
            ),
            uptime: 0
        )
        let textMutationCount = viewport.textMutationCount
        let layoutCount = viewport.ensureLayoutCount
        let attributedRebuildCount = viewport.attributedRebuildCount
        clockFactory.latest?.fire(at: 0.05)
        session.teardown(generation: generation)

        XCTAssertTrue(publishedEvents.isEmpty, "A sub-second real tick must not publish")
        XCTAssertEqual(viewport.textMutationCount, textMutationCount)
        XCTAssertEqual(viewport.ensureLayoutCount, layoutCount)
        XCTAssertEqual(viewport.attributedRebuildCount, attributedRebuildCount)
        XCTAssertEqual(registry.openIntervalCount, 0)
        XCTAssertTrue(recorder.openTokens.isEmpty)
        XCTAssertEqual(recorder.beginCount, recorder.endCount)
        XCTAssertTrue(recorder.completedOperations.contains(.scrollSession))
        XCTAssertTrue(recorder.completedOperations.contains(.scrollTick))
        XCTAssertFalse(
            recorder.completedOperations.contains {
                $0 == .snapshotEncode || $0 == .snapshotWrite || $0 == .snapshotFlush
            },
            "A frame callback must not enqueue persistence"
        )
    }

    func testSignpostAPIHasNoArbitraryMetadataSurface() throws {
        let interface = try source(
            "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift"
        )
        let service = try source(
            "PrivatePresenterApp/Services/PerformanceSignposter.swift"
        )
        let protocolSource = try XCTUnwrap(
            interface.range(of: "protocol PerformanceSignposting")
        ).lowerBound
        let typedSurface = String(interface[protocolSource...])

        for forbidden in [
            "metadata:", "[String:", "[String :", "Any...", "CVarArg",
            "String(describing:", "error:", "path:", "url:", "revision:",
            "count:", "size:", "userID:",
        ] {
            XCTAssertFalse(typedSurface.contains(forbidden), forbidden)
        }
        XCTAssertTrue(typedSurface.contains("PerformanceSignpostOperation"))
        XCTAssertTrue(typedSurface.contains("PerformanceSignpostOutcome"))
        XCTAssertTrue(typedSurface.contains("PerformanceSignpostReason"))

        let osBoundaryFiles = try productionSwiftFiles().filter { path in
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            return contents.contains("import OS")
                || contents.contains("OSSignposter")
                || contents.contains("OSSignpostIntervalState")
        }
        XCTAssertEqual(
            osBoundaryFiles.map(relativePath).sorted(),
            ["PrivatePresenterApp/Services/PerformanceSignposter.swift"]
        )
        XCTAssertTrue(service.contains("static let subsystem"))

        for forbiddenPath in [
            "PrivatePresenterApp/App/AppEffect.swift",
            "PrivatePresenterApp/App/AppModel.swift",
            "PrivatePresenterApp/Services/SnapshotStore.swift",
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift",
        ] {
            let contents = try source(forbiddenPath)
            XCTAssertFalse(contents.contains("PerformanceSignpostToken"), forbiddenPath)
            XCTAssertFalse(contents.contains("PerformanceIntervalToken"), forbiddenPath)
        }
    }

    func testSignpostNamesAndClosedMetadataAreExact() {
        XCTAssertEqual(PerformanceSignposter.subsystem, "com.privatepresenter.teleprompter")
        XCTAssertEqual(
            PerformanceSignpostCategory.allCases.map(\.rawValue),
            ["load", "layout", "edit", "scroll", "persistence"]
        )
        XCTAssertEqual(
            PerformanceSignpostOperation.allCases.map(\.rawValue),
            [
                "restore-to-interactive", "reader-layout", "edit-to-visible",
                "scroll-session", "scroll-tick", "snapshot-encode",
                "snapshot-write", "snapshot-flush",
            ]
        )
        XCTAssertEqual(
            PerformanceSignpostOperation.allCases.map(\.category),
            [
                .load, .layout, .edit, .scroll, .scroll,
                .persistence, .persistence, .persistence,
            ]
        )
        XCTAssertEqual(
            PerformanceSignpostOutcome.allCases.map(\.rawValue),
            ["success", "failure", "cancelled"]
        )
        XCTAssertEqual(
            PerformanceSignpostReason.allCases.map(\.rawValue),
            ["initial", "restore", "resync", "debounced", "flush"]
        )
    }

    func testSignpostPayloadsNeverContainPrivateSentinels() throws {
        let recorder = M5PerformanceRecorder()
        let registry = PerformanceIntervalRegistry(signposter: recorder)
        for (index, operation) in PerformanceSignpostOperation.allCases.enumerated() {
            let reasons = PerformanceSignpostReason.allCases
            let handle = try XCTUnwrap(
                registry.begin(operation, reason: reasons[index % reasons.count])
            )
            registry.end(handle, outcome: .success)
        }

        let payload = recorder.closedVocabulary.joined(separator: "|")
        for sentinel in [
            "SENTINEL_PRIVATE_SCRIPT", "SENTINEL_PRIVATE_TITLE",
            "SENTINEL_PRIVATE_SELECTION", "SENTINEL_PRIVATE_DISPLAY",
            "/Users/private/Library/Application Support", "file://",
            "revision=", "count=", "size=", "user-id", "NSError",
        ] {
            XCTAssertFalse(payload.contains(sentinel), sentinel)
        }
        let allowedVocabulary = Set(
            PerformanceSignpostOperation.allCases.map(\.rawValue)
                + PerformanceSignpostCategory.allCases.map(\.rawValue)
                + PerformanceSignpostOutcome.allCases.map(\.rawValue)
                + PerformanceSignpostReason.allCases.map(\.rawValue)
        )
        XCTAssertTrue(Set(recorder.closedVocabulary).isSubset(of: allowedVocabulary))
        XCTAssertEqual(
            Set(recorder.completedOperations.map(\.rawValue)),
            Set(PerformanceSignpostOperation.allCases.map(\.rawValue))
        )
    }

    func testRestoreIntervalEndsAfterReaderLayoutAndMainActorSentinel() async throws {
        let recorder = M5PerformanceRecorder()
        let registry = PerformanceIntervalRegistry(signposter: recorder)
        let gate = RestoreInteractivePerformanceGate(registry: registry)

        gate.begin(reason: .restore)
        XCTAssertEqual(recorder.openOperations, [.restoreToInteractive])
        gate.restoreCompleted()
        gate.readerAttached()
        XCTAssertTrue(recorder.completedOperations.isEmpty)
        gate.readerFirstLayoutCompleted()
        XCTAssertTrue(recorder.completedOperations.isEmpty)

        await gate.completeAfterMainActorSentinel()

        XCTAssertEqual(recorder.completedOperations, [.restoreToInteractive])
        XCTAssertEqual(recorder.lastOutcome, .success)
        XCTAssertEqual(registry.openIntervalCount, 0)
    }

    func testEditIntervalEndsAfterIncrementalReaderLayout() throws {
        let recorder = M5PerformanceRecorder()
        let root = URL(fileURLWithPath: "/tmp/private-presenter-m5-signpost-edit")
        let store = SnapshotStore(
            rootURL: root,
            fileSystem: M5PerformanceSnapshotFileSystem(),
            sleeper: M5ImmediateCancellationSnapshotSleeper(),
            performanceSignposter: recorder
        )
        let overlay = OverlayPanelController()
        let viewport = M5PerformanceViewport()
        let clocks = M5PerformanceFrameClockFactory()
        let adapter = AppEffectAdapter(
            snapshotStore: store,
            overlayController: overlay,
            performanceSignposter: recorder,
            readerViewportProvider: { viewport },
            frameClockFactory: clocks.make
        )
        let model = AppModel(
            overlayController: overlay,
            restorationRequired: false,
            effectHandler: adapter.handle
        )
        let controller = ControllerWindowController(model: model)
        adapter.connect(model: model, controller: controller)
        var stateAtEditEnd: (incrementalMutations: Int, layoutCount: Int)?
        recorder.onEnd = { operation in
            guard operation == .editToVisible else { return }
            stateAtEditEnd = (
                overlay.readerTextSystem.incrementalMutationCount,
                viewport.ensureLayoutCount
            )
        }
        let editor = EditorTextSystem(text: "base", revision: 0) { edit in
            model.send(.applyScriptEdit(edit))
        }

        editor.replaceCharactersForTesting(
            in: NSRange(location: 4, length: 0),
            with: " edit"
        )

        let edge = try XCTUnwrap(stateAtEditEnd)
        XCTAssertEqual(overlay.readerTextSystem.textStorage.string, "base edit")
        XCTAssertEqual(edge.incrementalMutations, 1)
        XCTAssertGreaterThan(edge.layoutCount, 0)
        XCTAssertEqual(recorder.outcomes(for: .editToVisible), [.success])
        XCTAssertTrue(recorder.openTokens.isEmpty)
    }

    func testDebounceWaitIsOutsidePersistenceIntervals() async throws {
        let recorder = M5PerformanceRecorder()
        let sleeper = M5SuspendedSnapshotSleeper()
        let fileSystem = M5PerformanceSnapshotFileSystem()
        let store = SnapshotStore(
            rootURL: URL(fileURLWithPath: "/tmp/private-presenter-m5-signpost-debounce"),
            fileSystem: fileSystem,
            sleeper: sleeper,
            performanceSignposter: recorder
        )

        try await store.scheduleSave(snapshot(revision: 1))
        await sleeper.waitUntilEntered()

        XCTAssertEqual(recorder.completedOperations, [.snapshotEncode])
        XCTAssertTrue(recorder.openTokens.isEmpty)
        XCTAssertEqual(fileSystem.atomicCommitCount, 0)
        await sleeper.cancel()
    }

    func testSnapshotEncodeWriteAndFlushAreSeparateIntervals() async throws {
        let recorder = M5PerformanceRecorder()
        let fileSystem = M5PerformanceSnapshotFileSystem()
        let store = SnapshotStore(
            rootURL: URL(fileURLWithPath: "/tmp/private-presenter-m5-signpost-flush"),
            fileSystem: fileSystem,
            sleeper: M5ImmediateCancellationSnapshotSleeper(),
            performanceSignposter: recorder
        )

        try await store.scheduleSave(snapshot(revision: 2))
        try await store.flush()

        XCTAssertEqual(
            recorder.events.map(\.edge),
            [
                .begin(.snapshotEncode), .end(.snapshotEncode),
                .begin(.snapshotFlush), .begin(.snapshotWrite),
                .end(.snapshotWrite), .end(.snapshotFlush),
            ]
        )
        XCTAssertEqual(recorder.outcomes(for: .snapshotEncode), [.success])
        XCTAssertEqual(recorder.outcomes(for: .snapshotWrite), [.success])
        XCTAssertEqual(recorder.outcomes(for: .snapshotFlush), [.success])
        XCTAssertEqual(Set(recorder.endedTokenValues).count, 3)
        XCTAssertTrue(recorder.openTokens.isEmpty)
        XCTAssertEqual(fileSystem.atomicCommitCount, 1)
    }

    func testSignpostRegistryIsEmptyAfterTeardown() throws {
        let recorder = M5PerformanceRecorder()
        var registry: PerformanceIntervalRegistry? = PerformanceIntervalRegistry(
            signposter: recorder
        )
        _ = registry?.begin(.restoreToInteractive, reason: .initial)
        _ = registry?.begin(.readerLayout, reason: .restore)
        _ = registry?.begin(.editToVisible, reason: nil)
        _ = registry?.begin(.scrollSession, reason: nil)
        _ = registry?.begin(.scrollTick, reason: nil)
        _ = registry?.begin(.snapshotEncode, reason: nil)
        _ = registry?.begin(.snapshotWrite, reason: .debounced)
        _ = registry?.begin(.snapshotFlush, reason: .flush)

        registry?.cancelAll()
        XCTAssertEqual(registry?.openIntervalCount, 0)
        registry = nil

        XCTAssertTrue(recorder.openTokens.isEmpty)
        XCTAssertEqual(recorder.beginCount, recorder.endCount)
        XCTAssertEqual(
            Set(recorder.outcomesByOperation.values.flatMap { $0 }),
            Set([.cancelled])
        )
    }

    private func snapshot(revision: UInt64) -> PersistedSnapshot {
        PersistedSnapshot(
            revision: revision,
            document: ScriptDocument(
                text: "synthetic signpost fixture",
                revision: revision
            ),
            readingAnchor: ReadingAnchor(),
            preferences: TeleprompterPreferences()
        )
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: repositoryRoot.appendingPathComponent(path).path, encoding: .utf8)
    }

    private func productionSwiftFiles() throws -> [String] {
        let roots = [
            repositoryRoot.appendingPathComponent("PrivatePresenterApp"),
            repositoryRoot.appendingPathComponent("Packages/TeleprompterCore/Sources"),
        ]
        return try roots.flatMap { root in
            try FileManager.default.subpathsOfDirectory(atPath: root.path)
                .filter { $0.hasSuffix(".swift") }
                .map { root.appendingPathComponent($0).path }
        }
    }

    private func relativePath(_ path: String) -> String {
        String(path.dropFirst(repositoryRoot.path.count + 1))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private final class M5PerformanceRecorder: PerformanceSignposting, @unchecked Sendable {
    struct Event: Equatable, Sendable {
        enum Edge: Equatable, Sendable {
            case begin(PerformanceSignpostOperation)
            case end(PerformanceSignpostOperation)
        }
        let edge: Edge
        let tokenValue: UInt64
        let category: PerformanceSignpostCategory
        let reason: PerformanceSignpostReason?
        let outcome: PerformanceSignpostOutcome?
    }

    private let lock = NSLock()
    private var nextTokenValue: UInt64 = 0
    private var active: [UInt64: (PerformanceSignpostOperation, PerformanceSignpostReason?)] = [:]
    private var recordedEvents: [Event] = []
    var onEnd: (@MainActor (PerformanceSignpostOperation) -> Void)?
    let isEnabled = true

    func beginInterval(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceSignpostToken? {
        lock.lock()
        defer { lock.unlock() }
        nextTokenValue += 1
        let token = PerformanceSignpostToken(rawValue: nextTokenValue)
        active[token.rawValue] = (operation, reason)
        recordedEvents.append(
            Event(
                edge: .begin(operation),
                tokenValue: token.rawValue,
                category: operation.category,
                reason: reason,
                outcome: nil
            )
        )
        return token
    }

    func endInterval(
        _ token: PerformanceSignpostToken,
        outcome: PerformanceSignpostOutcome
    ) {
        lock.lock()
        guard let (operation, reason) = active.removeValue(forKey: token.rawValue) else {
            lock.unlock()
            XCTFail("Interval token ended more than once")
            return
        }
        recordedEvents.append(
            Event(
                edge: .end(operation),
                tokenValue: token.rawValue,
                category: operation.category,
                reason: reason,
                outcome: outcome
            )
        )
        let callback = onEnd
        lock.unlock()
        if let callback {
            MainActor.assumeIsolated { callback(operation) }
        }
    }

    var events: [Event] { withLock { recordedEvents } }
    var openTokens: Set<UInt64> { withLock { Set(active.keys) } }
    var beginCount: Int { events.filter { if case .begin = $0.edge { true } else { false } }.count }
    var endCount: Int { events.filter { if case .end = $0.edge { true } else { false } }.count }
    var endedTokenValues: [UInt64] {
        events.compactMap { if case .end = $0.edge { $0.tokenValue } else { nil } }
    }
    var openOperations: [PerformanceSignpostOperation] {
        withLock { active.values.map(\.0).sorted { $0.rawValue < $1.rawValue } }
    }
    var completedOperations: [PerformanceSignpostOperation] {
        events.compactMap { event in
            if case .end(let operation) = event.edge { return operation }
            return nil
        }
    }
    var lastOutcome: PerformanceSignpostOutcome? { events.last?.outcome }
    var outcomesByOperation: [PerformanceSignpostOperation: [PerformanceSignpostOutcome]] {
        var result: [PerformanceSignpostOperation: [PerformanceSignpostOutcome]] = [:]
        for event in events {
            guard case .end(let operation) = event.edge, let outcome = event.outcome else {
                continue
            }
            result[operation, default: []].append(outcome)
        }
        return result
    }
    func outcomes(for operation: PerformanceSignpostOperation) -> [PerformanceSignpostOutcome] {
        outcomesByOperation[operation] ?? []
    }
    var closedVocabulary: [String] {
        events.compactMap { event -> [String]? in
            guard case .end(let operation) = event.edge, let outcome = event.outcome else { return nil }
            return [operation.rawValue, event.category.rawValue, outcome.rawValue]
                + (event.reason.map { [$0.rawValue] } ?? [])
        }.flatMap { $0 }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

@MainActor
private final class M5PerformanceViewport: ReaderViewport {
    var attachmentView: NSView? = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    var clipSize = NSSize(width: 480, height: 300)
    var clipOriginY = 0.0
    var maximumOffset = 1_000.0
    var textMutationCount = 0
    private(set) var ensureLayoutCount = 0
    private(set) var attributedRebuildCount = 0

    func ensureLayout() { ensureLayoutCount += 1 }
    func captureAnchor(viewportFraction: Double) -> ReadingAnchor {
        ReadingAnchor(utf16Offset: 0, viewportFraction: viewportFraction)
    }
    @discardableResult
    func restore(anchor: ReadingAnchor) -> Double { clipOriginY }
    func setClipOriginY(_ offset: Double) {
        clipOriginY = min(max(offset, 0), maximumOffset)
    }
    func threeCompleteLineStep() -> Double { 90 }
}

@MainActor
private final class M5PerformanceFrameClockFactory {
    private(set) var clocks: [M5PerformanceFrameClock] = []
    var latest: M5PerformanceFrameClock? { clocks.last }

    func make(
        attachedView: NSView,
        onTick: @escaping @MainActor (TimeInterval) -> Void
    ) -> FrameClock? {
        let clock = M5PerformanceFrameClock(onTick: onTick)
        clocks.append(clock)
        return clock
    }
}

@MainActor
private final class M5PerformanceFrameClock: FrameClock {
    private var onTick: (@MainActor (TimeInterval) -> Void)?
    init(onTick: @escaping @MainActor (TimeInterval) -> Void) { self.onTick = onTick }
    func fire(at uptime: TimeInterval) { onTick?(uptime) }
    func invalidate() { onTick = nil }
}

private final class M5PerformanceSnapshotFileSystem: SnapshotFileSystem, @unchecked Sendable {
    private let lock = NSLock()
    private var commitCount = 0
    var atomicCommitCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return commitCount
    }
    func createDirectory(at url: URL) throws {}
    func fileExists(at url: URL) -> Bool { false }
    func readFile(at url: URL) throws -> Data { Data() }
    func atomicCommit(_ data: Data, to destinationURL: URL, temporaryURL: URL) throws {
        lock.lock()
        commitCount += 1
        lock.unlock()
    }
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {}
}

private actor M5SuspendedSnapshotSleeper: SnapshotSleeper {
    private var continuation: CheckedContinuation<Void, Error>?
    private var entered: CheckedContinuation<Void, Never>?
    private var didEnter = false

    func sleep(for duration: Duration) async throws {
        didEnter = true
        entered?.resume()
        entered = nil
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilEntered() async {
        guard !didEnter else { return }
        await withCheckedContinuation { entered = $0 }
    }

    func cancel() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

private struct M5ImmediateCancellationSnapshotSleeper: SnapshotSleeper {
    func sleep(for duration: Duration) async throws {
        throw CancellationError()
    }
}
