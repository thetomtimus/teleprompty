import AppKit

@MainActor
protocol RepeatingScheduling: AnyObject {
    func start(interval: TimeInterval, action: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
protocol PointerPresenceMonitoring: AnyObject {
    func update(isActive: Bool)
    func teardown()
}

@MainActor
final class TaskRepeatingScheduler: RepeatingScheduling {
    private var task: Task<Void, Never>?

    func start(interval: TimeInterval, action: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                action()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
final class PointerPresenceMonitor: PointerPresenceMonitoring {
    static let samplingInterval: TimeInterval = 0.1

    private let scheduler: RepeatingScheduling
    private let locationProvider: @MainActor () -> NSPoint
    private let panelFrameProvider: @MainActor () -> NSRect
    private let onPresenceChanged: @MainActor (Bool) -> Void
    private var isActive = false
    private var lastPresence: Bool?

    init(
        scheduler: RepeatingScheduling,
        locationProvider: @escaping @MainActor () -> NSPoint,
        panelFrameProvider: @escaping @MainActor () -> NSRect,
        onPresenceChanged: @escaping @MainActor (Bool) -> Void
    ) {
        self.scheduler = scheduler
        self.locationProvider = locationProvider
        self.panelFrameProvider = panelFrameProvider
        self.onPresenceChanged = onPresenceChanged
    }

    func update(isActive: Bool) {
        guard self.isActive != isActive else { return }
        self.isActive = isActive
        guard isActive else {
            scheduler.cancel()
            lastPresence = nil
            return
        }
        scheduler.start(interval: Self.samplingInterval) { [weak self] in
            self?.sample()
        }
    }

    func teardown() {
        isActive = false
        lastPresence = nil
        scheduler.cancel()
    }

    private func sample() {
        let presence = panelFrameProvider().contains(locationProvider())
        guard presence != lastPresence else { return }
        lastPresence = presence
        onPresenceChanged(presence)
    }
}
