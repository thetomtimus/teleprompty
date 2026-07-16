import Foundation

public enum FocusChromeState: Equatable, Sendable {
    case unlocked
    case lockedChromeVisible
    case lockedFocusChromeVisible
    case lockedFocusChromeHidden
}

public struct FocusDeadlineToken: Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public enum FocusChromeEffect: Equatable, Sendable {
    case setChromeVisible(Bool)
    case scheduleHide(after: TimeInterval, token: FocusDeadlineToken)
    case cancelHide
    case startPointerSampling
    case stopPointerSampling
}

public struct FocusChromeStateMachine: Equatable, Sendable {
    public private(set) var state: FocusChromeState = .unlocked
    private var nextTokenValue: UInt64 = 1
    private var activeDeadline: FocusDeadlineToken?

    public init() {}

    public mutating func update(
        isVisible: Bool,
        isLocked: Bool,
        isFocusModeEnabled: Bool,
        pointerPresent: Bool
    ) -> [FocusChromeEffect] {
        guard isLocked else {
            state = .unlocked
            return cancelAndShowEffects(pointerSampling: false)
        }
        guard isFocusModeEnabled else {
            state = .lockedChromeVisible
            return cancelAndShowEffects(pointerSampling: false)
        }
        guard isVisible else {
            state = .lockedFocusChromeVisible
            return cancelAndShowEffects(pointerSampling: false)
        }
        guard !pointerPresent else {
            state = .lockedFocusChromeVisible
            return cancelAndShowEffects(pointerSampling: true)
        }

        state = .lockedFocusChromeVisible
        let token = FocusDeadlineToken(rawValue: nextTokenValue)
        nextTokenValue += 1
        activeDeadline = token
        return [
            .setChromeVisible(true),
            .cancelHide,
            .startPointerSampling,
            .scheduleHide(after: 2, token: token),
        ]
    }

    public mutating func deadlineFired(_ token: FocusDeadlineToken) -> [FocusChromeEffect] {
        guard activeDeadline == token else { return [] }
        activeDeadline = nil
        state = .lockedFocusChromeHidden
        return [.setChromeVisible(false)]
    }

    public mutating func teardown() -> [FocusChromeEffect] {
        activeDeadline = nil
        return [.cancelHide, .stopPointerSampling]
    }

    private mutating func cancelAndShowEffects(
        pointerSampling: Bool
    ) -> [FocusChromeEffect] {
        activeDeadline = nil
        return [
            .cancelHide,
            pointerSampling ? .startPointerSampling : .stopPointerSampling,
            .setChromeVisible(true),
        ]
    }
}
