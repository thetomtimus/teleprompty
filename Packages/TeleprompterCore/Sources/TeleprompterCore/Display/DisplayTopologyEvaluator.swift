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
            identityRelationship($0.fingerprint, selection.fingerprint) == .match
        }
        let hasConflict = onlineDisplays.contains {
            identityRelationship($0.fingerprint, selection.fingerprint) == .conflict
        }
        let explicitCurrentSelection = explicitlySelectedDisplay(
            from: drawableDisplays,
            selection: selection
        )
        if explicitCurrentSelection == nil, hasConflict || matches.count > 1 {
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

    private enum IdentityRelationship {
        case noMatch
        case match
        case conflict
    }

    private func identityRelationship(
        _ current: DisplayFingerprint,
        _ selected: DisplayFingerprint
    ) -> IdentityRelationship {
        if let currentUUID = current.uuid, let selectedUUID = selected.uuid {
            guard currentUUID == selectedUUID else {
                return hardwareMatches(current, selected) ? .conflict : .noMatch
            }
            return hardwareConflicts(current, selected) ? .conflict : .match
        }

        guard
            current.isBuiltIn == selected.isBuiltIn,
            current.vendorID == selected.vendorID,
            current.modelID == selected.modelID
        else {
            return .noMatch
        }

        if let currentSerial = meaningfulSerial(current.serialNumber),
            let selectedSerial = meaningfulSerial(selected.serialNumber)
        {
            return currentSerial == selectedSerial ? .match : .noMatch
        }

        guard current.confidence == .weak || selected.confidence == .weak else {
            return .noMatch
        }
        return current.lastLocalizedName == selected.lastLocalizedName ? .match : .noMatch
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
            identityRelationship(selected.fingerprint, selection.fingerprint) == .match
        else {
            return nil
        }
        return selected
    }

    private func hardwareConflicts(
        _ lhs: DisplayFingerprint,
        _ rhs: DisplayFingerprint
    ) -> Bool {
        conflicts(lhs.vendorID, rhs.vendorID)
            || conflicts(lhs.modelID, rhs.modelID)
            || conflicts(meaningfulSerial(lhs.serialNumber), meaningfulSerial(rhs.serialNumber))
            || lhs.isBuiltIn != rhs.isBuiltIn
    }

    private func hardwareMatches(
        _ lhs: DisplayFingerprint,
        _ rhs: DisplayFingerprint
    ) -> Bool {
        guard
            lhs.vendorID != nil,
            lhs.vendorID == rhs.vendorID,
            lhs.modelID != nil,
            lhs.modelID == rhs.modelID,
            lhs.isBuiltIn == rhs.isBuiltIn
        else {
            return false
        }
        if let lhsSerial = meaningfulSerial(lhs.serialNumber),
            let rhsSerial = meaningfulSerial(rhs.serialNumber)
        {
            return lhsSerial == rhsSerial
        }
        return true
    }

    private func conflicts<T: Equatable>(_ lhs: T?, _ rhs: T?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs != rhs
    }

    private func meaningfulSerial(_ serial: UInt32?) -> UInt32? {
        guard let serial, serial != 0 else { return nil }
        return serial
    }
}
