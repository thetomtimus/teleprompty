import AppKit
import TeleprompterCore
import XCTest
@testable import PrivatePresenter

@MainActor
final class AppLifecycleCoordinatorTests: XCTestCase {
    func testStatusItemOwnsExactlyFiveActionItems() {
        let model = AppModel(overlayController: OverlayPanelController())
        let status = StatusItemController(model: model)
        defer { status.remove() }

        XCTAssertEqual(status.actionItemCount, 5)
        XCTAssertEqual(status.actionTitles, ["Show Controller", "Start", "Show Teleprompter", "Lock", "Quit"])
    }

    func testMenuAndStatusTitlesNeverContainScriptTitle() {
        let sentinel = "SENTINEL_PRIVATE_TITLE"
        let model = AppModel(overlayController: OverlayPanelController())
        model.send(.setScriptTitle(sentinel))
        let status = StatusItemController(model: model)
        defer { status.remove() }

        XCTAssertFalse((status.actionTitles + [status.statusItemTitle, status.statusItemToolTip]).joined().contains(sentinel))
    }

    func testEveryMenuActionDispatchesTypedAppCommand() {
        var effects: [AppEffect] = []
        let model = AppModel(overlayController: OverlayPanelController(), effectHandler: { effects.append($0) })
        let status = StatusItemController(model: model)
        defer { status.remove() }
        let count = model.commandDispatchCount

        for index in 0..<5 { status.invokeForTesting(index: index) }

        XCTAssertEqual(model.commandDispatchCount, count + 5)
        XCTAssertTrue(effects.contains(.showExistingController))
        XCTAssertTrue(effects.contains(.requestTermination))
    }

    func testQuitRequestReachesLifecycleAsTypedAppCommand() {
        var effects: [AppEffect] = []
        let model = AppModel(overlayController: OverlayPanelController(), effectHandler: { effects.append($0) })
        model.send(.requestQuit)
        XCTAssertEqual(effects.last, .requestTermination)
    }

    func testClosingControllerLeavesOverlayStatusAndHotKeysAlive() {
        let runtime = AppRuntime(proofLevel: .floating)
        let statusIdentity = ObjectIdentifier(runtime.statusItemController)
        runtime.controllerWindowController.close()

        XCTAssertEqual(ObjectIdentifier(runtime.statusItemController), statusIdentity)
        XCTAssertFalse(runtime.statusItemController.isRemoved)
        XCTAssertNotNil(runtime.dependencies.effectAdapter.carbonHotKeyService)
    }

    func testShowControllerWhileUnsafeRemainsShielded() {
        let runtime = AppRuntime(proofLevel: .floating)
        runtime.controllerWindowController.close()
        runtime.model.send(.showController)
        XCTAssertTrue(runtime.model.isShielded)
        XCTAssertTrue(runtime.controllerWindowController.window?.isVisible ?? false)
    }

    func testStartupRegistersProductHotKeysAfterRestoreAndPrivacyAssessment() async {
        var events: [AppRuntimeStartupEvent] = []
        let runtime = AppRuntime(
            proofLevel: .floating,
            startupSeams: .init(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                record: { events.append($0) }
            )
        )
        await runtime.startForTesting()

        XCTAssertLessThan(events.firstIndex(of: .restore)!, events.firstIndex(of: .registerProductHotKeys)!)
        XCTAssertLessThan(events.firstIndex(of: .evaluatePrivacy)!, events.firstIndex(of: .registerProductHotKeys)!)
    }

    func testStartupCollisionLeavesMenuAndControllerRecoveryAvailable() async {
        let runtime = AppRuntime(proofLevel: .floating)
        await runtime.startForTesting()
        XCTAssertFalse(runtime.statusItemController.isRemoved)
        XCTAssertNotNil(runtime.controllerWindowController.window)
    }

    func testQuitStopsAndCapturesBeforePausedSnapshotFlush() async {
        let harness = makeLifecycleHarness(flushResult: true)
        let stopped = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(stopped)
        XCTAssertLessThan(harness.events.firstIndex(of: .pauseAndCapture)!, harness.events.firstIndex(of: .flushPausedSnapshot)!)
    }

    func testFlushFailureKeepsRecoveryServicesAndCancelsTermination() async {
        let harness = makeLifecycleHarness(flushResult: false)
        let stopped = await harness.coordinator.stopAndFlush()
        XCTAssertFalse(stopped)
        XCTAssertFalse(harness.model.isTerminationAttempting)
        XCTAssertFalse(harness.model.isTerminationQuiescing)
        XCTAssertFalse(harness.events.contains(.unregisterHotKeys))
        XCTAssertFalse(harness.events.contains(.removeStatusItem))
    }

    func testSuccessfulQuitStopsCallbacksBeforeStatusItemRemovalAndTerminateReply() async {
        let harness = makeLifecycleHarness(flushResult: true)
        let stopped = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(stopped)
        XCTAssertLessThan(harness.events.firstIndex(of: .stopFocusPointerDisplay)!, harness.events.firstIndex(of: .removeStatusItem)!)
        XCTAssertLessThan(harness.events.firstIndex(of: .removeStatusItem)!, harness.events.firstIndex(of: .terminateReady)!)
    }

    func testRepeatedQuitAndShutdownAreIdempotent() async {
        let harness = makeLifecycleHarness(flushResult: true)
        let firstStop = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(firstStop)
        let events = harness.events
        let secondStop = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(secondStop)
        XCTAssertEqual(harness.events, events)
    }

    func testRuntimeConstructsNoSecondModelPanelControllerStatusItemOrScrollOwner() {
        let runtime = AppRuntime(proofLevel: .floating)
        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
        XCTAssertEqual(runtime.overlayController.configurationSnapshot.panelCount, 1)
        XCTAssertEqual(runtime.statusItemController.actionItemCount, 5)
        XCTAssertEqual(runtime.dependencies.effectAdapter.activeScrollSessionCount, 0)
    }

    func testQuitTearsDownCallbacks() async {
        let harness = M5LifecycleHarness(flush: { true })
        let stopped = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(stopped)
        let commandCount = harness.model.commandDispatchCount
        let effects = harness.effects

        harness.deliverQuiescentCallbacks()

        XCTAssertEqual(harness.model.commandDispatchCount, commandCount)
        XCTAssertEqual(harness.effects, effects)
        XCTAssertTrue(harness.model.isTerminationQuiescing)
    }

    func testSuccessfulQuitUsesExactLifecycleOrder() async {
        let harness = M5LifecycleHarness(flush: { true })

        let stopped = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(stopped)
        XCTAssertEqual(
            harness.events,
            [
                .rejectMutations,
                .pauseAndCapture,
                .hideAndShield,
                .stagePausedSnapshot,
                .flushPausedSnapshot,
                .enterQuiescence,
                .closeCarbonDispatch,
                .unregisterHotKeys,
                .stopFocusPointerDisplay,
                .teardownScrollSession,
                .removeStatusItem,
                .closeController,
                .terminateReady,
            ]
        )
        XCTAssertEqual(
            harness.teardownOperations,
            [
                "closeCarbonDispatch",
                "unregisterHotKeys",
                "stopFocusPointerDisplay",
                "teardownScrollSession",
                "removeStatusItem",
                "closeController",
            ]
        )
        XCTAssertEqual(harness.flushedRevisions, [harness.model.snapshotRevision])
        XCTAssertEqual(
            harness.effects.compactMap { effect -> UInt64? in
                guard case .scheduleSnapshot(let snapshot) = effect else { return nil }
                return snapshot.revision
            }.last,
            harness.flushedRevisions.last
        )
        XCTAssertTrue(harness.model.isPaused)
        XCTAssertTrue(harness.model.isShielded)
        XCTAssertEqual(harness.model.overlaySession.visibility, .hidden)
    }

    func testFlushFailureTearsDownNothingAndLeavesRecoveryAvailable() async {
        let results = M5FlushSequence([false, true])
        let harness = M5LifecycleHarness(flush: { results.next() })

        let firstStop = await harness.coordinator.stopAndFlush()
        XCTAssertFalse(firstStop)
        XCTAssertEqual(
            harness.events,
            [
                .rejectMutations,
                .pauseAndCapture,
                .hideAndShield,
                .stagePausedSnapshot,
                .flushPausedSnapshot,
                .flushFailed,
            ]
        )
        XCTAssertTrue(harness.teardownOperations.isEmpty)
        XCTAssertFalse(harness.model.isTerminationQuiescing)
        XCTAssertFalse(harness.model.isTerminationAttempting)
        XCTAssertTrue(harness.model.isPaused)
        XCTAssertTrue(harness.model.isShielded)
        XCTAssertEqual(harness.model.overlaySession.visibility, .hidden)
        XCTAssertEqual(harness.model.localError, .terminationFlushFailed)

        let retryStop = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(retryStop)
        XCTAssertEqual(results.callCount, 2)
    }

    func testOverlappingQuitRequestsShareOneAttempt() async {
        let gate = M5LifecycleFlushGate()
        let harness = M5LifecycleHarness(flush: { await gate.wait() })
        let first = Task { @MainActor in await harness.coordinator.stopAndFlush() }
        await gate.waitUntilEntered()
        let second = Task { @MainActor in await harness.coordinator.stopAndFlush() }
        await Task.yield()
        gate.release(true)

        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertEqual(gate.waitCount, 1)
        XCTAssertEqual(harness.events.filter { $0 == .flushPausedSnapshot }.count, 1)
        XCTAssertEqual(harness.events.filter { $0 == .terminateReady }.count, 1)
    }

    func testRepeatedSuccessfulTeardownIsIdempotent() async {
        let harness = M5LifecycleHarness(flush: { true })
        let firstStop = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(firstStop)
        let events = harness.events
        let teardown = harness.teardownOperations

        let secondStop = await harness.coordinator.stopAndFlush()
        XCTAssertTrue(secondStop)
        XCTAssertEqual(harness.events, events)
        XCTAssertEqual(harness.teardownOperations, teardown)
    }

    func testQuiescentTickFocusHotKeyAndDisplayCallbacksAreIgnored() {
        let harness = M5LifecycleHarness(flush: { true })
        harness.model.send(.beginTerminationAttempt)
        harness.model.send(.prepareForTermination)
        harness.model.send(.enterTerminationQuiescence)
        harness.effects.removeAll()
        let commandCount = harness.model.commandDispatchCount
        let revision = harness.model.snapshotRevision
        let anchor = harness.model.overlaySession.readingAnchor
        let focus = harness.model.focusChromeState
        let hotKeyStatus = harness.model.hotKeyStatus

        harness.deliverQuiescentCallbacks()

        XCTAssertEqual(harness.model.commandDispatchCount, commandCount)
        XCTAssertEqual(harness.model.snapshotRevision, revision)
        XCTAssertEqual(harness.model.overlaySession.readingAnchor, anchor)
        XCTAssertEqual(harness.model.focusChromeState, focus)
        XCTAssertEqual(harness.model.hotKeyStatus, hotKeyStatus)
        XCTAssertTrue(harness.effects.isEmpty)
    }

    func testCarbonDispatchClosesBeforeUnregisterAndCleanupStatusDoesNotReopenIt() async {
        let registrar = M5LifecycleHotKeyRegistrar(unregisterStatus: -9_876)
        var dispatched: [ShortcutAction] = []
        let service = CarbonHotKeyService(
            registrar: registrar,
            dispatch: { dispatched.append($0) }
        )
        registrar.service = service
        guard case .committed = service.register(ShortcutValidator.defaultBindings) else {
            return XCTFail("Expected synthetic hot-key registration")
        }
        _ = service.receiveForTesting(identifier: .init(action: .togglePlayback))

        service.closeDispatch()
        let report = service.shutdown()
        await Task.yield()
        let registrationCount = registrar.registerCount
        let retry = service.retry()

        XCTAssertTrue(dispatched.isEmpty)
        XCTAssertEqual(registrar.firstUnregisterObservedDispatchClosed, true)
        XCTAssertEqual(report.referenceStatuses.first, -9_876)
        XCTAssertFalse(report.succeeded)
        guard case .cleanupUnknown = retry else {
            return XCTFail("Cleanup failure must remain unknown")
        }
        XCTAssertEqual(registrar.registerCount, registrationCount)
        XCTAssertFalse(String(describing: report).contains("synthetic lifecycle fixture"))
    }

    func testRuntimeOwnersDeallocateAfterTeardown() async {
        var runtime: AppRuntime? = AppRuntime(proofLevel: .floating)
        weak var weakRuntime = runtime
        weak var weakModel = runtime?.model
        weak var weakOverlay = runtime?.overlayController

        let stopped = await runtime?.stopAndFlush()
        XCTAssertTrue(stopped == true)
        runtime = nil
        for _ in 0..<5 { await Task.yield() }

        XCTAssertNil(weakRuntime)
        XCTAssertNil(weakModel)
        XCTAssertNil(weakOverlay)
    }

    private func makeLifecycleHarness(flushResult: Bool) -> LifecycleHarness {
        LifecycleHarness(flushResult: flushResult)
    }
}

@MainActor
private final class LifecycleHarness {
    let model = AppModel(overlayController: OverlayPanelController())
    var events: [AppLifecycleEvent] = []
    lazy var coordinator = AppLifecycleCoordinator(
        model: model,
        flushPausedSnapshot: { [weak self] in self?.flushResult ?? false },
        unregisterHotKeys: {},
        stopFocusPointerDisplay: {},
        teardownScrollSession: {},
        removeStatusItem: {},
        closeController: {},
        record: { [weak self] in self?.events.append($0) }
    )
    private let flushResult: Bool

    init(flushResult: Bool) { self.flushResult = flushResult }
}

@MainActor
private final class M5LifecycleHarness {
    let model: AppModel
    var events: [AppLifecycleEvent] = []
    var teardownOperations: [String] = []
    var flushedRevisions: [UInt64] = []
    private let flush: @MainActor () async -> Bool
    private let effectRecorder: M5LifecycleEffectRecorder
    var effects: [AppEffect] {
        get { effectRecorder.effects }
        set { effectRecorder.effects = newValue }
    }

    lazy var coordinator = AppLifecycleCoordinator(
        model: model,
        flushPausedSnapshot: { [weak self] in
            guard let self else { return false }
            self.flushedRevisions.append(self.model.snapshotRevision)
            return await self.flush()
        },
        closeCarbonDispatch: { [weak self] in
            self?.teardownOperations.append("closeCarbonDispatch")
        },
        unregisterHotKeys: { [weak self] in
            self?.teardownOperations.append("unregisterHotKeys")
        },
        stopFocusPointerDisplay: { [weak self] in
            self?.teardownOperations.append("stopFocusPointerDisplay")
        },
        teardownScrollSession: { [weak self] in
            self?.teardownOperations.append("teardownScrollSession")
        },
        removeStatusItem: { [weak self] in
            self?.teardownOperations.append("removeStatusItem")
        },
        closeController: { [weak self] in
            self?.teardownOperations.append("closeController")
        },
        record: { [weak self] in self?.events.append($0) }
    )

    init(flush: @escaping @MainActor () async -> Bool) {
        self.flush = flush
        let effectRecorder = M5LifecycleEffectRecorder()
        self.effectRecorder = effectRecorder
        model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "synthetic lifecycle fixture"),
            effectHandler: { effectRecorder.effects.append($0) }
        )
    }

    func deliverQuiescentCallbacks() {
        model.send(
            .scrollCheckpoint(
                ScrollCheckpoint(
                    generation: model.currentScrollGeneration,
                    anchor: ReadingAnchor(
                        utf16Offset: 4,
                        document: model.document.text
                    ),
                    pixelOffset: 80,
                    uptime: 10
                )
            )
        )
        model.send(.focusChromeStateChanged(.lockedFocusChromeHidden))
        model.send(.hotKeyReconfigurationCompleted(.committed(model.shortcutBindings)))
        model.send(.displayInventoryLoaded(RuntimeDisplayInventory(displays: [])))
    }
}

@MainActor
private final class M5LifecycleEffectRecorder {
    var effects: [AppEffect] = []
}

@MainActor
private final class M5FlushSequence {
    private var results: [Bool]
    private(set) var callCount = 0

    init(_ results: [Bool]) { self.results = results }

    func next() -> Bool {
        callCount += 1
        return results.isEmpty ? false : results.removeFirst()
    }
}

@MainActor
private final class M5LifecycleFlushGate {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private(set) var waitCount = 0
    private var releasedResult: Bool?

    func wait() async -> Bool {
        waitCount += 1
        enteredContinuation?.resume()
        enteredContinuation = nil
        if let releasedResult { return releasedResult }
        return await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilEntered() async {
        guard waitCount == 0 else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release(_ result: Bool) {
        releasedResult = result
        continuation?.resume(returning: result)
        continuation = nil
    }
}

@MainActor
private final class M5LifecycleHotKeyRegistrar: HotKeyRegistering {
    private let unregisterStatus: Int32
    private var nextToken: UInt64 = 1
    private(set) var registerCount = 0
    private(set) var firstUnregisterObservedDispatchClosed: Bool?
    weak var service: CarbonHotKeyService?

    init(unregisterStatus: Int32) { self.unregisterStatus = unregisterStatus }

    func installHandler(
        callback: @escaping @MainActor (ProductHotKeyIdentifier) -> Int32
    ) -> HotKeyCallResult<HotKeyHandlerToken> {
        .success(HotKeyHandlerToken(rawValue: 1))
    }

    func register(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        identifier: ProductHotKeyIdentifier
    ) -> HotKeyCallResult<HotKeyToken> {
        registerCount += 1
        defer { nextToken += 1 }
        return .success(HotKeyToken(rawValue: nextToken))
    }

    func unregister(_ token: HotKeyToken) -> Int32 {
        if firstUnregisterObservedDispatchClosed == nil {
            firstUnregisterObservedDispatchClosed = service?.isDispatchClosed
        }
        return unregisterStatus
    }

    func removeHandler(_ token: HotKeyHandlerToken) -> Int32 { noErr }
}
