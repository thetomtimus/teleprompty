import AppKit
import TeleprompterCore

/// Immutable work emitted only after `AppModel` commits authoritative state.
enum AppEffect: Equatable {
    case startScrollSession(binding: ScrollSessionBinding, uptime: TimeInterval)
    case stopScrollSession(
        retiring: ScrollSessionGeneration,
        replacement: ScrollSessionGeneration,
        reason: ScrollRetirementReason,
        fallbackAnchor: ReadingAnchor,
        fallbackOffset: Double
    )
    case updateScrollSpeed(ScrollSessionGeneration, Double, TimeInterval)
    case moveScrollSession(
        binding: ScrollSessionBinding,
        direction: ScrollManualDirection,
        uptime: TimeInterval
    )
    case readerAttachmentChanged(isAttached: Bool, binding: ScrollSessionBinding)
    case readerScreenChanged(ScrollSessionBinding)
    case restoreScrollLayout(ScrollSessionBinding)
    case teardownScrollSession(ScrollSessionGeneration)
    case applyReaderEdit(
        edit: ScriptTextEdit,
        preEditDocument: String,
        postEditDocument: String,
        generation: ScrollSessionGeneration,
        wasPlaying: Bool
    )
    case replaceReader(
        text: String,
        revision: UInt64,
        reason: ReaderFullReplacementReason,
        generation: ScrollSessionGeneration,
        anchor: ReadingAnchor?
    )
    case updateReaderAttributes(
        fontSize: Double,
        alignment: TeleprompterTextAlignment,
        activeBandEnabled: Bool,
        generation: ScrollSessionGeneration,
        anchor: ReadingAnchor?
    )
    case scheduleSnapshot(PersistedSnapshot)
    case flushSnapshot(token: ClearToken, requiredRevision: UInt64)
    case saveSnapshotImmediately(PersistedSnapshot)
    case flushPersistence
    case reconfigureHotKeys([ShortcutBinding])
    case retryHotKeys

    case stagePanelHidden(RuntimeDisplay, proposedFrame: CGRect?)
    case showPanel(RuntimeDisplay, proposedFrame: CGRect?)
    case hidePanel
    case setPanelLocked(Bool)
    case moveControllerWhileShielded(RuntimeDisplay)
    case resetViewport(ScrollSessionGeneration)

    case reassessPrivacy
    case queryTopology
    case evaluatePrivacy
}

enum AppLocalError: String, Equatable, Sendable {
    case snapshotLoadFailed
    case snapshotSaveFailed
    case preClearFlushFailed
    case clearRequestInvalidated
    case invalidShortcutConfiguration
    case globalShortcutConflict
    case globalShortcutCleanupUnknown
}
