import AppKit
import CoreGraphics
import TeleprompterCore

/// An `NSScreen`-backed destination. Every instance is drawable and may be
/// selected after the privacy model confirms its matching topology descriptor.
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

struct DisplayHardwareFacts: Equatable {
    let isBuiltIn: Bool
    let mirrorSourceID: UInt32?
    let isInMirrorSet: Bool
    let persistentUUID: String?
    let vendorID: UInt32?
    let modelID: UInt32?
    let serialNumber: UInt32?
}

struct RuntimeDisplayInventory: Equatable {
    /// Drawable destinations only. Safety evaluation uses `topology`, which may
    /// contain additional CoreGraphics-only online displays.
    let displays: [RuntimeDisplay]
    let topology: DisplayTopologySnapshot

    init(displays: [RuntimeDisplay]) {
        self.displays = displays
        let ids = displays.map(\.id)
        guard !ids.contains(0), Set(ids).count == ids.count else {
            topology = DisplayTopologySnapshot(displays: [], querySucceeded: false)
            return
        }
        var factsByID: [UInt32: DisplayHardwareFacts] = [:]
        for display in displays {
            factsByID[display.id] = DisplayHardwareFacts(
                isBuiltIn: display.isBuiltIn,
                mirrorSourceID: display.mirrorSourceID,
                isInMirrorSet: display.isInMirrorSet,
                persistentUUID: display.persistentUUID,
                vendorID: display.vendorID,
                modelID: display.modelID,
                serialNumber: display.serialNumber
            )
        }
        topology = Self.topology(displays: displays, factsByID: factsByID, onlineIDs: ids)
    }

    init(
        validating displays: [RuntimeDisplay],
        topology: DisplayTopologySnapshot
    ) throws {
        guard topology.querySucceeded else { throw DisplayQueryError.onlineDisplayQueryFailed }
        let topologyIDs = Set(topology.displays.filter(\.isOnline).map(\.sessionID))
        let drawableIDs = Set(displays.map(\.id))
        guard drawableIDs.isSubset(of: topologyIDs) else {
            throw DisplayQueryError.missingCandidateDrawableMapping
        }
        for display in displays {
            guard
                let descriptor = topology.displays.first(where: { $0.sessionID == display.id }),
                descriptor.isDrawableDestination
            else { throw DisplayQueryError.missingCandidateDrawableMapping }
        }
        self.displays = displays
        self.topology = topology
    }

    static func topology(
        displays: [RuntimeDisplay],
        factsByID: [UInt32: DisplayHardwareFacts],
        onlineIDs: [UInt32]
    ) -> DisplayTopologySnapshot {
        let drawableByID = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0) })
        let descriptors = onlineIDs.compactMap { id -> DisplayDescriptor? in
            guard let facts = factsByID[id] else { return nil }
            let drawable = drawableByID[id]
            let mirroredIDs = Set(
                onlineIDs.filter { factsByID[$0]?.mirrorSourceID == id }
            )
            let name = drawable?.localizedName ?? "Online Display \(id)"
            return DisplayDescriptor(
                sessionID: id,
                fingerprint: SystemDisplayService.fingerprint(
                    localizedName: name,
                    facts: facts
                ),
                localizedName: name,
                isBuiltIn: facts.isBuiltIn,
                isMain: drawable?.isMain ?? false,
                isOnline: drawable?.isOnline ?? true,
                bounds: drawable.map { DisplayRect($0.frame) },
                visibleFrame: drawable.map { DisplayRect($0.visibleFrame) },
                scale: drawable?.scale,
                mirrorSourceSessionID: facts.mirrorSourceID,
                mirroredSessionIDs: mirroredIDs,
                isInHardwareMirrorSet: facts.isInMirrorSet
            )
        }
        return DisplayTopologySnapshot(displays: descriptors, querySucceeded: true)
    }

    fileprivate static func confidence(
        for facts: DisplayHardwareFacts
    ) -> DisplayFingerprint.Confidence {
        let uuid = facts.persistentUUID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUUID = !(uuid?.isEmpty ?? true)
        let hasVendor = facts.vendorID.map { $0 != 0 } ?? false
        let hasModel = facts.modelID.map { $0 != 0 } ?? false
        let hasSerial = facts.serialNumber.map { $0 != 0 } ?? false
        if hasUUID, hasVendor, hasModel, hasSerial
        {
            return .strong
        }
        if hasUUID, hasVendor, hasModel {
            return .medium
        }
        return .weak
    }
}

enum DisplayQueryError: Error, Equatable {
    case missingScreenNumber
    case invalidScreenNumber
    case duplicateDrawableSessionID(UInt32)
    case onlineDisplayQueryFailed
    case onlineDisplayCountRace(expected: UInt32, actual: UInt32)
    case missingHardwareFacts(UInt32)
    case missingCandidateDrawableMapping
}

enum DisplayObservationError: Error {
    case registrationFailed(CGError)
    case priorRemovalFailed
}

@MainActor
struct DisplayObservationSeams {
    typealias Callback = @MainActor (CGDisplayChangeSummaryFlags) -> Void

    let install: (@escaping Callback) throws -> Void
    let remove: () -> Void
}

private final class DisplayReconfigurationCallbackContext: @unchecked Sendable {
    let lifetimeRawValue: UInt64
    private weak var service: SystemDisplayService?
    private let lock = NSLock()
    private var registrationPointer: UnsafeMutableRawPointer?
    private var pendingDeliveries = 0
    private var removalSucceeded = false
    private var registrationRetainReleased = false

    @MainActor
    init(service: SystemDisplayService, generation: RuntimeDisplayGeneration) {
        let lifetimeRawValue = generation.rawValue
        self.lifetimeRawValue = lifetimeRawValue
        self.service = service
    }

    func enqueue(_ rawFlags: UInt32) {
        beginDelivery()
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated {
                service?.receiveReconfiguration(
                    flags: CGDisplayChangeSummaryFlags(rawValue: rawFlags),
                    observationGeneration: RuntimeDisplayGeneration(
                        rawValue: lifetimeRawValue
                    )
                )
            }
            finishDelivery()
        }
    }

    func bindRegistrationPointer(_ pointer: UnsafeMutableRawPointer) {
        lock.lock()
        precondition(registrationPointer == nil)
        registrationPointer = pointer
        lock.unlock()
    }

    func registrationFailed() {
        releaseRegistrationRetainIfReady(force: true)
    }

    func registrationRemovalSucceeded() {
        lock.lock()
        removalSucceeded = true
        lock.unlock()
        releaseRegistrationRetainIfReady(force: false)
    }

    func registrationRemovalFailed() {
        // CoreGraphics may still call the registered pointer. Intentionally keep
        // the passRetained ownership forever rather than risk a use-after-free.
    }

    private func beginDelivery() {
        lock.lock()
        pendingDeliveries += 1
        lock.unlock()
    }

    private func finishDelivery() {
        lock.lock()
        precondition(pendingDeliveries > 0)
        pendingDeliveries -= 1
        lock.unlock()
        releaseRegistrationRetainIfReady(force: false)
    }

    private func releaseRegistrationRetainIfReady(force: Bool) {
        lock.lock()
        guard
            !registrationRetainReleased,
            let pointer = registrationPointer,
            force || (removalSucceeded && pendingDeliveries == 0)
        else {
            lock.unlock()
            return
        }
        registrationRetainReleased = true
        registrationPointer = nil
        lock.unlock()
        Unmanaged<DisplayReconfigurationCallbackContext>.fromOpaque(pointer).release()
    }
}

@MainActor
final class SystemDisplayService {
    typealias DrawableDisplayQuery = @MainActor () throws -> [RuntimeDisplay]
    typealias OnlineDisplayQuery = @MainActor () throws -> [UInt32]
    typealias HardwareFactsQuery = @MainActor (UInt32) throws -> DisplayHardwareFacts

    var onReconfigurationBegan:
        ((RuntimeDisplayGeneration) -> RuntimeDisplayGeneration?)?
    var onScreensChanged:
        ((RuntimeDisplayGeneration, RuntimeDisplayGeneration,
          Result<RuntimeDisplayInventory, Error>) -> Void)?
    private var isObserving = false
    private let drawableDisplayQuery: DrawableDisplayQuery
    private let onlineDisplayQuery: OnlineDisplayQuery
    private let hardwareFactsQuery: HardwareFactsQuery
    private let observationSeams: DisplayObservationSeams?
    private var callbackContext: DisplayReconfigurationCallbackContext?
    private(set) var callbackRemovalFailed = false
    private(set) var observationGeneration: RuntimeDisplayGeneration?
    private(set) var topologyGeneration: RuntimeDisplayGeneration?

    convenience init() {
        self.init(
            drawableDisplayQuery: { try Self.queryDrawableDisplays() },
            onlineDisplayQuery: { try Self.queryOnlineDisplayIDs() },
            hardwareFactsQuery: { Self.hardwareFacts(for: $0) },
            observationSeams: nil
        )
    }

    init(
        drawableDisplayQuery: @escaping DrawableDisplayQuery,
        onlineDisplayQuery: @escaping OnlineDisplayQuery,
        hardwareFactsQuery: @escaping HardwareFactsQuery,
        observationSeams: DisplayObservationSeams? = nil
    ) {
        self.drawableDisplayQuery = drawableDisplayQuery
        self.onlineDisplayQuery = onlineDisplayQuery
        self.hardwareFactsQuery = hardwareFactsQuery
        self.observationSeams = observationSeams
    }

    func currentDisplays() throws -> [RuntimeDisplay] {
        try drawableDisplayQuery()
    }

    func currentInventory() throws -> RuntimeDisplayInventory {
        let displays = try drawableDisplayQuery()
        let onlineIDs = try onlineDisplayQuery()
        var factsByID: [UInt32: DisplayHardwareFacts] = [:]
        for id in onlineIDs {
            factsByID[id] = try hardwareFactsQuery(id)
        }
        return try Self.makeInventory(
            drawableDisplays: displays,
            onlineIDs: onlineIDs,
            factsByID: factsByID
        )
    }

    static func makeInventory(
        drawableDisplays: [RuntimeDisplay],
        onlineIDs: [UInt32],
        factsByID: [UInt32: DisplayHardwareFacts]
    ) throws -> RuntimeDisplayInventory {
        let drawableIDs = drawableDisplays.map(\.id)
        guard !drawableIDs.contains(0), !onlineIDs.contains(0) else {
            throw DisplayQueryError.invalidScreenNumber
        }
        var seenDrawableIDs: Set<UInt32> = []
        for id in drawableIDs where !seenDrawableIDs.insert(id).inserted {
            throw DisplayQueryError.duplicateDrawableSessionID(id)
        }
        let uniqueOnlineIDs = Array(Set(onlineIDs)).sorted()
        guard uniqueOnlineIDs.count == onlineIDs.count else {
            throw DisplayQueryError.onlineDisplayCountRace(
                expected: UInt32(onlineIDs.count),
                actual: UInt32(uniqueOnlineIDs.count)
            )
        }
        for id in uniqueOnlineIDs where factsByID[id] == nil {
            throw DisplayQueryError.missingHardwareFacts(id)
        }
        guard Set(drawableIDs).isSubset(of: Set(uniqueOnlineIDs)) else {
            throw DisplayQueryError.missingCandidateDrawableMapping
        }
        let topology = RuntimeDisplayInventory.topology(
            displays: drawableDisplays,
            factsByID: factsByID,
            onlineIDs: uniqueOnlineIDs
        )
        return try RuntimeDisplayInventory(
            validating: drawableDisplays,
            topology: topology
        )
    }

    func startObserving(generation: RuntimeDisplayGeneration) throws {
        guard !isObserving else { return }
        guard !callbackRemovalFailed else {
            throw DisplayObservationError.priorRemovalFailed
        }
        if let observationSeams {
            try observationSeams.install { [weak self] flags in
                self?.receiveReconfiguration(
                    flags: flags,
                    observationGeneration: generation
                )
            }
        } else {
            let context = DisplayReconfigurationCallbackContext(
                service: self,
                generation: generation
            )
            let pointer = Unmanaged.passRetained(context).toOpaque()
            context.bindRegistrationPointer(pointer)
            let status = CGDisplayRegisterReconfigurationCallback(
                displayReconfigurationCallback,
                pointer
            )
            guard status == .success else {
                context.registrationFailed()
                throw DisplayObservationError.registrationFailed(status)
            }
            callbackContext = context
        }
        observationGeneration = generation
        topologyGeneration = nil
        isObserving = true
    }

    func stopObserving(invalidatedBy generation: RuntimeDisplayGeneration) {
        guard isObserving else { return }
        observationGeneration = generation
        topologyGeneration = nil
        isObserving = false
        if let observationSeams {
            observationSeams.remove()
        } else if let callbackContext {
            let status = CGDisplayRemoveReconfigurationCallback(
                displayReconfigurationCallback,
                Unmanaged.passUnretained(callbackContext).toOpaque()
            )
            if status == .success {
                callbackContext.registrationRemovalSucceeded()
            } else {
                callbackRemovalFailed = true
                callbackContext.registrationRemovalFailed()
            }
        }
        callbackContext = nil
    }

    fileprivate func receiveReconfiguration(
        flags: CGDisplayChangeSummaryFlags,
        observationGeneration: RuntimeDisplayGeneration
    ) {
        guard
            isObserving,
            observationGeneration == self.observationGeneration
        else { return }
        if flags.contains(.beginConfigurationFlag) {
            guard let onReconfigurationBegan else {
                topologyGeneration = nil
                return
            }
            topologyGeneration = onReconfigurationBegan(observationGeneration)
            return
        }
        guard let topologyGeneration else { return }
        do {
            onScreensChanged?(
                observationGeneration,
                topologyGeneration,
                .success(try currentInventory())
            )
        } catch {
            onScreensChanged?(
                observationGeneration,
                topologyGeneration,
                .failure(error)
            )
        }
    }

    private static func queryDrawableDisplays() throws -> [RuntimeDisplay] {
        try NSScreen.screens.map { screen in
            let rawNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            let displayID = CGDirectDisplayID(try sessionID(fromScreenNumber: rawNumber))
            let facts = hardwareFacts(for: UInt32(displayID))
            return RuntimeDisplay(
                id: UInt32(displayID),
                localizedName: screen.localizedName,
                isBuiltIn: facts.isBuiltIn,
                isMain: screen == NSScreen.main,
                isOnline: CGDisplayIsOnline(displayID) != 0,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                scale: Double(screen.backingScaleFactor),
                persistentUUID: facts.persistentUUID,
                mirrorSourceID: facts.mirrorSourceID,
                isInMirrorSet: facts.isInMirrorSet,
                vendorID: facts.vendorID,
                modelID: facts.modelID,
                serialNumber: facts.serialNumber
            )
        }
    }

    private static func queryOnlineDisplayIDs() throws -> [UInt32] {
        var expectedCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &expectedCount) == .success else {
            throw DisplayQueryError.onlineDisplayQueryFailed
        }
        guard expectedCount > 0 else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(expectedCount))
        var actualCount: UInt32 = 0
        let queryStatus = ids.withUnsafeMutableBufferPointer { buffer in
            CGGetOnlineDisplayList(expectedCount, buffer.baseAddress, &actualCount)
        }
        guard queryStatus == .success else {
            throw DisplayQueryError.onlineDisplayQueryFailed
        }
        guard actualCount == expectedCount else {
            throw DisplayQueryError.onlineDisplayCountRace(
                expected: expectedCount,
                actual: actualCount
            )
        }
        return Array(ids[0..<Int(actualCount)])
    }

    private static func hardwareFacts(for id: UInt32) -> DisplayHardwareFacts {
        let displayID = CGDirectDisplayID(id)
        let mirrorSource = CGDisplayMirrorsDisplay(displayID)
        return DisplayHardwareFacts(
            isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
            mirrorSourceID: mirrorSource == kCGNullDirectDisplay ? nil : UInt32(mirrorSource),
            isInMirrorSet: CGDisplayIsInMirrorSet(displayID) != 0,
            persistentUUID: uuidString(for: displayID),
            vendorID: meaningful(CGDisplayVendorNumber(displayID)),
            modelID: meaningful(CGDisplayModelNumber(displayID)),
            serialNumber: meaningful(CGDisplaySerialNumber(displayID))
        )
    }

    static func sessionID(fromScreenNumber value: Any?) throws -> UInt32 {
        guard let number = value as? NSNumber else {
            throw DisplayQueryError.missingScreenNumber
        }
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw DisplayQueryError.invalidScreenNumber
        }
        let numericValue = number.doubleValue
        guard numericValue.isFinite,
            numericValue.rounded(.towardZero) == numericValue,
            numericValue >= 1,
            numericValue <= Double(UInt32.max)
        else { throw DisplayQueryError.invalidScreenNumber }
        return UInt32(numericValue)
    }

    nonisolated static func fingerprint(
        localizedName: String,
        facts: DisplayHardwareFacts
    ) -> DisplayFingerprint {
        DisplayFingerprint(
            uuid: facts.persistentUUID,
            vendorID: facts.vendorID,
            modelID: facts.modelID,
            serialNumber: facts.serialNumber,
            isBuiltIn: facts.isBuiltIn,
            lastLocalizedName: localizedName,
            confidence: RuntimeDisplayInventory.confidence(for: facts)
        ).normalized
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
    let context = Unmanaged<DisplayReconfigurationCallbackContext>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    context.enqueue(flags.rawValue)
}
