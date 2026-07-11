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
}
