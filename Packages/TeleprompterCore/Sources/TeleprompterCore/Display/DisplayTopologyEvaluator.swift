import Foundation

public struct DisplayTopologyEvaluator: Sendable {
    public init() {}

    public func evaluate(
        snapshot: DisplayTopologySnapshot,
        selection: DisplaySelection?
    ) -> DisplayTopologyEvaluation {
        guard snapshot.querySucceeded else {
            return unsafe(.systemQueryFailed)
        }

        let onlineDisplays = snapshot.displays.filter(\.isOnline)
        guard !snapshot.verifiedMirroring else {
            return unsafe(.blockedMirroring)
        }

        let drawableDisplays = onlineDisplays.filter(\.isDrawableDestination)

        guard let selection else {
            return evaluateWithoutSelection(drawableDisplays)
        }

        let matches = drawableDisplays.filter {
            $0.fingerprint.relationship(to: selection.fingerprint) == .match
        }
        let hasAmbiguousRelationship = drawableDisplays.contains {
            $0.fingerprint.relationship(to: selection.fingerprint) == .ambiguous
        }
        let hasConflict = onlineDisplays.contains {
            $0.fingerprint.relationship(to: selection.fingerprint) == .conflict
        }
        let explicitCurrentSelection = explicitlySelectedDisplay(
            from: drawableDisplays,
            selection: selection
        )
        if explicitCurrentSelection == nil,
            hasConflict || hasAmbiguousRelationship || matches.count > 1
        {
            return unsafe(.ambiguousIdentity, requiresConfirmation: true)
        }

        guard let selectedDisplay = explicitCurrentSelection ?? matches.first else {
            let stagedBuiltIn = uniqueBuiltIn(in: drawableDisplays)
            return unsafe(
                .selectedDisplayMissing,
                candidate: stagedBuiltIn,
                requiresConfirmation: true
            )
        }

        guard selection.isConfirmed, selection.isConfirmedInCurrentSession else {
            let reason: DisplayConfirmationReason =
                selectedDisplay.fingerprint.confidence == .weak
                ? .weakIdentity
                : .selectedDisplayNotConfirmed
            return unsafe(
                .confirmationRequired(reason: reason),
                candidate: selectedDisplay,
                requiresConfirmation: true
            )
        }

        if onlineDisplays.count == 1 {
            return DisplayTopologyEvaluation(
                assessment: .singleDisplayNoAudienceSeparation,
                candidate: selectedDisplay,
                recovery: .eligible
            )
        }

        return DisplayTopologyEvaluation(
            assessment: .safeCandidate,
            candidate: selectedDisplay,
            recovery: .eligible
        )
    }

    public func isPersistenceEligible(
        _ fingerprint: DisplayFingerprint,
        in displays: [DisplayDescriptor]
    ) -> Bool {
        guard let key = fingerprint.persistentIdentityKey else { return false }
        let onlineFingerprints = displays
            .filter(\.isOnline)
            .map(\.fingerprint)
        guard onlineFingerprints.filter({
            $0.persistentIdentityKey == key
        }).count == 1 else { return false }

        let relationships = onlineFingerprints.map {
            $0.relationship(to: fingerprint)
        }
        return relationships.filter { $0 == .match }.count == 1
            && !relationships.contains(.conflict)
    }

    private func evaluateWithoutSelection(
        _ displays: [DisplayDescriptor]
    ) -> DisplayTopologyEvaluation {
        guard let builtIn = uniqueBuiltIn(in: displays) else {
            return unsafe(.selectionRequired, requiresConfirmation: true)
        }

        return unsafe(
            .confirmationRequired(reason: .firstRun),
            candidate: builtIn,
            requiresConfirmation: true
        )
    }

    private func uniqueBuiltIn(
        in displays: [DisplayDescriptor]
    ) -> DisplayDescriptor? {
        let builtIns = displays.filter(\.isBuiltIn)
        return builtIns.count == 1 ? builtIns[0] : nil
    }

    private func unsafe(
        _ assessment: DisplayPrivacyAssessment,
        candidate: DisplayDescriptor? = nil,
        requiresConfirmation: Bool = false
    ) -> DisplayTopologyEvaluation {
        DisplayTopologyEvaluation(
            assessment: assessment,
            candidate: candidate,
            recovery: requiresConfirmation
                ? .hiddenPausedUntilConfirmation
                : .hiddenPaused
        )
    }

    private func explicitlySelectedDisplay(
        from displays: [DisplayDescriptor],
        selection: DisplaySelection
    ) -> DisplayDescriptor? {
        guard
            selection.isConfirmed,
            selection.isConfirmedInCurrentSession,
            let sessionID = selection.currentSessionID,
            let selected = displays.first(where: { $0.sessionID == sessionID }),
            selected.fingerprint.relationship(to: selection.fingerprint) != .noMatch,
            selected.fingerprint.relationship(to: selection.fingerprint) != .conflict
        else {
            return nil
        }
        return selected
    }

}
