import Foundation

enum PrivacyEffect: Equatable, Sendable {
    case pauseScrolling
    case hideOverlay
    case shieldController
    case invalidatePendingShow
    case queryTopology
    case evaluatePrivacy
    case moveWindowsWhileShielded(screenID: UInt32)
    case requestConfirmation
    case publishSafeState
}
