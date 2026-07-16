import AppKit
import TeleprompterCore

struct FocusModeConfiguration: Equatable, Sendable {
    let isVisible: Bool
    let isLocked: Bool
    let isFocusModeEnabled: Bool
    let pointerPresent: Bool
}

@MainActor
protocol FocusDeadlineScheduling: AnyObject {
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class TaskFocusDeadlineScheduler: FocusDeadlineScheduling {
    private var task: Task<Void, Never>?

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
final class FocusModeController {
    private let scheduler: FocusDeadlineScheduling
    private let pointerMonitor: PointerPresenceMonitoring
    private let reduceMotionProvider: @MainActor () -> Bool
    private let setChromeVisible: @MainActor (Bool, TimeInterval) -> Void
    private let stateChanged: @MainActor (FocusChromeState) -> Void
    private let accessibilityOptionsCenter: NotificationCenter
    private var machine = FocusChromeStateMachine()
    private var accessibilityOptionsToken: NSObjectProtocol?
    private var lastConfiguration: FocusModeConfiguration?

    init(
        scheduler: FocusDeadlineScheduling,
        pointerMonitor: PointerPresenceMonitoring,
        reduceMotionProvider: @escaping @MainActor () -> Bool,
        setChromeVisible: @escaping @MainActor (Bool, TimeInterval) -> Void,
        stateChanged: @escaping @MainActor (FocusChromeState) -> Void,
        accessibilityOptionsCenter: NotificationCenter =
            NSWorkspace.shared.notificationCenter
    ) {
        self.scheduler = scheduler
        self.pointerMonitor = pointerMonitor
        self.reduceMotionProvider = reduceMotionProvider
        self.setChromeVisible = setChromeVisible
        self.stateChanged = stateChanged
        self.accessibilityOptionsCenter = accessibilityOptionsCenter
        accessibilityOptionsToken = accessibilityOptionsCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.accessibilityOptionsChanged()
            }
        }
    }

    var transitionDuration: TimeInterval {
        PresenterAccessibility.motionPolicy(
            reduceMotion: reduceMotionProvider()
        ).decorativeFocusDuration
    }

    func apply(_ configuration: FocusModeConfiguration) {
        lastConfiguration = configuration
        execute(
            machine.update(
                isVisible: configuration.isVisible,
                isLocked: configuration.isLocked,
                isFocusModeEnabled: configuration.isFocusModeEnabled,
                pointerPresent: configuration.pointerPresent
            )
        )
        stateChanged(machine.state)
    }

    func teardown() {
        execute(machine.teardown())
        pointerMonitor.teardown()
        lastConfiguration = nil
        if let accessibilityOptionsToken {
            accessibilityOptionsCenter.removeObserver(accessibilityOptionsToken)
            self.accessibilityOptionsToken = nil
        }
    }

    private func accessibilityOptionsChanged() {
        guard lastConfiguration != nil else { return }
        let chromeVisible = machine.state != .lockedFocusChromeHidden
        setChromeVisible(chromeVisible, transitionDuration)
    }

    private func execute(_ effects: [FocusChromeEffect]) {
        for effect in effects {
            switch effect {
            case .setChromeVisible(let visible):
                setChromeVisible(visible, transitionDuration)
            case .scheduleHide(let delay, let token):
                scheduler.schedule(after: delay) { [weak self] in
                    guard let self else { return }
                    self.execute(self.machine.deadlineFired(token))
                    self.stateChanged(self.machine.state)
                }
            case .cancelHide:
                scheduler.cancel()
            case .startPointerSampling:
                pointerMonitor.update(isActive: true)
            case .stopPointerSampling:
                pointerMonitor.update(isActive: false)
            }
        }
    }
}
