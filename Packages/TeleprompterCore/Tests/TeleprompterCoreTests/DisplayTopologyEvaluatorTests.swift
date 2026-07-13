import XCTest

@testable import TeleprompterCore

final class DisplayTopologyEvaluatorTests: XCTestCase {
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

    func testConflictingUUIDWithMatchingHardwareIsAmbiguous() {
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

        XCTAssertEqual(result.assessment, .ambiguousIdentity)
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
