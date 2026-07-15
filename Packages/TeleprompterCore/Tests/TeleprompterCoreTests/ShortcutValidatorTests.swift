import Foundation
import XCTest

@testable import TeleprompterCore

final class ShortcutValidatorTests: XCTestCase {
    func testDefaultsMatchPRD() throws {
        let bindings = try ShortcutValidator.validate(ShortcutValidator.defaultBindings)

        XCTAssertEqual(bindings.map(\.action), ShortcutAction.stableOrder)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: bindings.map { ($0.action, $0.shortcut) }),
            KeyboardShortcut.defaultMap
        )
    }

    func testBareSpaceAndArrowsAreRejected() {
        let reserved: [(ShortcutAction, UInt16)] = [
            (.togglePlayback, 49),
            (.increaseSpeed, 126),
            (.decreaseSpeed, 125),
            (.moveBackward, 123),
            (.moveForward, 124),
        ]

        for (action, keyCode) in reserved {
            var bindings = ShortcutValidator.defaultBindings
            replace(action, in: &bindings, withKeyCode: keyCode, modifiers: [])
            XCTAssertTrue(
                violations(from: bindings).contains(.bareReservedKey(action: action, keyCode: keyCode))
            )
        }
    }

    func testDuplicateChordIsRejected() {
        var bindings = ShortcutValidator.defaultBindings
        let duplicate = KeyboardShortcut.defaultMap[.togglePlayback]!
        replace(
            .increaseSpeed,
            in: &bindings,
            withKeyCode: duplicate.virtualKeyCode,
            modifiers: duplicate.modifiers
        )

        XCTAssertTrue(
            violations(from: bindings).contains(
                .duplicateChord(
                    actions: [.togglePlayback, .increaseSpeed],
                    shortcut: duplicate
                )
            )
        )
    }

    func testCustomChordRoundTrips() throws {
        var custom = ShortcutValidator.defaultBindings
        replace(.toggleVisibility, in: &custom, withKeyCode: 5, modifiers: [.command, .shift])
        let snapshot = makeSnapshot(shortcutBindings: custom)

        let decoded = try PersistedSnapshot.canonicalDecoder().decode(
            PersistedSnapshot.self,
            from: snapshot.canonicalData()
        )

        XCTAssertEqual(try ShortcutValidator.validate(decoded.shortcutBindings), custom)
    }

    func testEveryProductShortcutRequiresModifier() {
        var bindings = ShortcutValidator.defaultBindings
        replace(.toggleVisibility, in: &bindings, withKeyCode: 4, modifiers: [])

        XCTAssertTrue(
            violations(from: bindings).contains(.modifierRequired(action: .toggleVisibility))
        )
    }

    func testMissingAndDuplicateActionsAreRejected() {
        var missing = ShortcutValidator.defaultBindings
        missing.removeAll { $0.action == .toggleLock }
        XCTAssertTrue(violations(from: missing).contains(.missingAction(action: .toggleLock)))

        var duplicate = ShortcutValidator.defaultBindings
        duplicate.append(duplicate.first!)
        XCTAssertTrue(
            violations(from: duplicate).contains(.duplicateAction(action: .togglePlayback))
        )
    }

    func testCanonicalBindingsUseStableActionOrder() throws {
        let reversed = Array(ShortcutValidator.defaultBindings.reversed())

        XCTAssertEqual(
            try ShortcutValidator.validate(reversed).map(\.action),
            ShortcutAction.stableOrder
        )
    }

    func testInvalidRestoredBindingsUseDefaultsWithoutDiscardingDocument() {
        var invalid = ShortcutValidator.defaultBindings
        invalid.removeAll { $0.action == .toggleLock }
        let original = makeSnapshot(text: "Synthetic restore fixture", shortcutBindings: invalid)

        let resolution = ShortcutRestorePolicy.resolve(original)

        XCTAssertTrue(resolution.usedDefaultBindings)
        XCTAssertEqual(resolution.snapshot.document, original.document)
        XCTAssertEqual(resolution.snapshot.preferences, original.preferences)
        XCTAssertEqual(resolution.snapshot.readingAnchor, original.readingAnchor)
        XCTAssertEqual(resolution.snapshot.shortcutBindings, ShortcutValidator.defaultBindings)
    }

    func testShortcutRoundTripKeepsPersistedSnapshotSchemaOne() throws {
        let data = try makeSnapshot(shortcutBindings: ShortcutValidator.defaultBindings).canonicalData()
        let decoded = try PersistedSnapshot.canonicalDecoder().decode(
            PersistedSnapshot.self,
            from: data
        )

        XCTAssertEqual(PersistedSnapshot.currentSchemaVersion, 1)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.shortcutBindings, ShortcutValidator.defaultBindings)
    }

    func testCustomizationIsDisabledByDefaultUntilPhysicalProof() {
        XCTAssertFalse(ShortcutCustomizationAvailability.isEnabledByDefault)
    }

    private func violations(from bindings: [ShortcutBinding]) -> [ShortcutViolation] {
        do {
            _ = try ShortcutValidator.validate(bindings)
            XCTFail("Expected shortcut validation to fail")
            return []
        } catch let error as ShortcutValidationError {
            return error.violations
        } catch {
            XCTFail("Unexpected error: \(error)")
            return []
        }
    }

    private func replace(
        _ action: ShortcutAction,
        in bindings: inout [ShortcutBinding],
        withKeyCode keyCode: UInt16,
        modifiers: Set<ShortcutModifier>
    ) {
        let replacement = ShortcutBinding(
            action: action,
            shortcut: KeyboardShortcut(virtualKeyCode: keyCode, modifiers: modifiers)
        )
        bindings[bindings.firstIndex { $0.action == action }!] = replacement
    }

    private func makeSnapshot(
        text: String = "Synthetic shortcut fixture",
        shortcutBindings: [ShortcutBinding]
    ) -> PersistedSnapshot {
        PersistedSnapshot(
            revision: 9,
            document: ScriptDocument(
                title: "Synthetic document",
                text: text,
                revision: 3,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            readingAnchor: ReadingAnchor(utf16Offset: 2, document: text),
            preferences: TeleprompterPreferences(isLocked: true),
            shortcutBindings: shortcutBindings
        )
    }
}
