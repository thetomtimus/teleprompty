import Foundation
import TeleprompterCore

/// An opaque, single-use capability created only by `AppModel.requestClear`.
struct ClearToken: Equatable, Hashable, Sendable {
    private let value: UUID

    static func issue() -> ClearToken {
        ClearToken(value: UUID())
    }
}

enum AppCommand {
    case replaceScript(text: String)
    case applyScriptEdit(ScriptTextEdit)
    case readerResyncRequested(appliedRevision: UInt64)
    case setScriptTitle(String)
    case setFontSize(Double)
    case setTextAlignment(TeleprompterTextAlignment)
    case setActiveBandEnabled(Bool)
    case requestClear
    case confirmClear(token: ClearToken)
    case cancelClear
    case completePreClearFlush(
        token: ClearToken,
        persistedRevision: UInt64,
        succeeded: Bool
    )

    case start
    case pause
    case togglePlayback
    case restart

    case showOverlay
    case hideOverlay
    case setLocked(Bool)

    case restore(PersistedSnapshot?)
    case restoreFailed
    case flushPersistence

    case topologyWillChange
    case displayInventoryLoaded(RuntimeDisplayInventory)
    case displayInventoryFailed
    case selectDisplay(UInt32?)
    case confirmSelectedDisplay
    case completeShieldedMove(screenID: UInt32)
    case keepScriptHidden
}
