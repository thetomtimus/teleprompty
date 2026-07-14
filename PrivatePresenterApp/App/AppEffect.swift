import AppKit
import TeleprompterCore

/// Immutable work emitted only after `AppModel` commits authoritative state.
enum AppEffect: Equatable {
    case applyReaderEdit(ScriptTextEdit)
    case replaceReader(text: String, revision: UInt64, reason: ReaderFullReplacementReason)
    case updateReaderAttributes(
        fontSize: Double,
        alignment: TeleprompterTextAlignment,
        activeBandEnabled: Bool
    )
    case scheduleSnapshot(PersistedSnapshot)
    case flushSnapshot(token: ClearToken, requiredRevision: UInt64)
    case saveSnapshotImmediately(PersistedSnapshot)
    case flushPersistence

    case stagePanelHidden(RuntimeDisplay)
    case showPanel(RuntimeDisplay)
    case hidePanel
    case setPanelLocked(Bool)
    case moveControllerWhileShielded(RuntimeDisplay)
    case resetViewport

    case reassessPrivacy
    case queryTopology
    case evaluatePrivacy
}

enum AppLocalError: String, Equatable, Sendable {
    case snapshotLoadFailed
    case snapshotSaveFailed
    case preClearFlushFailed
    case clearRequestInvalidated
}
