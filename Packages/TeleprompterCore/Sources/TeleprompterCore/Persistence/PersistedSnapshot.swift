import Foundation

public struct PersistedPanelFrame: Codable, Equatable, Sendable {
    public var displayFingerprint: DisplayFingerprint
    public var frame: NormalizedPanelFrame

    public init(displayFingerprint: DisplayFingerprint, frame: NormalizedPanelFrame) {
        self.displayFingerprint = displayFingerprint
        self.frame = frame
    }
}

public struct ShortcutBinding: Codable, Equatable, Sendable {
    public var action: ShortcutAction
    public var shortcut: KeyboardShortcut

    public init(action: ShortcutAction, shortcut: KeyboardShortcut) {
        self.action = action
        self.shortcut = shortcut
    }
}

public enum PersistedSnapshotValidationError: Error, Equatable, Sendable {
    case duplicateShortcutAction
    case duplicateDisplayFingerprint
    case schemaVersionMismatch
}

public struct PersistedSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var revision: UInt64
    public var document: ScriptDocument
    public var readingAnchor: ReadingAnchor
    public var preferences: TeleprompterPreferences
    public var panelFrames: [PersistedPanelFrame]
    public var shortcutBindings: [ShortcutBinding]

    public init(
        schemaVersion: Int = PersistedSnapshot.currentSchemaVersion,
        revision: UInt64,
        document: ScriptDocument,
        readingAnchor: ReadingAnchor,
        preferences: TeleprompterPreferences,
        panelFrames: [PersistedPanelFrame] = [],
        shortcutBindings: [ShortcutBinding] = []
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.document = document
        self.readingAnchor = readingAnchor.clamped(to: document.text)
        self.preferences = preferences
        self.panelFrames = Self.sortedFrames(panelFrames)
        self.shortcutBindings = Self.sortedBindings(shortcutBindings)
    }

    public static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    public static func canonicalDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    public func canonicalData() throws -> Data {
        try Self.canonicalEncoder().encode(self)
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        try V1Snapshot(self).encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let wireSnapshot = try V1Snapshot(from: decoder)
        self.init(
            schemaVersion: wireSnapshot.schemaVersion,
            revision: wireSnapshot.revision,
            document: wireSnapshot.document,
            readingAnchor: wireSnapshot.readingAnchor,
            preferences: wireSnapshot.preferences,
            panelFrames: wireSnapshot.panelFrames,
            shortcutBindings: try wireSnapshot.shortcutBindings.map { try $0.domainBinding() }
        )
        try validate()
    }

    private func validate() throws {
        guard
            schemaVersion == Self.currentSchemaVersion,
            document.schemaVersion == ScriptDocument.currentSchemaVersion
        else {
            throw PersistedSnapshotValidationError.schemaVersionMismatch
        }

        let actions = shortcutBindings.map(\.action)
        guard Set(actions).count == actions.count else {
            throw PersistedSnapshotValidationError.duplicateShortcutAction
        }

        let identities = panelFrames.map { CanonicalFingerprintIdentity($0.displayFingerprint) }
        guard Set(identities).count == identities.count else {
            throw PersistedSnapshotValidationError.duplicateDisplayFingerprint
        }
    }

    private static func sortedFrames(_ frames: [PersistedPanelFrame]) -> [PersistedPanelFrame] {
        frames.sorted {
            CanonicalFingerprintIdentity($0.displayFingerprint)
                .precedes(CanonicalFingerprintIdentity($1.displayFingerprint))
        }
    }

    private static func sortedBindings(_ bindings: [ShortcutBinding]) -> [ShortcutBinding] {
        bindings.sorted { $0.action.stableIndex < $1.action.stableIndex }
    }
}

private struct V1Snapshot: Codable {
    let schemaVersion: Int
    let revision: UInt64
    let document: ScriptDocument
    let readingAnchor: ReadingAnchor
    let preferences: TeleprompterPreferences
    let panelFrames: [PersistedPanelFrame]
    let shortcutBindings: [V1ShortcutBinding]

    init(_ snapshot: PersistedSnapshot) {
        schemaVersion = snapshot.schemaVersion
        revision = snapshot.revision
        document = snapshot.document
        readingAnchor = snapshot.readingAnchor.clamped(to: snapshot.document.text)
        preferences = snapshot.preferences
        panelFrames = snapshot.panelFrames
        shortcutBindings = snapshot.shortcutBindings.map(V1ShortcutBinding.init)
    }
}

private struct V1ShortcutBinding: Codable {
    let action: ShortcutAction
    let shortcut: V1KeyboardShortcut

    init(_ binding: ShortcutBinding) {
        action = binding.action
        shortcut = V1KeyboardShortcut(binding.shortcut)
    }

    func domainBinding() throws -> ShortcutBinding {
        ShortcutBinding(action: action, shortcut: try shortcut.domainShortcut())
    }
}

private struct V1KeyboardShortcut: Codable {
    let virtualKeyCode: UInt16
    let modifiers: [ShortcutModifier]

    init(_ shortcut: KeyboardShortcut) {
        virtualKeyCode = shortcut.virtualKeyCode
        modifiers = shortcut.modifiers.sorted { $0.rawValue < $1.rawValue }
    }

    func domainShortcut() throws -> KeyboardShortcut {
        let modifierSet = Set(modifiers)
        guard modifierSet.count == modifiers.count else {
            throw KeyboardShortcutCodingError.duplicateModifier
        }
        return KeyboardShortcut(virtualKeyCode: virtualKeyCode, modifiers: modifierSet)
    }
}

private struct CanonicalFingerprintIdentity: Equatable, Hashable {
    let persistentKey: DisplayFingerprint.PersistentIdentityKey?
    let uuid: String?
    let vendorID: UInt32?
    let modelID: UInt32?
    let serialNumber: UInt32?
    let isBuiltIn: Bool
    let lastLocalizedName: String
    let confidence: String

    init(_ fingerprint: DisplayFingerprint) {
        let normalized = fingerprint.normalized
        persistentKey = normalized.persistentIdentityKey
        uuid = normalized.uuid
        vendorID = normalized.vendorID
        modelID = normalized.modelID
        serialNumber = normalized.serialNumber
        isBuiltIn = normalized.isBuiltIn
        lastLocalizedName = fingerprint.lastLocalizedName
        confidence = fingerprint.confidence.rawValue
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        if let lhsKey = lhs.persistentKey, let rhsKey = rhs.persistentKey {
            return lhsKey == rhsKey
        }
        return lhs.uuid == rhs.uuid
            && lhs.vendorID == rhs.vendorID
            && lhs.modelID == rhs.modelID
            && lhs.serialNumber == rhs.serialNumber
            && lhs.isBuiltIn == rhs.isBuiltIn
            && lhs.lastLocalizedName == rhs.lastLocalizedName
            && lhs.confidence == rhs.confidence
    }

    func hash(into hasher: inout Hasher) {
        if let persistentKey {
            hasher.combine(0)
            hasher.combine(persistentKey)
        } else {
            hasher.combine(1)
            hasher.combine(uuid)
            hasher.combine(vendorID)
            hasher.combine(modelID)
            hasher.combine(serialNumber)
            hasher.combine(isBuiltIn)
            hasher.combine(lastLocalizedName)
            hasher.combine(confidence)
        }
    }

    func precedes(_ other: CanonicalFingerprintIdentity) -> Bool {
        if let result = compareOptional(uuid, other.uuid) { return result }
        if let result = compareOptional(vendorID, other.vendorID) { return result }
        if let result = compareOptional(modelID, other.modelID) { return result }
        if let result = compareOptional(serialNumber, other.serialNumber) { return result }
        if isBuiltIn != other.isBuiltIn { return !isBuiltIn && other.isBuiltIn }
        if lastLocalizedName != other.lastLocalizedName {
            return lastLocalizedName < other.lastLocalizedName
        }
        return confidence < other.confidence
    }

    private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case (nil, nil):
            return nil
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        case (.some(let lhs), .some(let rhs)) where lhs != rhs:
            return lhs < rhs
        default:
            return nil
        }
    }
}
