import AppKit
import CoreGraphics
import TeleprompterCore

struct RuntimeDisplay: Identifiable, Equatable {
    let id: UInt32
    let localizedName: String
    let isBuiltIn: Bool
    let isMain: Bool
    let isOnline: Bool
    let frame: CGRect
    let visibleFrame: CGRect
    let scale: Double
    let persistentUUID: String?
    let mirrorSourceID: UInt32?
    let isInMirrorSet: Bool
    let vendorID: UInt32?
    let modelID: UInt32?
    let serialNumber: UInt32?

    init(
        id: UInt32,
        localizedName: String,
        isBuiltIn: Bool,
        isMain: Bool,
        isOnline: Bool,
        frame: CGRect,
        visibleFrame: CGRect,
        scale: Double,
        persistentUUID: String?,
        mirrorSourceID: UInt32?,
        isInMirrorSet: Bool,
        vendorID: UInt32? = nil,
        modelID: UInt32? = nil,
        serialNumber: UInt32? = nil
    ) {
        self.id = id
        self.localizedName = localizedName
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
        self.isOnline = isOnline
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
        self.persistentUUID = persistentUUID
        self.mirrorSourceID = mirrorSourceID
        self.isInMirrorSet = isInMirrorSet
        self.vendorID = vendorID
        self.modelID = modelID
        self.serialNumber = serialNumber
    }

    var isMirrored: Bool { isInMirrorSet || mirrorSourceID != nil }
}

struct RuntimeDisplayInventory: Equatable {
    let displays: [RuntimeDisplay]
    let topology: DisplayTopologySnapshot

    init(displays: [RuntimeDisplay]) {
        self.displays = displays
        let descriptors = displays.map { display in
            let mirroredIDs = Set(
                displays.lazy
                    .filter { $0.mirrorSourceID == display.id }
                    .map(\.id)
            )
            let confidence: DisplayFingerprint.Confidence
            if display.persistentUUID != nil,
               display.vendorID != nil,
               display.modelID != nil,
               display.serialNumber != nil {
                confidence = .strong
            } else if display.persistentUUID != nil,
                      display.vendorID != nil,
                      display.modelID != nil {
                confidence = .medium
            } else {
                confidence = .weak
            }
            return DisplayDescriptor(
                sessionID: display.id,
                fingerprint: DisplayFingerprint(
                    uuid: display.persistentUUID,
                    vendorID: display.vendorID,
                    modelID: display.modelID,
                    serialNumber: display.serialNumber,
                    isBuiltIn: display.isBuiltIn,
                    lastLocalizedName: display.localizedName,
                    confidence: confidence
                ),
                localizedName: display.localizedName,
                isBuiltIn: display.isBuiltIn,
                isMain: display.isMain,
                isOnline: display.isOnline,
                bounds: DisplayRect(display.frame),
                visibleFrame: DisplayRect(display.visibleFrame),
                scale: display.scale,
                mirrorSourceSessionID: display.mirrorSourceID,
                mirroredSessionIDs: mirroredIDs
            )
        }
        topology = DisplayTopologySnapshot(displays: descriptors, querySucceeded: true)
    }
}

enum DisplayQueryError: Error {
    case missingScreenNumber(String)
}

enum DisplayObservationError: Error {
    case registrationFailed(CGError)
}

@MainActor
final class SystemDisplayService {
    var onReconfigurationBegan: (() -> Void)?
    var onScreensChanged: ((Result<RuntimeDisplayInventory, Error>) -> Void)?
    private var isObserving = false

    func currentDisplays() throws -> [RuntimeDisplay] {
        try NSScreen.screens.map { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? NSNumber else {
                throw DisplayQueryError.missingScreenNumber(screen.localizedName)
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let mirrorSource = CGDisplayMirrorsDisplay(displayID)
            return RuntimeDisplay(
                id: UInt32(displayID),
                localizedName: screen.localizedName,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                isMain: screen == NSScreen.main,
                isOnline: CGDisplayIsOnline(displayID) != 0,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                scale: Double(screen.backingScaleFactor),
                persistentUUID: Self.uuidString(for: displayID),
                mirrorSourceID: mirrorSource == kCGNullDirectDisplay ? nil : UInt32(mirrorSource),
                isInMirrorSet: CGDisplayIsInMirrorSet(displayID) != 0,
                vendorID: Self.meaningful(CGDisplayVendorNumber(displayID)),
                modelID: Self.meaningful(CGDisplayModelNumber(displayID)),
                serialNumber: Self.meaningful(CGDisplaySerialNumber(displayID))
            )
        }
    }

    func currentInventory() throws -> RuntimeDisplayInventory {
        RuntimeDisplayInventory(displays: try currentDisplays())
    }

    func startObserving() throws {
        guard !isObserving else { return }
        let status = CGDisplayRegisterReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard status == .success else {
            throw DisplayObservationError.registrationFailed(status)
        }
        isObserving = true
    }

    func stopObserving() {
        guard isObserving else { return }
        CGDisplayRemoveReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        isObserving = false
    }

    fileprivate func receiveReconfiguration(flags: CGDisplayChangeSummaryFlags) {
        if flags.contains(.beginConfigurationFlag) {
            onReconfigurationBegan?()
            return
        }
        do {
            onScreensChanged?(.success(try currentInventory()))
        } catch {
            onScreensChanged?(.failure(error))
        }
    }

    private static func meaningful(_ value: UInt32) -> UInt32? {
        value == 0 ? nil : value
    }

    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let unmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) else { return nil }
        let uuid = unmanaged.takeRetainedValue()
        guard let value = CFUUIDCreateString(nil, uuid) else { return nil }
        return value as String
    }
}

private func displayReconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let service = Unmanaged<SystemDisplayService>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        service.receiveReconfiguration(flags: flags)
    }
}
