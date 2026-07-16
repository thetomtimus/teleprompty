import Foundation

enum AppLifecycleEvent: Equatable, Sendable {
    case rejectMutations
    case pauseAndCapture
    case hideAndShield
    case stagePausedSnapshot
    case flushPausedSnapshot
    case flushFailed
    case enterQuiescence
    case closeCarbonDispatch
    case unregisterHotKeys
    case stopFocusPointerDisplay
    case teardownScrollSession
    case removeStatusItem
    case closeController
    case terminateReady
}

@MainActor
final class AppLifecycleCoordinator {
    private let model: AppModel
    private let flushPausedSnapshot: @MainActor () async -> Bool
    private let closeCarbonDispatch: @MainActor () async -> Void
    private let unregisterHotKeys: @MainActor () async -> Void
    private let stopFocusPointerDisplay: @MainActor () async -> Void
    private let teardownScrollSession: @MainActor () async -> Void
    private let removeStatusItem: @MainActor () async -> Void
    private let closeController: @MainActor () async -> Void
    private let record: @MainActor (AppLifecycleEvent) -> Void
    private var completed = false
    private var nextAttemptID: UInt64 = 0
    private var inFlight: (id: UInt64, task: Task<Bool, Never>)?

    init(
        model: AppModel,
        flushPausedSnapshot: @escaping @MainActor () async -> Bool,
        closeCarbonDispatch: @escaping @MainActor () async -> Void = {},
        unregisterHotKeys: @escaping @MainActor () async -> Void,
        stopFocusPointerDisplay: @escaping @MainActor () async -> Void,
        teardownScrollSession: @escaping @MainActor () async -> Void,
        removeStatusItem: @escaping @MainActor () async -> Void,
        closeController: @escaping @MainActor () async -> Void,
        record: @escaping @MainActor (AppLifecycleEvent) -> Void = { _ in }
    ) {
        self.model = model
        self.flushPausedSnapshot = flushPausedSnapshot
        self.closeCarbonDispatch = closeCarbonDispatch
        self.unregisterHotKeys = unregisterHotKeys
        self.stopFocusPointerDisplay = stopFocusPointerDisplay
        self.teardownScrollSession = teardownScrollSession
        self.removeStatusItem = removeStatusItem
        self.closeController = closeController
        self.record = record
    }

    func stopAndFlush() async -> Bool {
        if completed { return true }
        if let inFlight { return await inFlight.task.value }
        let (attemptID, overflow) = nextAttemptID.addingReportingOverflow(1)
        precondition(!overflow, "Lifecycle attempt generation exhausted")
        nextAttemptID = attemptID
        let task = Task { @MainActor [weak self] in
            await self?.performStopAndFlush() ?? false
        }
        inFlight = (attemptID, task)
        let result = await task.value
        if inFlight?.id == attemptID { inFlight = nil }
        return result
    }

    private func performStopAndFlush() async -> Bool {
        record(.rejectMutations)
        model.send(.beginTerminationAttempt)
        record(.pauseAndCapture)
        model.send(.prepareForTermination)
        record(.hideAndShield)
        record(.stagePausedSnapshot)
        model.send(.stagePausedTerminationSnapshot)
        record(.flushPausedSnapshot)
        guard await flushPausedSnapshot() else {
            model.send(.cancelTerminationAttempt)
            record(.flushFailed)
            return false
        }

        model.send(.enterTerminationQuiescence)
        record(.enterQuiescence)
        record(.closeCarbonDispatch)
        await closeCarbonDispatch()
        record(.unregisterHotKeys)
        await unregisterHotKeys()
        record(.stopFocusPointerDisplay)
        await stopFocusPointerDisplay()
        record(.teardownScrollSession)
        await teardownScrollSession()
        record(.removeStatusItem)
        await removeStatusItem()
        record(.closeController)
        await closeController()
        record(.terminateReady)
        completed = true
        return true
    }
}
