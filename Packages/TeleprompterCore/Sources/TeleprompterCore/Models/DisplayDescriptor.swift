import Foundation

/// A current-session display description. It is intentionally not `Codable`: the
/// session ID must never be persisted as display identity.
public struct DisplayDescriptor: Equatable, Sendable {
    public var sessionID: UInt32
    public var fingerprint: DisplayFingerprint
    public var localizedName: String
    public var isBuiltIn: Bool
    public var isMain: Bool
    public var isOnline: Bool
    /// Geometry exists only when AppKit exposes this online display as an
    /// `NSScreen`. CoreGraphics-only topology members remain safety inputs but
    /// can never be selected as overlay destinations.
    public var bounds: DisplayRect?
    public var visibleFrame: DisplayRect?
    public var scale: Double?
    public var mirrorSourceSessionID: UInt32?
    public var mirroredSessionIDs: Set<UInt32>
    public var isInHardwareMirrorSet: Bool

    public init(
        sessionID: UInt32,
        fingerprint: DisplayFingerprint,
        localizedName: String,
        isBuiltIn: Bool,
        isMain: Bool,
        isOnline: Bool,
        bounds: DisplayRect? = nil,
        visibleFrame: DisplayRect? = nil,
        scale: Double? = nil,
        mirrorSourceSessionID: UInt32? = nil,
        mirroredSessionIDs: Set<UInt32> = [],
        isInHardwareMirrorSet: Bool = false
    ) {
        self.sessionID = sessionID
        self.fingerprint = fingerprint
        self.localizedName = localizedName
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
        self.isOnline = isOnline
        self.bounds = bounds
        self.visibleFrame = visibleFrame
        self.scale = scale
        self.mirrorSourceSessionID = mirrorSourceSessionID
        self.mirroredSessionIDs = mirroredSessionIDs
        self.isInHardwareMirrorSet = isInHardwareMirrorSet
    }

    public var isParticipatingInMirroring: Bool {
        isInHardwareMirrorSet || mirrorSourceSessionID != nil || !mirroredSessionIDs.isEmpty
    }

    public var isDrawableDestination: Bool {
        bounds != nil && visibleFrame != nil && scale != nil
    }
}

public struct DisplayTopologySnapshot: Equatable, Sendable {
    public var displays: [DisplayDescriptor]
    public var querySucceeded: Bool

    public init(displays: [DisplayDescriptor], querySucceeded: Bool) {
        self.displays = displays
        self.querySucceeded = querySucceeded
    }

    public var verifiedMirroring: Bool {
        querySucceeded
            && displays.lazy
                .filter(\.isOnline)
                .contains(where: \.isParticipatingInMirroring)
    }
}

public struct DisplaySelection: Equatable, Sendable {
    public var fingerprint: DisplayFingerprint
    public var isConfirmed: Bool
    /// True only after an explicit confirmation in the current topology session.
    /// This transient value must not be restored from persisted preferences.
    public var isConfirmedInCurrentSession: Bool
    /// A transient runtime ID used only to resolve an explicitly selected display
    /// when multiple current displays have indistinguishable fingerprints.
    public var currentSessionID: UInt32?

    public init(
        fingerprint: DisplayFingerprint,
        isConfirmed: Bool,
        isConfirmedInCurrentSession: Bool = false,
        currentSessionID: UInt32? = nil
    ) {
        self.fingerprint = fingerprint
        self.isConfirmed = isConfirmed
        self.isConfirmedInCurrentSession = isConfirmedInCurrentSession
        self.currentSessionID = currentSessionID
    }
}
