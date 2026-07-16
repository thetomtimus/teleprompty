import AppKit
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class SystemDisplayServiceTests: XCTestCase {
    func testMapsNSScreenNumberToSessionID() throws {
        XCTAssertEqual(
            try SystemDisplayService.sessionID(fromScreenNumber: NSNumber(value: UInt32(42))),
            42
        )
    }

    func testMissingOrWrongTypedNSScreenNumberFailsClosed() {
        XCTAssertThrowsError(try SystemDisplayService.sessionID(fromScreenNumber: nil))
        XCTAssertThrowsError(try SystemDisplayService.sessionID(fromScreenNumber: "42"))
    }

    func testZeroSessionIDFailsClosed() {
        XCTAssertThrowsError(
            try SystemDisplayService.sessionID(fromScreenNumber: NSNumber(value: UInt32(0)))
        ) { error in
            XCTAssertEqual(error as? DisplayQueryError, .invalidScreenNumber)
        }
    }

    func testBuildsFingerprintFromUUIDAndHardware() {
        let fingerprint = SystemDisplayService.fingerprint(
            localizedName: "Generated Display",
            facts: DisplayHardwareFacts(
                isBuiltIn: false,
                mirrorSourceID: nil,
                isInMirrorSet: false,
                persistentUUID: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
                vendorID: 0,
                modelID: 2,
                serialNumber: 0
            )
        )

        XCTAssertEqual(fingerprint.uuid, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        XCTAssertNil(fingerprint.vendorID)
        XCTAssertEqual(fingerprint.modelID, 2)
        XCTAssertNil(fingerprint.serialNumber)
        XCTAssertNotNil(fingerprint.persistentIdentityKey)
    }

    func testDuplicateDrawableSessionIDsFailClosed() {
        XCTAssertThrowsError(
            try inventory(
                drawable: [display(id: 1), display(id: 1)],
                online: [1],
                facts: [1: facts(id: 1)]
            )
        ) { error in
            XCTAssertEqual(error as? DisplayQueryError, .duplicateDrawableSessionID(1))
        }
    }

    func testDuplicateOnlineSessionIDsFailClosed() {
        XCTAssertThrowsError(
            try inventory(
                drawable: [display(id: 1)],
                online: [1, 1],
                facts: [1: facts(id: 1)]
            )
        )
    }

    func testQueryFailureIsUnsafe() {
        struct QueryFailure: Error {}
        let service = SystemDisplayService(
            drawableDisplayQuery: { [self.display(id: 1)] },
            onlineDisplayQuery: { throw QueryFailure() },
            hardwareFactsQuery: { self.facts(id: $0) }
        )

        XCTAssertThrowsError(try service.currentInventory())
    }

    func testRuntimeInventoryRequiresDrawableDestinationsAndTopology() throws {
        let drawable = display(id: 1)
        let topology = DisplayTopologySnapshot(
            displays: [descriptor(id: 2, drawable: false)],
            querySucceeded: true
        )

        XCTAssertThrowsError(
            try RuntimeDisplayInventory(validating: [drawable], topology: topology)
        ) { error in
            XCTAssertEqual(error as? DisplayQueryError, .missingCandidateDrawableMapping)
        }
    }

    func testProductionCurrentInventoryIncludesNonDrawableOnlineMirrorSink() throws {
        let drawable = display(id: 1)
        let service = SystemDisplayService(
            drawableDisplayQuery: { [drawable] },
            onlineDisplayQuery: { [1, 2] },
            hardwareFactsQuery: { id in
                id == 1
                    ? self.facts(id: 1, inMirrorSet: true)
                    : self.facts(id: 2, mirrorSourceID: 1, inMirrorSet: true)
            }
        )

        let inventory = try service.currentInventory()

        XCTAssertEqual(inventory.displays.map(\.id), [1])
        XCTAssertEqual(inventory.topology.displays.map(\.sessionID), [1, 2])
        XCTAssertTrue(inventory.topology.verifiedMirroring)
    }

    func testCGOnlyTopologyMemberHasNoVisibleFrameScaleOrDestinationEligibility() throws {
        let inventory = try inventory(
            drawable: [display(id: 1)],
            online: [1, 2],
            facts: [
                1: facts(id: 1),
                2: facts(id: 2),
            ]
        )

        let cgOnly = try XCTUnwrap(
            inventory.topology.displays.first { $0.sessionID == 2 }
        )
        XCTAssertNil(cgOnly.bounds)
        XCTAssertNil(cgOnly.visibleFrame)
        XCTAssertNil(cgOnly.scale)
        XCTAssertFalse(cgOnly.isDrawableDestination)
    }

    func testDrawableDestinationsRemainNSScreenBacked() throws {
        let destination = display(id: 7)
        let inventory = try inventory(
            drawable: [destination],
            online: [7],
            facts: [7: facts(id: 7)]
        )

        let descriptor = try XCTUnwrap(inventory.topology.displays.first)
        XCTAssertEqual(inventory.displays, [destination])
        XCTAssertTrue(descriptor.isDrawableDestination)
        XCTAssertEqual(descriptor.bounds, DisplayRect(destination.frame))
        XCTAssertEqual(descriptor.visibleFrame, DisplayRect(destination.visibleFrame))
        XCTAssertEqual(descriptor.scale, destination.scale)
    }

    func testOnlineMirroredSinkMissingFromDrawableScreensStillBlocks() throws {
        let drawable = display(id: 1)
        let inventory = try inventory(
            drawable: [drawable],
            online: [1, 2],
            facts: [
                1: facts(id: 1, inMirrorSet: true),
                2: facts(id: 2, mirrorSourceID: 1, inMirrorSet: true),
            ]
        )

        let evaluation = DisplayTopologyEvaluator().evaluate(
            snapshot: inventory.topology,
            selection: DisplaySelection(
                fingerprint: inventory.topology.displays[0].fingerprint,
                isConfirmed: true,
                isConfirmedInCurrentSession: true,
                currentSessionID: 1
            )
        )

        XCTAssertEqual(evaluation.assessment, .blockedMirroring)
        XCTAssertFalse(evaluation.canOpenOverlay)
    }

    func testAllOnlineMirrorSourceAndSinkAreExported() throws {
        let inventory = try inventory(
            drawable: [display(id: 1)],
            online: [1, 2],
            facts: [
                1: facts(id: 1, inMirrorSet: true),
                2: facts(id: 2, mirrorSourceID: 1, inMirrorSet: true),
            ]
        )

        let source = try XCTUnwrap(inventory.topology.displays.first { $0.sessionID == 1 })
        let sink = try XCTUnwrap(inventory.topology.displays.first { $0.sessionID == 2 })
        XCTAssertEqual(source.mirroredSessionIDs, [2])
        XCTAssertEqual(sink.mirrorSourceSessionID, 1)
    }

    func testOnlineDisplayQueryFailureFailsClosed() {
        struct QueryFailure: Error {}
        let service = SystemDisplayService(
            drawableDisplayQuery: { [self.display(id: 1)] },
            onlineDisplayQuery: { throw QueryFailure() },
            hardwareFactsQuery: { self.facts(id: $0) }
        )

        XCTAssertThrowsError(try service.currentInventory())
    }

    func testOnlineDisplayCountRaceFailsClosed() {
        XCTAssertThrowsError(
            try inventory(
                drawable: [display(id: 1)],
                online: [1, 1],
                facts: [1: facts(id: 1)]
            )
        ) { error in
            XCTAssertEqual(
                error as? DisplayQueryError,
                .onlineDisplayCountRace(expected: 2, actual: 1)
            )
        }
    }

    func testMissingCandidateDrawableMappingFailsClosed() {
        XCTAssertThrowsError(
            try inventory(
                drawable: [display(id: 9)],
                online: [1],
                facts: [1: facts(id: 1)]
            )
        ) { error in
            XCTAssertEqual(error as? DisplayQueryError, .missingCandidateDrawableMapping)
        }
    }

    func testObservationAndTopologyGenerationsAreMonotonicAndRuntimeOnly() throws {
        let source = M5ManualDisplayObservationSource()
        let service = SystemDisplayService(
            drawableDisplayQuery: { [self.display(id: 1)] },
            onlineDisplayQuery: { [1] },
            hardwareFactsQuery: { self.facts(id: $0) },
            observationSeams: DisplayObservationSeams(
                install: { source.install($0) },
                remove: { source.remove() }
            )
        )
        var nextTopologyRawValue: UInt64 = 2
        service.onReconfigurationBegan = { _ in
            defer { nextTopologyRawValue += 1 }
            return RuntimeDisplayGeneration(rawValue: nextTopologyRawValue)
        }

        try service.startObserving(
            generation: RuntimeDisplayGeneration(rawValue: 1)
        )
        let firstObservation = try XCTUnwrap(service.observationGeneration)
        source.fire(.beginConfigurationFlag)
        let firstTopology = try XCTUnwrap(service.topologyGeneration)
        source.fire([])
        source.fire(.beginConfigurationFlag)
        let secondTopology = try XCTUnwrap(service.topologyGeneration)
        service.stopObserving(
            invalidatedBy: RuntimeDisplayGeneration(rawValue: 4)
        )
        let stoppedObservation = try XCTUnwrap(service.observationGeneration)
        try service.startObserving(
            generation: RuntimeDisplayGeneration(rawValue: 5)
        )
        let secondObservation = try XCTUnwrap(service.observationGeneration)

        XCTAssertGreaterThan(firstObservation.rawValue, 0)
        XCTAssertGreaterThan(secondTopology.rawValue, firstTopology.rawValue)
        XCTAssertGreaterThan(stoppedObservation.rawValue, firstObservation.rawValue)
        XCTAssertGreaterThan(secondObservation.rawValue, stoppedObservation.rawValue)

        let persistedSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
                ),
            encoding: .utf8
        )
        XCTAssertFalse(persistedSource.contains("DisplayObservationGeneration"))
        XCTAssertFalse(persistedSource.contains("TopologyTransactionGeneration"))
        let runtimeSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("PrivatePresenterApp/App/AppRuntime.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(runtimeSource.contains("addingReportingOverflow(1)"))
        XCTAssertTrue(runtimeSource.contains("issueDisplayGeneration()"))
        service.stopObserving(
            invalidatedBy: RuntimeDisplayGeneration(rawValue: 6)
        )
    }

    func testQueuedDisplayCallbackAfterStopIsIgnored() throws {
        let source = M5ManualDisplayObservationSource()
        var deliveries: [Result<RuntimeDisplayInventory, Error>] = []
        var service: SystemDisplayService? = SystemDisplayService(
            drawableDisplayQuery: { [self.display(id: 1)] },
            onlineDisplayQuery: { [1] },
            hardwareFactsQuery: { self.facts(id: $0) },
            observationSeams: DisplayObservationSeams(
                install: { source.install($0) },
                remove: { source.remove() }
            )
        )
        weak var weakService = service
        service?.onReconfigurationBegan = { _ in
            RuntimeDisplayGeneration(rawValue: 2)
        }
        service?.onScreensChanged = { _, _, result in deliveries.append(result) }
        try service?.startObserving(
            generation: RuntimeDisplayGeneration(rawValue: 1)
        )
        let queued = try XCTUnwrap(source.latestInstalledCallback)

        service?.stopObserving(
            invalidatedBy: RuntimeDisplayGeneration(rawValue: 3)
        )
        service = nil
        queued([])

        XCTAssertTrue(deliveries.isEmpty)
        XCTAssertNil(weakService)
        XCTAssertEqual(source.removeCount, 1)
    }

    func testNativeCallbackContextRetainsUntilRemovalAndDrainOrLeaksOnFailure() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "PrivatePresenterApp/Services/SystemDisplayService.swift"
                ),
            encoding: .utf8
        )

        for marker in [
            "Unmanaged.passRetained(context).toOpaque()",
            "pendingDeliveries += 1",
            "pendingDeliveries -= 1",
            "registrationRemovalSucceeded()",
            "removalSucceeded && pendingDeliveries == 0",
            "registrationRemovalFailed()",
            "keep the passRetained ownership forever",
        ] {
            XCTAssertTrue(source.contains(marker), marker)
        }
        XCTAssertFalse(
            source.contains(
                "CGDisplayRemoveReconfigurationCallback(\n"
                    + "                displayReconfigurationCallback,\n"
                    + "                Unmanaged.passUnretained(callbackContext).toOpaque()\n"
                    + "            )\n        }\n        callbackContext = nil"
            )
        )
    }

    private func inventory(
        drawable: [RuntimeDisplay],
        online: [UInt32],
        facts: [UInt32: DisplayHardwareFacts]
    ) throws -> RuntimeDisplayInventory {
        try SystemDisplayService.makeInventory(
            drawableDisplays: drawable,
            onlineIDs: online,
            factsByID: facts
        )
    }

    private func display(id: UInt32) -> RuntimeDisplay {
        RuntimeDisplay(
            id: id,
            localizedName: "Display \(id)",
            isBuiltIn: id == 1,
            isMain: id == 1,
            isOnline: true,
            frame: NSRect(x: Int(id - 1) * 1_440, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: Int(id - 1) * 1_440, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "uuid-\(id)",
            mirrorSourceID: nil,
            isInMirrorSet: false,
            vendorID: 1,
            modelID: id,
            serialNumber: id
        )
    }

    private func descriptor(id: UInt32, drawable: Bool) -> DisplayDescriptor {
        DisplayDescriptor(
            sessionID: id,
            fingerprint: DisplayFingerprint(
                uuid: "uuid-\(id)",
                vendorID: 1,
                modelID: id,
                serialNumber: id,
                isBuiltIn: id == 1,
                lastLocalizedName: "Display \(id)",
                confidence: .strong
            ),
            localizedName: "Display \(id)",
            isBuiltIn: id == 1,
            isMain: id == 1,
            isOnline: true,
            bounds: drawable ? DisplayRect(x: 0, y: 0, width: 1_440, height: 900) : nil,
            visibleFrame: drawable
                ? DisplayRect(x: 0, y: 0, width: 1_440, height: 860)
                : nil,
            scale: drawable ? 2 : nil
        )
    }

    private func facts(
        id: UInt32,
        mirrorSourceID: UInt32? = nil,
        inMirrorSet: Bool = false
    ) -> DisplayHardwareFacts {
        DisplayHardwareFacts(
            isBuiltIn: id == 1,
            mirrorSourceID: mirrorSourceID,
            isInMirrorSet: inMirrorSet,
            persistentUUID: "uuid-\(id)",
            vendorID: 1,
            modelID: id,
            serialNumber: id
        )
    }
}

@MainActor
private final class M5ManualDisplayObservationSource {
    typealias Callback = @MainActor (CGDisplayChangeSummaryFlags) -> Void

    private var installedCallback: Callback?
    private(set) var latestInstalledCallback: Callback?
    private(set) var removeCount = 0

    func install(_ callback: @escaping Callback) {
        installedCallback = callback
        latestInstalledCallback = callback
    }

    func remove() {
        installedCallback = nil
        removeCount += 1
    }

    func fire(_ flags: CGDisplayChangeSummaryFlags) {
        installedCallback?(flags)
    }
}
