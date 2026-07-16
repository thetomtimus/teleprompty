import AppKit
import TeleprompterCore
import XCTest
@testable import PrivatePresenter

@MainActor
final class FocusModeControllerTests: XCTestCase {
    func testPointerPresenceRevealsWithoutDisablingClickThrough() {
        let harness = makeFocusHarness()
        harness.panel.setLocked(true)
        harness.controller.apply(.init(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false))
        harness.scheduler.fire()
        harness.controller.apply(.init(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: true))

        XCTAssertEqual(harness.visibility, [true, false, true])
        XCTAssertTrue(harness.panel.ignoresMouseEvents)
    }

    func testDynamicCanBecomeKeyRequiresUnlockedAndActive() {
        XCTAssertFalse(TeleprompterPanel.keyEligibility(isLocked: true, applicationIsActive: true))
        XCTAssertFalse(TeleprompterPanel.keyEligibility(isLocked: false, applicationIsActive: false))
        XCTAssertTrue(TeleprompterPanel.keyEligibility(isLocked: false, applicationIsActive: true))
    }

    func testUnlockNeverActivates() {
        var operations: [OverlayPanelOperation] = []
        let controller = OverlayPanelController(operationRecorder: { operations.append($0) })
        controller.setLocked(true)
        controller.setLocked(false)

        XCTAssertFalse(operations.contains(.activateApplication))
        XCTAssertFalse(operations.contains(.makeKey))
        XCTAssertFalse(operations.contains(.makeMain))
    }

    func testReduceMotionRemovesDecorativeFade() {
        let reduced = makeFocusHarness(reduceMotion: true)
        reduced.controller.apply(
            .init(
                isVisible: true,
                isLocked: false,
                isFocusModeEnabled: true,
                pointerPresent: false
            )
        )
        let animated = makeFocusHarness(reduceMotion: false)
        animated.controller.apply(
            .init(
                isVisible: true,
                isLocked: false,
                isFocusModeEnabled: true,
                pointerPresent: false
            )
        )

        XCTAssertEqual(reduced.durations.last, 0)
        XCTAssertGreaterThan(animated.durations.last ?? 0, 0)
    }

    func testHideAndTeardownCancelDeadlineAndSampling() {
        let harness = makeFocusHarness()
        harness.controller.apply(.init(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false))
        harness.controller.apply(.init(isVisible: false, isLocked: true, isFocusModeEnabled: true, pointerPresent: false))
        harness.controller.teardown()

        XCTAssertGreaterThanOrEqual(harness.scheduler.cancelCount, 1)
        XCTAssertGreaterThanOrEqual(harness.pointerMonitor.stopCount, 1)
    }

    func testPointerSamplerRunsOnlyWhileVisibleLockedAndFocused() {
        let scheduler = FakeRepeatingScheduler()
        let monitor = PointerPresenceMonitor(
            scheduler: scheduler,
            locationProvider: { NSPoint(x: 10, y: 10) },
            panelFrameProvider: { NSRect(x: 0, y: 0, width: 100, height: 100) },
            onPresenceChanged: { _ in }
        )

        monitor.update(isActive: false)
        XCTAssertEqual(scheduler.startCount, 0)
        monitor.update(isActive: true)
        XCTAssertEqual(scheduler.startCount, 1)
        monitor.update(isActive: false)
        XCTAssertEqual(scheduler.cancelCount, 1)
    }

    func testPointerSamplerUsesLocationOnlyAtOneHundredMillisecondInterval() {
        let scheduler = FakeRepeatingScheduler()
        var presences: [Bool] = []
        let monitor = PointerPresenceMonitor(
            scheduler: scheduler,
            locationProvider: { NSPoint(x: 10, y: 10) },
            panelFrameProvider: { NSRect(x: 0, y: 0, width: 100, height: 100) },
            onPresenceChanged: { presences.append($0) }
        )

        monitor.update(isActive: true)
        scheduler.fire()

        XCTAssertEqual(scheduler.interval, 0.1)
        XCTAssertEqual(presences, [true])
    }

    func testLockedPointerRevealKeepsIgnoresMouseEventsTrue() {
        let harness = makeFocusHarness()
        harness.panel.setLocked(true)
        harness.controller.apply(.init(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: true))
        XCTAssertTrue(harness.panel.ignoresMouseEvents)
    }

    func testInactiveApplicationCannotYieldKeyPanelEvenWhenUnlocked() {
        XCTAssertFalse(TeleprompterPanel.keyEligibility(isLocked: false, applicationIsActive: false))
    }

    func testShowHideLockFocusAndPointerPathsNeverActivateOrMakeKey() {
        var operations: [OverlayPanelOperation] = []
        let overlay = OverlayPanelController(operationRecorder: { operations.append($0) })
        overlay.stageHidden(proposedFrame: .init(x: 10, y: 10, width: 500, height: 250), on: .init(x: 0, y: 0, width: 1000, height: 700))
        overlay.show(proposedFrame: .init(x: 10, y: 10, width: 500, height: 250), on: .init(x: 0, y: 0, width: 1000, height: 700))
        overlay.setLocked(true)
        overlay.hide()

        XCTAssertFalse(operations.contains(.activateApplication))
        XCTAssertFalse(operations.contains(.makeKey))
        XCTAssertFalse(operations.contains(.makeMain))
    }

    func testCanBecomeMainRemainsFalseInEveryState() {
        let panel = TeleprompterPanel(contentRect: .init(x: 0, y: 0, width: 500, height: 250))
        panel.setLocked(false)
        XCTAssertFalse(panel.canBecomeMain)
        panel.setLocked(true)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testFocusChromeUsesSameAppModelIdentityAsReaderWindow() {
        let runtime = AppRuntime(proofLevel: .floating)
        XCTAssertEqual(runtime.overlayController.connectedModelIdentity, ObjectIdentifier(runtime.model))
    }

    func testOverlayHostingControllerIsCreatedOnceOnConnect() {
        let runtime = AppRuntime(proofLevel: .floating)
        XCTAssertEqual(runtime.overlayController.hostingControllerConstructionCount, 1)
        _ = runtime.overlayController.connect(model: runtime.model)
        XCTAssertEqual(runtime.overlayController.hostingControllerConstructionCount, 1)
    }

    func testConnectModelIsIdempotentAndRejectsDifferentModel() {
        let controller = OverlayPanelController()
        let first = AppModel(overlayController: controller)
        XCTAssertTrue(controller.connect(model: first))
        XCTAssertTrue(controller.connect(model: first))
        let other = AppModel(overlayController: OverlayPanelController())
        XCTAssertFalse(controller.connect(model: other))
    }

    func testFocusChromeDoesNotMutateTextOrChangeReaderInset() {
        let runtime = AppRuntime(proofLevel: .floating)
        runtime.model.send(.replaceScript(text: "Synthetic reader fixture"))
        let revision = runtime.model.document.revision
        runtime.model.send(.setFocusModeEnabled(false))

        XCTAssertEqual(runtime.model.document.text, "Synthetic reader fixture")
        XCTAssertEqual(runtime.model.document.revision, revision)
        XCTAssertEqual(ReaderViewportAdapter.documentBottomPadding, 64)
    }

    func testFocusPreferenceRoundTripsSchemaOne() throws {
        var preferences = TeleprompterPreferences()
        preferences.isFocusModeEnabled = false
        let snapshot = PersistedSnapshot(
            revision: 1,
            document: ScriptDocument(text: "Synthetic"),
            readingAnchor: ReadingAnchor(),
            preferences: preferences,
            shortcutBindings: ShortcutValidator.defaultBindings
        )
        let decoded = try PersistedSnapshot.canonicalDecoder().decode(PersistedSnapshot.self, from: snapshot.canonicalData())

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertFalse(decoded.preferences.isFocusModeEnabled)
    }

    private func makeFocusHarness(reduceMotion: Bool = false) -> FocusHarness {
        FocusHarness(reduceMotion: reduceMotion)
    }
}

@MainActor
private final class FocusHarness {
    let panel = TeleprompterPanel(contentRect: .init(x: 0, y: 0, width: 500, height: 250))
    let scheduler = FakeFocusDeadlineScheduler()
    let pointerMonitor = FakePointerMonitor()
    var visibility: [Bool] = []
    var durations: [TimeInterval] = []
    lazy var controller = FocusModeController(
        scheduler: scheduler,
        pointerMonitor: pointerMonitor,
        reduceMotionProvider: { [weak self] in self?.reduceMotion ?? false },
        setChromeVisible: { [weak self] visible, duration in
            self?.visibility.append(visible)
            self?.durations.append(duration)
        },
        stateChanged: { _ in }
    )
    private let reduceMotion: Bool

    init(reduceMotion: Bool) { self.reduceMotion = reduceMotion }
}

@MainActor
private final class FakeFocusDeadlineScheduler: FocusDeadlineScheduling {
    var action: (@MainActor () -> Void)?
    var cancelCount = 0
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { cancelCount += 1; action = nil }
    func fire() { let current = action; action = nil; current?() }
}

@MainActor
private final class FakePointerMonitor: PointerPresenceMonitoring {
    var startCount = 0
    var stopCount = 0
    func update(isActive: Bool) { if isActive { startCount += 1 } else { stopCount += 1 } }
    func teardown() { stopCount += 1 }
}

@MainActor
private final class FakeRepeatingScheduler: RepeatingScheduling {
    var interval: TimeInterval?
    var action: (@MainActor () -> Void)?
    var startCount = 0
    var cancelCount = 0
    func start(interval: TimeInterval, action: @escaping @MainActor () -> Void) {
        self.interval = interval; self.action = action; startCount += 1
    }
    func cancel() { action = nil; cancelCount += 1 }
    func fire() { action?() }
}
