import Foundation

public struct DisplayFingerprint: Codable, Equatable, Hashable, Sendable {
    public enum Confidence: String, Codable, CaseIterable, Hashable, Sendable {
        case strong
        case medium
        case weak
    }

    public var uuid: String?
    public var vendorID: UInt32?
    public var modelID: UInt32?
    public var serialNumber: UInt32?
    public var isBuiltIn: Bool
    public var lastLocalizedName: String
    public var confidence: Confidence

    public init(
        uuid: String?,
        vendorID: UInt32?,
        modelID: UInt32?,
        serialNumber: UInt32?,
        isBuiltIn: Bool,
        lastLocalizedName: String,
        confidence: Confidence
    ) {
        self.uuid = uuid
        self.vendorID = vendorID
        self.modelID = modelID
        self.serialNumber = serialNumber
        self.isBuiltIn = isBuiltIn
        self.lastLocalizedName = lastLocalizedName
        self.confidence = confidence
    }

    /// A runtime-independent identity suitable for selection and frame keys.
    /// Localized names and confidence are deliberately excluded.
    public enum PersistentIdentityKey: Equatable, Hashable, Sendable {
        case uuid(String)
        case hardware(isBuiltIn: Bool, vendorID: UInt32, modelID: UInt32, serialNumber: UInt32)
    }

    public enum Relationship: Equatable, Sendable {
        case noMatch
        case match
        case conflict
        case ambiguous
    }

    public var normalized: DisplayFingerprint {
        DisplayFingerprint(
            uuid: Self.normalizedUUID(uuid),
            vendorID: Self.meaningful(vendorID),
            modelID: Self.meaningful(modelID),
            serialNumber: Self.meaningful(serialNumber),
            isBuiltIn: isBuiltIn,
            lastLocalizedName: lastLocalizedName,
            confidence: confidence
        )
    }

    public var persistentIdentityKey: PersistentIdentityKey? {
        let value = normalized
        if let uuid = value.uuid {
            return .uuid(uuid)
        }
        guard
            let vendorID = value.vendorID,
            let modelID = value.modelID,
            let serialNumber = value.serialNumber
        else { return nil }
        return .hardware(
            isBuiltIn: value.isBuiltIn,
            vendorID: vendorID,
            modelID: modelID,
            serialNumber: serialNumber
        )
    }

    public func relationship(to other: DisplayFingerprint) -> Relationship {
        let lhs = normalized
        let rhs = other.normalized

        if let lhsUUID = lhs.uuid, let rhsUUID = rhs.uuid {
            guard lhsUUID == rhsUUID else { return .noMatch }
            return lhs.hasConflict(with: rhs) ? .conflict : .match
        }

        if lhs.isBuiltIn != rhs.isBuiltIn, lhs.hasSharedIdentityFact(with: rhs) {
            return .conflict
        }

        if let lhsKey = lhs.completeHardwareKey,
            let rhsKey = rhs.completeHardwareKey
        {
            return lhsKey == rhsKey ? .match : .noMatch
        }

        return .ambiguous
    }

    private var completeHardwareKey: PersistentIdentityKey? {
        guard let vendorID,
            let modelID,
            let serialNumber
        else { return nil }
        return .hardware(
            isBuiltIn: isBuiltIn,
            vendorID: vendorID,
            modelID: modelID,
            serialNumber: serialNumber
        )
    }

    private func hasConflict(with other: DisplayFingerprint) -> Bool {
        isBuiltIn != other.isBuiltIn
            || Self.conflicts(vendorID, other.vendorID)
            || Self.conflicts(modelID, other.modelID)
            || Self.conflicts(serialNumber, other.serialNumber)
    }

    private func hasSharedIdentityFact(with other: DisplayFingerprint) -> Bool {
        Self.matches(vendorID, other.vendorID)
            || Self.matches(modelID, other.modelID)
            || Self.matches(serialNumber, other.serialNumber)
    }

    private static func normalizedUUID(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func meaningful(_ value: UInt32?) -> UInt32? {
        guard let value, value != 0 else { return nil }
        return value
    }

    private static func conflicts<T: Equatable>(_ lhs: T?, _ rhs: T?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs != rhs
    }

    private static func matches<T: Equatable>(_ lhs: T?, _ rhs: T?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs == rhs
    }
}
