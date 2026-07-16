import Foundation

enum PerformanceSignpostCategory: String, CaseIterable, Sendable {
    case load
    case layout
    case edit
    case scroll
    case persistence
}

enum PerformanceSignpostOperation: String, CaseIterable, Sendable {
    case restoreToInteractive = "restore-to-interactive"
    case readerLayout = "reader-layout"
    case editToVisible = "edit-to-visible"
    case scrollSession = "scroll-session"
    case scrollTick = "scroll-tick"
    case snapshotEncode = "snapshot-encode"
    case snapshotWrite = "snapshot-write"
    case snapshotFlush = "snapshot-flush"

    var category: PerformanceSignpostCategory {
        switch self {
        case .restoreToInteractive:
            .load
        case .readerLayout:
            .layout
        case .editToVisible:
            .edit
        case .scrollSession, .scrollTick:
            .scroll
        case .snapshotEncode, .snapshotWrite, .snapshotFlush:
            .persistence
        }
    }
}

enum PerformanceSignpostOutcome: String, CaseIterable, Sendable {
    case success
    case failure
    case cancelled
}

enum PerformanceSignpostReason: String, CaseIterable, Sendable {
    case initial
    case restore
    case resync
    case debounced
    case flush
}

struct PerformanceSignpostToken: Hashable, Sendable {
    let rawValue: UInt64
}

protocol PerformanceSignposting: Sendable {
    var isEnabled: Bool { get }

    func beginInterval(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceSignpostToken?

    func endInterval(
        _ token: PerformanceSignpostToken,
        outcome: PerformanceSignpostOutcome
    )
}

struct DisabledPerformanceSignposter: PerformanceSignposting {
    let isEnabled = false

    func beginInterval(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceSignpostToken? {
        nil
    }

    func endInterval(
        _ token: PerformanceSignpostToken,
        outcome: PerformanceSignpostOutcome
    ) {}
}
