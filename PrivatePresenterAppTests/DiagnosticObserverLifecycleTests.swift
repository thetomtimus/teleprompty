#if DEBUG
import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class DiagnosticObserverLifecycleTests: XCTestCase {
    func testNoEventsAreAcceptedAfterObserverTeardown() async {
        let harness = makeObserverHarness()
        harness.observers.install(panel: harness.panel, controller: harness.controller)
        harness.observers.tearDown()

        harness.applicationCenter.post(
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )
        await settleNotificationTasks()
        _ = await harness.recorder.recorder.finish()

        XCTAssertFalse(
            harness.recorder.sink.envelopes.contains { envelope in
                envelope.payload.applicationLifecycle == .didBecomeActive
            })
    }

    func testApplicationObserversCaptureWillAndDidBecomeActive() async {
        let harness = makeObserverHarness()
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.applicationCenter.post(
            name: NSApplication.willBecomeActiveNotification,
            object: NSApp
        )
        harness.applicationCenter.post(
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )
        await settleNotificationTasks()
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        let lifecycle = harness.recorder.sink.envelopes.compactMap {
            $0.payload.applicationLifecycle
        }
        XCTAssertEqual(lifecycle, [.willBecomeActive, .didBecomeActive])
    }

    func testApplicationObserversCaptureWillAndDidResignActive() async {
        let harness = makeObserverHarness()
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.applicationCenter.post(
            name: NSApplication.willResignActiveNotification,
            object: NSApp
        )
        harness.applicationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        await settleNotificationTasks()
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        let lifecycle = harness.recorder.sink.envelopes.compactMap {
            $0.payload.applicationLifecycle
        }
        XCTAssertEqual(lifecycle, [.willResignActive, .didResignActive])
    }

    func testWorkspaceObserverCapturesDidActivateApplication() async {
        let harness = makeObserverHarness()
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.workspaceCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        await settleNotificationTasks()
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        XCTAssertTrue(
            harness.recorder.sink.envelopes.contains { envelope in
                envelope.kind == .workspaceActivation
                    && envelope.payload.workspaceActivation == .didActivateApplication
            })
    }

    func testWindowObserversRetainTransientKeyMainOrderAndOcclusionNotifications() async {
        let harness = makeObserverHarness()
        harness.observers.install(panel: harness.panel, controller: harness.controller)
        let notifications: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
        ]

        for notification in notifications {
            harness.applicationCenter.post(name: notification, object: harness.panel)
        }
        harness.panel.orderFront(nil)
        harness.applicationCenter.post(
            name: NSWindow.didChangeOcclusionStateNotification,
            object: harness.panel
        )
        harness.panel.orderOut(nil)
        harness.applicationCenter.post(
            name: NSWindow.didChangeOcclusionStateNotification,
            object: harness.panel
        )
        await settleNotificationTasks()
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        let observed = harness.recorder.sink.envelopes.compactMap {
            $0.payload.windowLifecycle
        }
        XCTAssertEqual(
            observed,
            [
                .didBecomeKey,
                .didResignKey,
                .didBecomeMain,
                .didResignMain,
                .didChangeOcclusionState,
                .didOrderOnScreen,
                .didChangeOcclusionState,
                .didOrderOffScreen,
            ]
        )
    }

    func testFocusSnapshotsUseImmediateNextRunLoop100msAnd500msSchedule() async {
        let scheduler = ManualDiagnosticFocusScheduler()
        let harness = makeObserverHarness(focusScheduler: scheduler)
        let correlationID = UUID()
        let focus = focusState()
        var didClose = false
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.observers.scheduleFocusSamples(
            correlationID: correlationID,
            capture: { focus },
            onClosed: { didClose = true }
        )
        XCTAssertEqual(scheduler.delayedMilliseconds, [100, 500])
        scheduler.runNextMainRunLoop()
        scheduler.runDelay(milliseconds: 100)
        scheduler.runDelay(milliseconds: 500)
        scheduler.runNextMainRunLoop()
        _ = await harness.recorder.recorder.finish()

        let kinds = harness.recorder.sink.envelopes
            .filter { $0.correlationID == correlationID }
            .map(\.kind)
        XCTAssertEqual(
            kinds,
            [
                .focusImmediate,
                .focusNextMainRunLoop,
                .focusDelayed100Milliseconds,
                .focusDelayed500Milliseconds,
                .correlationWindowClosed,
            ]
        )
        XCTAssertTrue(didClose)
        XCTAssertEqual(harness.observers.activeCorrelationCount, 0)
    }

    func testDelayedSamplesAreCancelledAfterSessionTeardown() async {
        let scheduler = ManualDiagnosticFocusScheduler()
        let harness = makeObserverHarness(focusScheduler: scheduler)
        let correlationID = UUID()
        let focus = focusState()
        harness.observers.install(panel: harness.panel, controller: harness.controller)
        harness.observers.scheduleFocusSamples(
            correlationID: correlationID,
            capture: { focus },
            onClosed: {}
        )

        harness.observers.tearDown()
        scheduler.runAll()
        _ = await harness.recorder.recorder.finish()

        let kinds = harness.recorder.sink.envelopes
            .filter { $0.correlationID == correlationID }
            .map(\.kind)
        XCTAssertEqual(kinds, [.focusImmediate])
        XCTAssertEqual(harness.observers.activeCorrelationCount, 0)
    }

    func testPostCorrelationQuitActivationIsTaggedAndExcludedFromFocusVerdict() async {
        let harness = makeObserverHarness(
            correlationID: nil,
            postCorrelationQuitEligibilityProvider: { true }
        )
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.applicationCenter.post(
            name: NSApplication.willBecomeActiveNotification,
            object: NSApp
        )
        harness.applicationCenter.post(
            name: NSWindow.didBecomeKeyNotification,
            object: harness.controller
        )
        harness.applicationCenter.post(
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        let activation = harness.recorder.sink.envelopes.first {
            $0.payload.applicationLifecycle == .didBecomeActive
        }
        XCTAssertEqual(activation?.payload.observationPhase, .postCorrelationQuit)
        XCTAssertNil(activation?.correlationID)
        XCTAssertEqual(
            harness.recorder.sink.envelopes.first {
                $0.payload.windowLifecycle == .didBecomeKey
            }?.payload.observationPhase,
            .postCorrelationQuit
        )
        XCTAssertFalse(
            harness.recorder.sink.envelopes.contains { envelope in
                envelope.payload.applicationLifecycle == .didBecomeActive
                    && envelope.payload.observationPhase == .correlatedAction
            })
    }

    func testUncorrelatedActivationWithoutTerminationStillFailsFocusVerdict() async {
        let harness = makeObserverHarness(
            correlationID: nil,
            observationPhaseProvider: { .correlatedAction }
        )
        harness.observers.install(panel: harness.panel, controller: harness.controller)

        harness.applicationCenter.post(
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )
        harness.observers.tearDown()
        _ = await harness.recorder.recorder.finish()

        let focusViolations = harness.recorder.sink.envelopes.filter { envelope in
            envelope.payload.applicationLifecycle == .didBecomeActive
                && envelope.payload.observationPhase != .postCorrelationQuit
        }
        XCTAssertEqual(focusViolations.count, 1)
        XCTAssertNil(focusViolations.first?.correlationID)
    }

    private func makeObserverHarness(
        focusScheduler: any DiagnosticFocusScheduler = SystemDiagnosticFocusScheduler(),
        correlationID: UUID? = UUID(),
        observationPhaseProvider: @escaping @MainActor () -> DiagnosticObservationPhase = {
            .correlatedAction
        },
        postCorrelationQuitEligibilityProvider: @escaping @MainActor () -> Bool = {
            false
        }
    ) -> ObserverHarness {
        _ = NSApplication.shared
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let recorder = makeDiagnosticRecorderHarness()
        let panel = TeleprompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 300)
        )
        let controller = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 360),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let observers = DiagnosticObserverSet(
            recorder: recorder.recorder,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter,
            correlationProvider: { correlationID },
            observationPhaseProvider: observationPhaseProvider,
            postCorrelationQuitEligibilityProvider: postCorrelationQuitEligibilityProvider,
            focusScheduler: focusScheduler
        )
        return ObserverHarness(
            recorder: recorder,
            observers: observers,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter,
            panel: panel,
            controller: controller
        )
    }

    private func settleNotificationTasks() async {
        await Task.yield()
        await Task.yield()
    }

    private func focusState() -> DiagnosticFocusState {
        let window = DiagnosticWindowState(
            isVisible: true,
            isKey: false,
            isMain: false,
            frame: DiagnosticRect(CGRect(x: 0, y: 0, width: 600, height: 300)),
            occlusionState: 0
        )
        return DiagnosticFocusState(
            frontmostProcessIdentifier: 42,
            frontmostBundleIdentifier: "com.apple.Keynote",
            applicationIsActive: false,
            activationPolicy: "regular",
            panel: window,
            controller: window,
            controllerShowCount: 1,
            controllerShielded: true
        )
    }
}

@MainActor
private struct ObserverHarness {
    let recorder: DiagnosticRecorderHarness
    let observers: DiagnosticObserverSet
    let applicationCenter: NotificationCenter
    let workspaceCenter: NotificationCenter
    let panel: NSPanel
    let controller: NSWindow
}

@MainActor
private final class ManualDiagnosticFocusScheduler: DiagnosticFocusScheduler {
    private var nextActions: [ManualScheduledAction] = []
    private var delayedActions: [(milliseconds: Int, action: ManualScheduledAction)] = []

    var delayedMilliseconds: [Int] { delayedActions.map(\.milliseconds) }

    func scheduleNextMainRunLoop(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction {
        let scheduled = ManualScheduledAction(action: action)
        nextActions.append(scheduled)
        return scheduled
    }

    func schedule(
        afterMilliseconds milliseconds: Int,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction {
        let scheduled = ManualScheduledAction(action: action)
        delayedActions.append((milliseconds, scheduled))
        return scheduled
    }

    func runNextMainRunLoop() {
        guard !nextActions.isEmpty else { return }
        nextActions.removeFirst().run()
    }

    func runDelay(milliseconds: Int) {
        guard let index = delayedActions.firstIndex(where: { $0.milliseconds == milliseconds }) else {
            return
        }
        delayedActions.remove(at: index).action.run()
    }

    func runAll() {
        while !nextActions.isEmpty { runNextMainRunLoop() }
        while let delayed = delayedActions.first {
            runDelay(milliseconds: delayed.milliseconds)
        }
    }
}

@MainActor
private final class ManualScheduledAction: DiagnosticScheduledAction {
    private var action: (@MainActor @Sendable () -> Void)?

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    func cancel() {
        action = nil
    }

    func run() {
        let action = action
        self.action = nil
        action?()
    }
}
#endif
