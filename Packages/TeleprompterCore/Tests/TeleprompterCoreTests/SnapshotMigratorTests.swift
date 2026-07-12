import Foundation
import XCTest
@testable import TeleprompterCore

final class SnapshotMigratorTests: XCTestCase {
    private let fixedID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let fixedDate = Date(timeIntervalSince1970: 1_720_000_000.375)

    func testV1MigratesIdempotently() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: makeSnapshot().canonicalData()) as? [String: Any]
        )
        object.removeValue(forKey: "panelFrames")
        object.removeValue(forKey: "shortcutBindings")
        let input = try JSONSerialization.data(withJSONObject: object)
        let first = try SnapshotMigrator().migrate(input)
        let canonical = try first.canonicalData()
        let second = try SnapshotMigrator().migrate(canonical)

        XCTAssertEqual(first.panelFrames, [])
        XCTAssertEqual(first.shortcutBindings, [])
        XCTAssertEqual(first, second)
        XCTAssertEqual(canonical, try second.canonicalData())
    }

    func testV1MigrationPreservesUnicodeAndRevision() throws {
        let unicode = "Café Cafe\u{301} · 한국어 · 👍🏽 · 👨‍👩‍👧‍👦"
        let input = try makeSnapshot(text: unicode).canonicalData()

        let migrated = try SnapshotMigrator().migrate(input)

        XCTAssertEqual(migrated.revision, 19)
        XCTAssertEqual(migrated.document.revision, 13)
        XCTAssertEqual(migrated.document.id, fixedID)
        XCTAssertEqual(migrated.document.updatedAt, fixedDate)
        XCTAssertEqual(migrated.document.text, unicode)
    }

    func testUnknownFutureSchemaFailsWithoutDataLoss() throws {
        let input = Data(#"{"schemaVersion":2,"document":{"text":"Generated fixture"}}"#.utf8)
        let untouched = input

        XCTAssertThrowsError(try SnapshotMigrator().migrate(input)) { error in
            XCTAssertEqual(
                error as? SnapshotMigrationError,
                .unsupportedFutureSchema(found: 2, supported: 1)
            )
        }
        XCTAssertEqual(input, untouched)
    }

    func testUnsupportedLegacySchemaDoesNotGuess() {
        for version in [0, -1] {
            let input = Data("{\"schemaVersion\":\(version)}".utf8)

            XCTAssertThrowsError(try SnapshotMigrator().migrate(input)) { error in
                XCTAssertEqual(
                    error as? SnapshotMigrationError,
                    .unsupportedLegacySchema(found: version)
                )
            }
        }
    }

    func testRestoreAlwaysReturnsPaused() {
        let snapshot = makeSnapshot()

        let restored = RestoredState(snapshot: snapshot)

        XCTAssertEqual(restored.overlaySession.visibility, .hidden)
        XCTAssertEqual(restored.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(restored.overlaySession.pixelOffset, 0)
        XCTAssertEqual(restored.overlaySession.readingAnchor, snapshot.readingAnchor)
    }

    func testRestoreRequiresFreshPrivacyAssessmentBeforeShow() {
        let restored = RestoredState(snapshot: makeSnapshot())

        XCTAssertTrue(restored.requiresPrivacyReassessment)
        XCTAssertNil(restored.overlaySession.currentSessionDisplayID)
        XCTAssertEqual(restored.overlaySession.recoveryConfirmationState, .required)
    }

    func testMalformedSnapshotIsReported() throws {
        let valid = try XCTUnwrap(
            JSONSerialization.jsonObject(with: makeSnapshot().canonicalData()) as? [String: Any]
        )
        var invalidUUID = valid
        var invalidUUIDDocument = try XCTUnwrap(invalidUUID["document"] as? [String: Any])
        invalidUUIDDocument["id"] = "not-a-uuid"
        invalidUUID["document"] = invalidUUIDDocument

        var invalidDate = valid
        var invalidDateDocument = try XCTUnwrap(invalidDate["document"] as? [String: Any])
        invalidDateDocument["updatedAt"] = "not-a-date"
        invalidDate["document"] = invalidDateDocument

        var invalidEnum = valid
        var invalidPreferences = try XCTUnwrap(
            invalidEnum["preferences"] as? [String: Any]
        )
        invalidPreferences["fontWeight"] = "unsupported"
        invalidEnum["preferences"] = invalidPreferences

        var missingRequiredField = valid
        missingRequiredField.removeValue(forKey: "revision")

        let inputs = try [
            Data("not-json".utf8),
            Data(#"{"document":{}}"#.utf8),
            Data(#"{"schemaVersion":"one"}"#.utf8),
            JSONSerialization.data(withJSONObject: invalidUUID),
            JSONSerialization.data(withJSONObject: invalidDate),
            JSONSerialization.data(withJSONObject: invalidEnum),
            JSONSerialization.data(withJSONObject: missingRequiredField),
        ]

        for input in inputs {
            XCTAssertThrowsError(try SnapshotMigrator().migrate(input)) { error in
                XCTAssertEqual(error as? SnapshotMigrationError, .malformed)
            }
        }
    }

    func testMigrationErrorsNeverContainScriptContent() throws {
        let privateValues = [
            "GENERATED_SCRIPT_SENTINEL_7C4D",
            "GENERATED_TITLE_SENTINEL_81AF",
            "GENERATED_CONTEXT_SENTINEL_6E29",
        ]
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: makeSnapshot(
                    title: privateValues[1],
                    text: privateValues[0],
                    context: privateValues[2]
                ).canonicalData()
            ) as? [String: Any]
        )
        object["schemaVersion"] = "invalid"
        let malformed = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try SnapshotMigrator().migrate(malformed)) { error in
            let descriptions = [String(describing: error), (error as NSError).localizedDescription]
            for privateValue in privateValues {
                for description in descriptions {
                    XCTAssertFalse(description.contains(privateValue))
                }
            }
        }
    }

    private func makeSnapshot(
        title: String = "Generated fixture",
        text: String = "Generated fixture script",
        context: String = "Generated fixture context"
    ) -> PersistedSnapshot {
        let document = ScriptDocument(
            id: fixedID,
            title: title,
            text: text,
            revision: 13,
            updatedAt: fixedDate
        )
        return PersistedSnapshot(
            revision: 19,
            document: document,
            readingAnchor: ReadingAnchor(
                utf16Offset: 2,
                contextBefore: context,
                contextAfter: context,
                viewportFraction: 0.4,
                document: text
            ),
            preferences: TeleprompterPreferences(),
            panelFrames: [],
            shortcutBindings: []
        )
    }
}
