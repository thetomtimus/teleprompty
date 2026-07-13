import Foundation

public enum SnapshotMigrationError: Error, Equatable, Sendable {
    case unsupportedFutureSchema(found: Int, supported: Int)
    case unsupportedLegacySchema(found: Int)
    case malformed
}

extension SnapshotMigrationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupportedFutureSchema(let found, let supported):
            return "Snapshot schema \(found) exceeds supported schema \(supported)."
        case .unsupportedLegacySchema(let found):
            return "Snapshot schema \(found) is unsupported."
        case .malformed:
            return "Snapshot data is malformed."
        }
    }
}

extension SnapshotMigrationError: LocalizedError {
    public var errorDescription: String? { description }
}

public struct SnapshotMigrator: Sendable {
    public init() {}

    public func migrate(_ data: Data) throws -> PersistedSnapshot {
        let schemaVersion: Int
        do {
            schemaVersion = try JSONDecoder().decode(SchemaEnvelope.self, from: data).schemaVersion
        } catch {
            throw SnapshotMigrationError.malformed
        }

        switch schemaVersion {
        case PersistedSnapshot.currentSchemaVersion:
            return try migrateV1(data)
        case let version where version > PersistedSnapshot.currentSchemaVersion:
            throw SnapshotMigrationError.unsupportedFutureSchema(
                found: version,
                supported: PersistedSnapshot.currentSchemaVersion
            )
        default:
            throw SnapshotMigrationError.unsupportedLegacySchema(found: schemaVersion)
        }
    }

    private func migrateV1(_ data: Data) throws -> PersistedSnapshot {
        do {
            let wireSnapshot = try PersistedSnapshot.canonicalDecoder().decode(
                V1Snapshot.self,
                from: data
            )
            let snapshot = try wireSnapshot.domainSnapshot()

            // Decode the canonical representation once so callers always receive
            // normalized collection ordering as well as a validated v1 snapshot.
            return try PersistedSnapshot.canonicalDecoder().decode(
                PersistedSnapshot.self,
                from: snapshot.canonicalData()
            )
        } catch {
            throw SnapshotMigrationError.malformed
        }
    }
}

public struct RestoredState: Equatable, Sendable {
    public let snapshot: PersistedSnapshot
    public let overlaySession: OverlaySession
    public let requiresPrivacyReassessment: Bool

    public init(snapshot: PersistedSnapshot) {
        self.snapshot = snapshot
        overlaySession = OverlaySession(
            visibility: .hidden,
            playbackPhase: .paused,
            readingAnchor: snapshot.readingAnchor,
            pixelOffset: 0,
            currentSessionDisplayID: nil,
            chromeState: .shown,
            recoveryConfirmationState: .required
        )
        requiresPrivacyReassessment = true
    }
}

private struct SchemaEnvelope: Decodable {
    let schemaVersion: Int
}

private struct V1Snapshot: Decodable {
    let schemaVersion: Int
    let revision: UInt64
    let document: ScriptDocument
    let readingAnchor: ReadingAnchor
    let preferences: TeleprompterPreferences
    let panelFrames: [PersistedPanelFrame]
    let shortcutBindings: [V1ShortcutBinding]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case document
        case readingAnchor
        case preferences
        case panelFrames
        case shortcutBindings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        revision = try container.decode(UInt64.self, forKey: .revision)
        document = try container.decode(ScriptDocument.self, forKey: .document)
        readingAnchor = try container.decode(ReadingAnchor.self, forKey: .readingAnchor)
        preferences = try container.decode(TeleprompterPreferences.self, forKey: .preferences)
        panelFrames =
            try container.decodeIfPresent(
                [PersistedPanelFrame].self,
                forKey: .panelFrames
            ) ?? []
        shortcutBindings =
            try container.decodeIfPresent(
                [V1ShortcutBinding].self,
                forKey: .shortcutBindings
            ) ?? []
    }

    func domainSnapshot() throws -> PersistedSnapshot {
        PersistedSnapshot(
            schemaVersion: schemaVersion,
            revision: revision,
            document: document,
            readingAnchor: readingAnchor,
            preferences: preferences,
            panelFrames: panelFrames,
            shortcutBindings: try shortcutBindings.map { try $0.domainBinding() }
        )
    }
}

private struct V1ShortcutBinding: Decodable {
    let action: ShortcutAction
    let shortcut: V1KeyboardShortcut

    func domainBinding() throws -> ShortcutBinding {
        ShortcutBinding(action: action, shortcut: try shortcut.domainShortcut())
    }
}

private struct V1KeyboardShortcut: Decodable {
    let virtualKeyCode: UInt16
    let modifiers: [ShortcutModifier]

    func domainShortcut() throws -> KeyboardShortcut {
        let modifierSet = Set(modifiers)
        guard modifierSet.count == modifiers.count else {
            throw V1MigrationValidationError.duplicateShortcutModifier
        }
        return KeyboardShortcut(virtualKeyCode: virtualKeyCode, modifiers: modifierSet)
    }
}

private enum V1MigrationValidationError: Error {
    case duplicateShortcutModifier
}
