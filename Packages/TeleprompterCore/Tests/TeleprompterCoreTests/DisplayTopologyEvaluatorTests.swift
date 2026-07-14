import XCTest

@testable import TeleprompterCore

final class DisplayTopologyEvaluatorTests: XCTestCase {
    func testQueryFailureIsUnsafe() {
        let result = evaluate(displays: [], querySucceeded: false)

        XCTAssertEqual(result.assessment, .systemQueryFailed)
        XCTAssertTrue(result.recovery.mustPause)
        XCTAssertTrue(result.recovery.mustHide)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testDuplicateZeroSerialDisplaysAreAmbiguous() {
        let ambiguous = DisplayFingerprint(
            uuid: nil,
            vendorID: 10,
            modelID: 20,
            serialNumber: 0,
            isBuiltIn: false,
            lastLocalizedName: "Generated Display",
            confidence: .weak
        )
        let first = display(id: 10, name: "Generated Display A", fingerprint: ambiguous)
        let second = display(id: 11, name: "Generated Display B", fingerprint: ambiguous)

        let result = evaluate(
            displays: [first, second],
            selection: .init(fingerprint: ambiguous, isConfirmed: true)
        )

        XCTAssertEqual(result.assessment, .ambiguousIdentity)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
        XCTAssertNil(ambiguous.persistentIdentityKey)
    }

    func testZeroVendorModelAndSerialAreNotStrongIdentity() {
        let fingerprint = DisplayFingerprint(
            uuid: nil,
            vendorID: 0,
            modelID: 0,
            serialNumber: 0,
            isBuiltIn: false,
            lastLocalizedName: "Generated Display",
            confidence: .strong
        )

        XCTAssertNil(fingerprint.normalized.vendorID)
        XCTAssertNil(fingerprint.normalized.modelID)
        XCTAssertNil(fingerprint.normalized.serialNumber)
        XCTAssertNil(fingerprint.persistentIdentityKey)
    }

    func testLocalizedNameDoesNotOverrideHardwareConflict() {
        let selected = DisplayFingerprint(
            uuid: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Same Name",
            confidence: .strong
        )
        let current = DisplayFingerprint(
            uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            vendorID: 1,
            modelID: 999,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Same Name",
            confidence: .strong
        )

        XCTAssertEqual(current.relationship(to: selected), .conflict)
    }

    func testCompleteHardwareFallbackRequiresMeaningfulSerial() {
        let selected = DisplayFingerprint(
            uuid: nil,
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Old Name",
            confidence: .medium
        )
        let renamed = DisplayFingerprint(
            uuid: nil,
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "New Name",
            confidence: .medium
        )
        var incomplete = renamed
        incomplete.serialNumber = 0

        XCTAssertEqual(renamed.relationship(to: selected), .match)
        XCTAssertEqual(incomplete.relationship(to: selected), .ambiguous)
    }

    func testCompleteHardwareFallbackMatchesWhenOnlyOneSideHasUUID() {
        let selected = DisplayFingerprint(
            uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Old Name",
            confidence: .strong
        )
        var current = selected
        current.uuid = nil
        current.lastLocalizedName = "New Name"

        XCTAssertEqual(current.relationship(to: selected), .match)
        XCTAssertEqual(selected.relationship(to: current), .match)

        current.modelID = 999
        XCTAssertEqual(current.relationship(to: selected), .noMatch)
        XCTAssertEqual(selected.relationship(to: current), .noMatch)
    }

    func testExplicitCurrentSessionChoiceDoesNotMakeDuplicateIdentityPersistable() {
        let duplicate = fingerprint(
            uuid: "duplicate",
            name: "Generated Display",
            confidence: .strong
        )
        let first = display(id: 50, name: "Generated Display A", fingerprint: duplicate)
        let second = display(id: 51, name: "Generated Display B", fingerprint: duplicate)

        let result = evaluate(
            displays: [first, second],
            selection: .init(
                fingerprint: duplicate,
                isConfirmed: true,
                isConfirmedInCurrentSession: true,
                currentSessionID: second.sessionID
            )
        )

        XCTAssertEqual(result.assessment, .safeCandidate)
        XCTAssertEqual(result.candidate?.sessionID, second.sessionID)
        XCTAssertFalse(
            DisplayTopologyEvaluator().isPersistenceEligible(
                duplicate,
                in: [first, second]
            )
        )
    }

    func testMixedUUIDAndHardwareDuplicateIsNotPersistenceEligible() {
        let withUUID = DisplayFingerprint(
            uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Generated Display A",
            confidence: .strong
        )
        var hardwareOnly = withUUID
        hardwareOnly.uuid = nil
        hardwareOnly.lastLocalizedName = "Generated Display B"
        let displays = [
            display(id: 60, name: "Generated Display A", fingerprint: withUUID),
            display(id: 61, name: "Generated Display B", fingerprint: hardwareOnly),
        ]
        let evaluator = DisplayTopologyEvaluator()

        XCTAssertFalse(evaluator.isPersistenceEligible(withUUID, in: displays))
        XCTAssertFalse(evaluator.isPersistenceEligible(hardwareOnly, in: displays))
    }

    func testAmbiguousFingerprintCannotRestoreAcrossSessionWithoutConfirmation() {
        let ambiguous = DisplayFingerprint(
            uuid: nil,
            vendorID: 1,
            modelID: 2,
            serialNumber: 0,
            isBuiltIn: false,
            lastLocalizedName: "Generated Display",
            confidence: .weak
        )
        let current = display(id: 80, name: "Generated Display", fingerprint: ambiguous)

        let result = evaluate(
            displays: [current],
            selection: .init(
                fingerprint: ambiguous,
                isConfirmed: true,
                isConfirmedInCurrentSession: false
            )
        )

        XCTAssertEqual(result.assessment, .ambiguousIdentity)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testDistinctUUIDsRemainDistinctDespiteMatchingHardware() {
        let first = DisplayFingerprint(
            uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Generated Display",
            confidence: .strong
        )
        var second = first
        second.uuid = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

        XCTAssertEqual(first.relationship(to: second), .noMatch)
        let displays = [
            display(id: 70, name: "Generated Display A", fingerprint: first),
            display(id: 71, name: "Generated Display B", fingerprint: second),
        ]
        let evaluator = DisplayTopologyEvaluator()
        XCTAssertTrue(evaluator.isPersistenceEligible(first, in: displays))
        XCTAssertTrue(evaluator.isPersistenceEligible(second, in: displays))
    }

    func testMirroredSelectionBlocksOpening() {
        let privateDisplay = display(
            id: 1,
            name: "Built-in Display",
            builtIn: true,
            mirroredSessionIDs: [2]
        )
        let projector = display(id: 2, name: "Projector", mirrorSourceSessionID: 1)

        let result = evaluate(
            displays: [privateDisplay, projector],
            selection: .init(fingerprint: privateDisplay.fingerprint, isConfirmed: true)
        )

        XCTAssertEqual(result.assessment, .blockedMirroring)
        XCTAssertFalse(result.canOpenOverlay)
        XCTAssertTrue(result.recovery.mustPause)
        XCTAssertTrue(result.recovery.mustHide)
    }

    func testMirrorSourceStillBlocksOpening() {
        let source = display(id: 1, name: "Built-in Display", builtIn: true)
        let mirror = display(id: 2, name: "Projector", mirrorSourceSessionID: 1)

        let result = evaluate(
            displays: [source, mirror],
            selection: .init(fingerprint: source.fingerprint, isConfirmed: true)
        )

        XCTAssertEqual(result.assessment, .blockedMirroring)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testVerifiedMirroringRequiresHardwareMirrorFacts() {
        let first = display(id: 1, name: "Built-in Display", builtIn: true)
        let second = display(id: 2, name: "Projector")

        XCTAssertFalse(
            DisplayTopologySnapshot(displays: [first, second], querySucceeded: true)
                .verifiedMirroring
        )

        var mirrored = second
        mirrored.isInHardwareMirrorSet = true
        XCTAssertTrue(
            DisplayTopologySnapshot(displays: [first, mirrored], querySucceeded: true)
                .verifiedMirroring
        )
    }

    func testDistinctExtendedDisplaysAreNotMislabelledMirrored() {
        let privateDisplay = display(id: 1, name: "Built-in Display", builtIn: true)
        let projector = display(id: 2, name: "Projector")

        let result = evaluate(
            displays: [privateDisplay, projector],
            selection: .init(
                fingerprint: privateDisplay.fingerprint,
                isConfirmed: true,
                isConfirmedInCurrentSession: true,
                currentSessionID: privateDisplay.sessionID
            )
        )

        XCTAssertEqual(result.assessment, .safeCandidate)
        XCTAssertTrue(result.canOpenOverlay)
    }

    func testCGOnlyDisplayCannotBecomeSelectedDestination() {
        var cgOnly = display(id: 2, name: "CoreGraphics only")
        cgOnly.bounds = nil
        cgOnly.visibleFrame = nil
        cgOnly.scale = nil

        let result = evaluate(
            displays: [cgOnly],
            selection: .init(
                fingerprint: cgOnly.fingerprint,
                isConfirmed: true,
                isConfirmedInCurrentSession: true,
                currentSessionID: cgOnly.sessionID
            )
        )

        XCTAssertEqual(result.assessment, .selectedDisplayMissing)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testNoBuiltInRequiresSelection() {
        let projector = display(id: 20, name: "Projector")
        let confidenceMonitor = display(id: 21, name: "Confidence Monitor")

        let result = evaluate(displays: [projector, confidenceMonitor])

        XCTAssertEqual(result.assessment, .selectionRequired)
        XCTAssertNil(result.candidate)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
    }

    func testAmbiguousFingerprintRequiresConfirmation() {
        let repeatedFingerprint = fingerprint(
            uuid: "duplicated-uuid",
            name: "Identical Display",
            confidence: .medium
        )
        let first = display(id: 10, name: "Identical Display", fingerprint: repeatedFingerprint)
        let second = display(id: 11, name: "Identical Display", fingerprint: repeatedFingerprint)

        let result = evaluate(
            displays: [first, second],
            selection: .init(fingerprint: repeatedFingerprint, isConfirmed: true)
        )

        XCTAssertEqual(result.assessment, .ambiguousIdentity)
        XCTAssertNil(result.candidate)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testRemovedSelectionReturnsHiddenPausedRecovery() {
        let removed = fingerprint(uuid: "removed", name: "Removed Display")
        let builtIn = display(id: 1, name: "Built-in Display", builtIn: true)

        let result = evaluate(
            displays: [builtIn],
            selection: .init(fingerprint: removed, isConfirmed: true)
        )

        XCTAssertEqual(result.assessment, .selectedDisplayMissing)
        XCTAssertEqual(result.candidate, builtIn)
        XCTAssertTrue(result.recovery.mustPause)
        XCTAssertTrue(result.recovery.mustHide)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testEvaluatorNeverAutoSelectsExternalDisplay() {
        let external = display(id: 2, name: "Audience Projector")

        let result = evaluate(displays: [external])

        XCTAssertEqual(result.assessment, .selectionRequired)
        XCTAssertNil(result.candidate)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testWeakFingerprintMatchNeverAutoConfirms() {
        let weakFingerprint = fingerprint(
            uuid: "weak-display",
            name: "Unverified Display",
            confidence: .weak
        )
        let display = display(
            id: 30,
            name: "Unverified Display",
            fingerprint: weakFingerprint
        )

        let result = evaluate(
            displays: [display],
            selection: .init(
                fingerprint: weakFingerprint,
                isConfirmed: true
            )
        )

        XCTAssertEqual(result.assessment, .confirmationRequired(reason: .weakIdentity))
        XCTAssertEqual(result.candidate, display)
        XCTAssertTrue(result.recovery.mustPause)
        XCTAssertTrue(result.recovery.mustHide)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testTopologySessionRequiresFreshConfirmationForStrongFingerprint() {
        let privateDisplay = display(id: 1, name: "Built-in Display", builtIn: true)
        let projector = display(id: 2, name: "Projector")

        let result = evaluate(
            displays: [privateDisplay, projector],
            selection: .init(
                fingerprint: privateDisplay.fingerprint,
                isConfirmed: true,
                isConfirmedInCurrentSession: false
            )
        )

        XCTAssertEqual(
            result.assessment,
            .confirmationRequired(reason: .selectedDisplayNotConfirmed)
        )
        XCTAssertTrue(result.recovery.mustPause)
        XCTAssertTrue(result.recovery.mustHide)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testDistinctUUIDWithMatchingHardwareDoesNotMatch() {
        let selectedFingerprint = fingerprint(
            uuid: "previous-uuid",
            name: "Private Display"
        )
        let currentFingerprint = fingerprint(
            uuid: "conflicting-uuid",
            name: "Private Display"
        )
        let current = display(
            id: 44,
            name: "Private Display",
            fingerprint: currentFingerprint
        )

        let result = evaluate(
            displays: [current],
            selection: .init(
                fingerprint: selectedFingerprint,
                isConfirmed: true,
                isConfirmedInCurrentSession: true
            )
        )

        XCTAssertEqual(result.assessment, .selectedDisplayMissing)
        XCTAssertTrue(result.recovery.mustHide)
        XCTAssertTrue(result.recovery.requiresExplicitConfirmation)
        XCTAssertFalse(result.canOpenOverlay)
    }

    func testExplicitCurrentSessionSelectionResolvesDuplicateFingerprint() {
        let duplicate = fingerprint(
            uuid: "duplicate",
            name: "Identical Display",
            confidence: .weak
        )
        let first = display(id: 50, name: "Identical Display", fingerprint: duplicate)
        let second = display(id: 51, name: "Identical Display", fingerprint: duplicate)

        let result = evaluate(
            displays: [first, second],
            selection: .init(
                fingerprint: duplicate,
                isConfirmed: true,
                isConfirmedInCurrentSession: true,
                currentSessionID: second.sessionID
            )
        )

        XCTAssertEqual(result.assessment, .safeCandidate)
        XCTAssertEqual(result.candidate, second)
        XCTAssertTrue(result.canOpenOverlay)
    }

    private func evaluate(
        displays: [DisplayDescriptor],
        querySucceeded: Bool = true,
        selection: DisplaySelection? = nil
    ) -> DisplayTopologyEvaluation {
        DisplayTopologyEvaluator().evaluate(
            snapshot: .init(displays: displays, querySucceeded: querySucceeded),
            selection: selection
        )
    }

    private func display(
        id: UInt32,
        name: String,
        builtIn: Bool = false,
        fingerprint suppliedFingerprint: DisplayFingerprint? = nil,
        mirrorSourceSessionID: UInt32? = nil,
        mirroredSessionIDs: Set<UInt32> = []
    ) -> DisplayDescriptor {
        DisplayDescriptor(
            sessionID: id,
            fingerprint: suppliedFingerprint
                ?? fingerprint(
                    uuid: "uuid-\(id)",
                    name: name,
                    builtIn: builtIn
                ),
            localizedName: name,
            isBuiltIn: builtIn,
            isMain: builtIn,
            isOnline: true,
            bounds: .init(x: 0, y: 0, width: 1_920, height: 1_080),
            visibleFrame: .init(x: 0, y: 0, width: 1_920, height: 1_040),
            scale: 2,
            mirrorSourceSessionID: mirrorSourceSessionID,
            mirroredSessionIDs: mirroredSessionIDs
        )
    }

    private func fingerprint(
        uuid: String,
        name: String,
        builtIn: Bool = false,
        confidence: DisplayFingerprint.Confidence = .strong
    ) -> DisplayFingerprint {
        DisplayFingerprint(
            uuid: uuid,
            vendorID: 1_552,
            modelID: 4_101,
            serialNumber: 7_001,
            isBuiltIn: builtIn,
            lastLocalizedName: name,
            confidence: confidence
        )
    }
}
