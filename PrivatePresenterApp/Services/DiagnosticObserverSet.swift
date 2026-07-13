#if DEBUG
import AppKit

@MainActor
protocol DiagnosticScheduledAction: AnyObject {
    func cancel()
}

@MainActor
protocol DiagnosticFocusScheduler: AnyObject {
    func scheduleNextMainRunLoop(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction
    func schedule(
        afterMilliseconds milliseconds: Int,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction
}

@MainActor
final class SystemDiagnosticFocusScheduler: DiagnosticFocusScheduler {
    func scheduleNextMainRunLoop(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction {
        let item = DispatchWorkItem {
            MainActor.assumeIsolated { action() }
        }
        let scheduled = DiagnosticDispatchAction(item: item)
        DispatchQueue.main.async(execute: item)
        return scheduled
    }

    func schedule(
        afterMilliseconds milliseconds: Int,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any DiagnosticScheduledAction {
        let item = DispatchWorkItem {
            MainActor.assumeIsolated { action() }
        }
        let scheduled = DiagnosticDispatchAction(item: item)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds),
            execute: item
        )
        return scheduled
    }
}

@MainActor
private final class DiagnosticDispatchAction: DiagnosticScheduledAction {
    private var item: DispatchWorkItem?

    init(item: DispatchWorkItem) {
        self.item = item
    }

    func cancel() {
        item?.cancel()
        item = nil
    }
}

@MainActor
final class DiagnosticObserverSet {
    typealias CorrelationProvider = @MainActor () -> UUID?
    typealias ObservationPhaseProvider = @MainActor () -> DiagnosticObservationPhase

    private let recorder: DiagnosticEvidenceRecorder
    private let applicationCenter: NotificationCenter
    private let workspaceCenter: NotificationCenter
    private let correlationProvider: CorrelationProvider
    private let observationPhaseProvider: ObservationPhaseProvider
    private let focusScheduler: any DiagnosticFocusScheduler
    private var applicationTokens: [NSObjectProtocol] = []
    private var workspaceTokens: [NSObjectProtocol] = []
    private var generation: UInt64 = 0
    private var scheduledFocusActions: [UUID: [any DiagnosticScheduledAction]] = [:]
    private(set) var isInstalled = false

    init(
        recorder: DiagnosticEvidenceRecorder,
        applicationCenter: NotificationCenter = .default,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        correlationProvider: @escaping CorrelationProvider = { nil },
        observationPhaseProvider: @escaping ObservationPhaseProvider = { .correlatedAction },
        focusScheduler: any DiagnosticFocusScheduler = SystemDiagnosticFocusScheduler()
    ) {
        self.recorder = recorder
        self.applicationCenter = applicationCenter
        self.workspaceCenter = workspaceCenter
        self.correlationProvider = correlationProvider
        self.observationPhaseProvider = observationPhaseProvider
        self.focusScheduler = focusScheduler
    }

    func install(panel: NSPanel, controller: NSWindow?) {
        guard !isInstalled else { return }
        generation &+= 1
        let installedGeneration = generation
        isInstalled = true

        observeApplication(
            NSApplication.willBecomeActiveNotification,
            lifecycle: .willBecomeActive,
            generation: installedGeneration
        )
        observeApplication(
            NSApplication.didBecomeActiveNotification,
            lifecycle: .didBecomeActive,
            generation: installedGeneration
        )
        observeApplication(
            NSApplication.willResignActiveNotification,
            lifecycle: .willResignActive,
            generation: installedGeneration
        )
        observeApplication(
            NSApplication.didResignActiveNotification,
            lifecycle: .didResignActive,
            generation: installedGeneration
        )

        let workspaceToken = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.accepts(generation: installedGeneration) else { return }
                self.recorder.record(
                    kind: .workspaceActivation,
                    correlationID: self.correlationProvider(),
                    payload: DiagnosticEventPayload(
                        workspaceActivation: .didActivateApplication,
                        observationPhase: self.observationPhaseProvider()
                    )
                )
            }
        }
        workspaceTokens.append(workspaceToken)

        observeWindow(panel, owner: .panel, generation: installedGeneration)
        if let controller {
            observeWindow(controller, owner: .controller, generation: installedGeneration)
        }
    }

    func tearDown() {
        guard isInstalled else { return }
        generation &+= 1
        isInstalled = false
        for action in scheduledFocusActions.values.flatMap({ $0 }) {
            action.cancel()
        }
        scheduledFocusActions.removeAll(keepingCapacity: false)
        for token in applicationTokens {
            applicationCenter.removeObserver(token)
        }
        for token in workspaceTokens {
            workspaceCenter.removeObserver(token)
        }
        applicationTokens.removeAll(keepingCapacity: false)
        workspaceTokens.removeAll(keepingCapacity: false)
    }

    func scheduleFocusSamples(
        correlationID: UUID,
        capture: @escaping @MainActor @Sendable () -> DiagnosticFocusState,
        onClosed: @escaping @MainActor @Sendable () -> Void
    ) {
        guard isInstalled else { return }
        let scheduledGeneration = generation
        recorder.record(
            kind: .focusImmediate,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(focus: capture())
        )

        let next = focusScheduler.scheduleNextMainRunLoop { [weak self] in
            guard let self, self.accepts(generation: scheduledGeneration) else { return }
            self.recorder.record(
                kind: .focusNextMainRunLoop,
                correlationID: correlationID,
                payload: DiagnosticEventPayload(focus: capture())
            )
        }
        let delayed100 = focusScheduler.schedule(afterMilliseconds: 100) { [weak self] in
            guard let self, self.accepts(generation: scheduledGeneration) else { return }
            self.recorder.record(
                kind: .focusDelayed100Milliseconds,
                correlationID: correlationID,
                payload: DiagnosticEventPayload(focus: capture())
            )
        }
        let delayed500 = focusScheduler.schedule(afterMilliseconds: 500) { [weak self] in
            guard let self, self.accepts(generation: scheduledGeneration) else { return }
            self.recorder.record(
                kind: .focusDelayed500Milliseconds,
                correlationID: correlationID,
                payload: DiagnosticEventPayload(focus: capture())
            )
            let close = self.focusScheduler.scheduleNextMainRunLoop { [weak self] in
                guard let self, self.accepts(generation: scheduledGeneration) else { return }
                self.recorder.record(
                    kind: .correlationWindowClosed,
                    correlationID: correlationID
                )
                self.scheduledFocusActions.removeValue(forKey: correlationID)
                onClosed()
            }
            self.scheduledFocusActions[correlationID]?.append(close)
        }
        scheduledFocusActions[correlationID] = [next, delayed100, delayed500]
    }

    func cancelFocusSamples(correlationID: UUID) {
        guard let actions = scheduledFocusActions.removeValue(forKey: correlationID) else {
            return
        }
        for action in actions {
            action.cancel()
        }
    }

    var activeCorrelationCount: Int { scheduledFocusActions.count }

    private func observeApplication(
        _ name: Notification.Name,
        lifecycle: DiagnosticApplicationLifecycle,
        generation: UInt64
    ) {
        let token = applicationCenter.addObserver(
            forName: name,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.accepts(generation: generation) else { return }
                self.recorder.record(
                    kind: .applicationLifecycle,
                    correlationID: self.correlationProvider(),
                    payload: DiagnosticEventPayload(
                        applicationLifecycle: lifecycle,
                        observationPhase: self.observationPhaseProvider()
                    )
                )
            }
        }
        applicationTokens.append(token)
    }

    private func observeWindow(
        _ window: NSWindow,
        owner: DiagnosticWindowOwner,
        generation: UInt64
    ) {
        let observations: [(Notification.Name, DiagnosticWindowLifecycle)] = [
            (NSWindow.didBecomeKeyNotification, .didBecomeKey),
            (NSWindow.didResignKeyNotification, .didResignKey),
            (NSWindow.didBecomeMainNotification, .didBecomeMain),
            (NSWindow.didResignMainNotification, .didResignMain),
            (NSWindow.didChangeOcclusionStateNotification, .didChangeOcclusionState),
        ]
        for (name, lifecycle) in observations {
            let token = applicationCenter.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                MainActor.assumeIsolated {
                    guard
                        let self,
                        let window,
                        self.accepts(generation: generation)
                    else { return }
                    self.recorder.record(
                        kind: .windowLifecycle,
                        correlationID: self.correlationProvider(),
                        payload: DiagnosticEventPayload(
                            windowLifecycle: lifecycle,
                            windowOwner: owner,
                            observationPhase: self.observationPhaseProvider(),
                            panelState: owner == .panel ? window.diagnosticState : nil,
                            controllerState: owner == .controller ? window.diagnosticState : nil
                        )
                    )
                    if lifecycle == .didChangeOcclusionState {
                        self.recorder.record(
                            kind: .windowLifecycle,
                            correlationID: self.correlationProvider(),
                            payload: DiagnosticEventPayload(
                                windowLifecycle: window.isVisible
                                    ? .didOrderOnScreen
                                    : .didOrderOffScreen,
                                windowOwner: owner,
                                observationPhase: self.observationPhaseProvider(),
                                panelState: owner == .panel ? window.diagnosticState : nil,
                                controllerState: owner == .controller
                                    ? window.diagnosticState
                                    : nil
                            )
                        )
                    }
                }
            }
            applicationTokens.append(token)
        }
    }

    private func accepts(generation: UInt64) -> Bool {
        isInstalled && self.generation == generation
    }
}

@MainActor
extension NSWindow {
    var diagnosticState: DiagnosticWindowState {
        DiagnosticWindowState(
            isVisible: isVisible,
            isKey: isKeyWindow,
            isMain: isMainWindow,
            frame: DiagnosticRect(frame),
            occlusionState: occlusionState.rawValue
        )
    }
}
#endif
