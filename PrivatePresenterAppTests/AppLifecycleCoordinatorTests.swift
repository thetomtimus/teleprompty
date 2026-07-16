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
        XCTAssertTrue(await harness.coordinator.stopAndFlush())
        XCTAssertLessThan(harness.events.firstIndex(of: .pauseAndCapture)!, harness.events.firstIndex(of: .flushPausedSnapshot)!)
    }

    func testFlushFailureKeepsRecoveryServicesAndCancelsTermination() async {
        let harness = makeLifecycleHarness(flushResult: false)
        XCTAssertFalse(await harness.coordinator.stopAndFlush())
        XCTAssertFalse(harness.model.isTerminationAttempting)
        XCTAssertFalse(harness.model.isTerminationQuiescing)
        XCTAssertFalse(harness.events.contains(.unregisterHotKeys))
        XCTAssertFalse(harness.events.contains(.removeStatusItem))
    }

    func testSuccessfulQuitStopsCallbacksBeforeStatusItemRemovalAndTerminateReply() async {
        let harness = makeLifecycleHarness(flushResult: true)
        XCTAssertTrue(await harness.coordinator.stopAndFlush())
        XCTAssertLessThan(harness.events.firstIndex(of: .stopFocusPointerDisplay)!, harness.events.firstIndex(of: .removeStatusItem)!)
        XCTAssertLessThan(harness.events.firstIndex(of: .removeStatusItem)!, harness.events.firstIndex(of: .terminateReady)!)
    }

    func testRepeatedQuitAndShutdownAreIdempotent() async {
        let harness = makeLifecycleHarness(flushResult: true)
        XCTAssertTrue(await harness.coordinator.stopAndFlush())
        let events = harness.events
        XCTAssertTrue(await harness.coordinator.stopAndFlush())
        XCTAssertEqual(harness.events, events)
    }

    func testRuntimeConstructsNoSecondModelPanelControllerStatusItemOrScrollOwner() {
        let runtime = AppRuntime(proofLevel: .floating)
        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
        XCTAssertEqual(runtime.overlayController.configurationSnapshot.panelCount, 1)
        XCTAssertEqual(runtime.statusItemController.actionItemCount, 5)
        XCTAssertEqual(runtime.dependencies.effectAdapter.activeScrollSessionCount, 0)
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
