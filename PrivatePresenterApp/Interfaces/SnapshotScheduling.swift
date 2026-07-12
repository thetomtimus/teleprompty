import Foundation

protocol SnapshotClock: Sendable {
    func now() -> Date
}

protocol SnapshotSleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

struct SystemSnapshotClock: SnapshotClock {
    func now() -> Date { Date() }
}

struct ContinuousSnapshotSleeper: SnapshotSleeper {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
