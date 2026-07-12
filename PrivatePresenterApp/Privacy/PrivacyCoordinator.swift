import Foundation

/// A pure, deterministic planner. It never invokes adapters or mutates app state.
@MainActor
final class PrivacyCoordinator {
    private(set) var lastDirectives: [PrivacyDirective] = []

    func topologyWillChange(
        confirmedSafeScreenID: UInt32? = nil
    ) -> [PrivacyDirective] {
        plan(confirmedSafeScreenID: confirmedSafeScreenID, isSafe: false)
    }

    func topologyWasEvaluated(
        confirmedSafeScreenID: UInt32?,
        isSafe: Bool
    ) -> [PrivacyDirective] {
        plan(confirmedSafeScreenID: confirmedSafeScreenID, isSafe: isSafe)
    }

    private func plan(
        confirmedSafeScreenID: UInt32?,
        isSafe: Bool
    ) -> [PrivacyDirective] {
        var directives: [PrivacyDirective] = [
            .pauseScrolling,
            .hideOverlay,
            .shieldController,
            .invalidatePendingShow,
            .queryTopology,
            .evaluatePrivacy,
        ]
        if let confirmedSafeScreenID, isSafe {
            directives.append(.moveWindowsWhileShielded(screenID: confirmedSafeScreenID))
            directives.append(.publishSafeState)
        } else {
            directives.append(.requestConfirmation)
        }
        lastDirectives = directives
        return directives
    }
}
