import Foundation

/// Produces fail-closed effects in a fixed, inspectable order. It never publishes a safe
/// state or reveals content before pause/hide/shield/invalidation and a fresh query.
@MainActor
final class PrivacyCoordinator {
    typealias EffectHandler = (PrivacyEffect) -> Void

    private var effectHandler: EffectHandler
    private(set) var lastEffects: [PrivacyEffect] = []

    init(effectHandler: @escaping EffectHandler = { _ in }) {
        self.effectHandler = effectHandler
    }

    func setEffectHandler(_ effectHandler: @escaping EffectHandler) {
        self.effectHandler = effectHandler
    }

    @discardableResult
    func topologyWillChange(confirmedSafeScreenID: UInt32? = nil) -> [PrivacyEffect] {
        execute(terminalEffects(confirmedSafeScreenID: confirmedSafeScreenID, isSafe: false))
    }

    @discardableResult
    func topologyWasEvaluated(
        confirmedSafeScreenID: UInt32?,
        isSafe: Bool
    ) -> [PrivacyEffect] {
        execute(terminalEffects(confirmedSafeScreenID: confirmedSafeScreenID, isSafe: isSafe))
    }

    private func terminalEffects(
        confirmedSafeScreenID: UInt32?,
        isSafe: Bool
    ) -> [PrivacyEffect] {
        var effects: [PrivacyEffect] = [
            .pauseScrolling,
            .hideOverlay,
            .shieldController,
            .invalidatePendingShow,
            .queryTopology,
            .evaluatePrivacy,
        ]
        if let confirmedSafeScreenID, isSafe {
            effects.append(.moveWindowsWhileShielded(screenID: confirmedSafeScreenID))
            effects.append(.publishSafeState)
        } else {
            effects.append(.requestConfirmation)
        }
        return effects
    }

    @discardableResult
    private func execute(_ effects: [PrivacyEffect]) -> [PrivacyEffect] {
        lastEffects = effects
        for effect in effects {
            effectHandler(effect)
        }
        return effects
    }
}
