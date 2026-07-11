import Foundation

public enum DisplayConfirmationReason: String, Codable, Equatable, Sendable {
    case firstRun
    case selectedDisplayNotConfirmed
    case weakIdentity
}

public enum DisplayPrivacyAssessment: Codable, Equatable, Sendable {
    case safeCandidate
    case blockedMirroring
    case selectionRequired
    case confirmationRequired(reason: DisplayConfirmationReason)
    case selectedDisplayMissing
    case ambiguousIdentity
    case singleDisplayNoAudienceSeparation
    case systemQueryFailed
}

public struct DisplayRecoveryDirectives: Equatable, Sendable {
    public var mustPause: Bool
    public var mustHide: Bool
    public var requiresExplicitConfirmation: Bool

    public init(
        mustPause: Bool,
        mustHide: Bool,
        requiresExplicitConfirmation: Bool
    ) {
        self.mustPause = mustPause
        self.mustHide = mustHide
        self.requiresExplicitConfirmation = requiresExplicitConfirmation
    }

    public static let eligible = DisplayRecoveryDirectives(
        mustPause: false,
        mustHide: false,
        requiresExplicitConfirmation: false
    )

    public static let hiddenPaused = DisplayRecoveryDirectives(
        mustPause: true,
        mustHide: true,
        requiresExplicitConfirmation: false
    )

    public static let hiddenPausedUntilConfirmation = DisplayRecoveryDirectives(
        mustPause: true,
        mustHide: true,
        requiresExplicitConfirmation: true
    )
}

public struct DisplayTopologyEvaluation: Equatable, Sendable {
    public var assessment: DisplayPrivacyAssessment
    public var candidate: DisplayDescriptor?
    public var recovery: DisplayRecoveryDirectives

    public init(
        assessment: DisplayPrivacyAssessment,
        candidate: DisplayDescriptor?,
        recovery: DisplayRecoveryDirectives
    ) {
        self.assessment = assessment
        self.candidate = candidate
        self.recovery = recovery
    }

    public var canOpenOverlay: Bool {
        !recovery.mustHide
            && (assessment == .safeCandidate
                || assessment == .singleDisplayNoAudienceSeparation)
    }
}
