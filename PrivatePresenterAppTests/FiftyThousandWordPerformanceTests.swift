import CryptoKit
import Foundation
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class FiftyThousandWordPerformanceTests: XCTestCase {
    private static let baselineEnvironmentKey = "PRIVATE_PRESENTER_M5_BASELINE"
    private static let expectedWordCount = 50_000
    private static let expectedByteCount = 499_999
    private static let expectedDigest =
        "d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4"
    private static let actionCadence = 0.100
    private static let maximumLoadDuration = 2.000
    private static let maximumP95EditDuration = 0.050
    private static let maximumEditOrStallDuration = 0.100

    func testFiftyThousandWordLoad() async throws {
        try requireAbsoluteBaseline()
        let fixture = try swiftFixture()
        let harness = try makeHarness(fixture: fixture)
        let pristine = try await harness.preparePristineSnapshot()

        assertPristineSnapshot(pristine)
        XCTAssertFalse(pristine.usedDisposableBaselineAccount)
        XCTAssertFalse(pristine.normalApplicationSupportWasEmpty)
        let externalRecord = try M5AbsolutePerformanceEvidenceGate
            .loadValidatedExternalRecord(expected: pristine)

        try await harness.resetToPristineSnapshot()
        let warmup = try await harness.runLoadTrial(measured: false)
        XCTAssertFalse(warmup.wasMeasured)
        assertCompleteLoadEndpoint(warmup)

        var trials: [M5LoadTrialResult] = []
        for _ in 0..<3 {
            try await harness.resetToPristineSnapshot()
            let trial = try await harness.runLoadTrial(measured: true)
            trials.append(trial)
            assertCompleteLoadEndpoint(trial)
            XCTAssertEqual(trial.snapshotIdentity, pristine.snapshotIdentity)
            XCTAssertEqual(trial.executableIdentity, pristine.executableIdentity)
            XCTAssertEqual(trial.evidenceScope, .inProcessSemanticOnly)
        }

        XCTAssertEqual(trials.count, 3)
        XCTAssertTrue(trials.allSatisfy(\.wasMeasured))
        XCTAssertEqual(harness.unrecordedWarmupCount, 1)
        XCTAssertEqual(harness.recordedCleanLoadCount, 3)
        XCTAssertEqual(harness.pristineResetCount, 4)
        XCTAssertTrue(
            externalRecord.loadDurationsSeconds.allSatisfy {
                $0 <= Self.maximumLoadDuration
            }
        )
    }

    func testRepeatedEditDoesNotRebuildWholeReader() async throws {
        let fixture = try swiftFixture()
        let actions = try exactEditActions(for: fixture)
        let result = try await makeHarness(fixture: fixture).runEditSequence(
            actions: actions,
            cadence: Self.actionCadence,
            measuresWallClock: false
        )

        XCTAssertEqual(result.actionCount, 300)
        XCTAssertEqual(result.acceptedEditCount, 300)
        XCTAssertEqual(result.editToVisibleIntervalCount, 300)
        XCTAssertEqual(result.incrementalReaderMutationCount, 300)
        XCTAssertEqual(result.scheduledCadence, Self.actionCadence, accuracy: 0.000_001)
        XCTAssertEqual(result.fullReplacementCountAfter, result.fullReplacementCountBefore)
        XCTAssertEqual(result.resyncCount, 0)
        XCTAssertTrue(result.fixtureWasRestoredAfterEveryPair)
        XCTAssertEqual(result.finalFixture, fixture)
        XCTAssertEqual(result.openIntervalCount, 0)
    }

    func testDebouncedSaveDoesNotBlockMainActor() async throws {
        let fixture = try swiftFixture()
        let result = try await makeHarness(fixture: fixture).runDelayedFilesystemEdit(
            delay: 0.200
        )

        XCTAssertEqual(result.filesystemDelay, 0.200, accuracy: 0.000_001)
        XCTAssertTrue(result.editReturnedBeforeFilesystemCompletion)
        XCTAssertFalse(result.editAwaitedPersistence)
        XCTAssertTrue(result.mainActorSentinelRanWhileFilesystemWasDelayed)
        XCTAssertEqual(result.editToVisibleIntervalCount, 1)
    }

    func testScrollTicksDoNotMutateTextOrPublishPerFrame() async throws {
        let fixture = try swiftFixture()
        let result = try await makeHarness(fixture: fixture).runDeterministicTickProbe()

        XCTAssertGreaterThan(result.tickCount, 0)
        XCTAssertEqual(result.textMutationDelta, 0)
        XCTAssertEqual(result.persistenceEnqueueDelta, 0)
        XCTAssertEqual(result.attributedRebuildDelta, 0)
        XCTAssertEqual(result.swiftUIPublishDelta, 0)
        XCTAssertEqual(result.subsecondCheckpointPublishDelta, 0)
        XCTAssertEqual(result.tickIntervalCount, result.tickCount)
        XCTAssertEqual(result.openTickIntervalCount, 0)
        XCTAssertFalse(result.sessionLeaked)
    }

    func testFixtureIsExactlyFiftyThousandWords() throws {
        let fixture = try swiftFixture()
        let text = try XCTUnwrap(String(data: fixture, encoding: .utf8))
        let words = text.split(whereSeparator: { $0.isWhitespace })

        XCTAssertEqual(words.count, Self.expectedWordCount)
        XCTAssertEqual(fixture.count, Self.expectedByteCount)
        XCTAssertEqual(text.utf16.count, Self.expectedByteCount)
        XCTAssertEqual(words.first.map(String.init), "word00000")
        XCTAssertEqual(words.last.map(String.init), "word49999")
        XCTAssertEqual(digest(of: fixture), Self.expectedDigest)
        XCTAssertFalse(fixture.isEmpty)
        XCTAssertNotEqual(fixture.last, 0x0A)

        let separators = fixture.enumerated().compactMap { index, byte in
            byte == 0x0A ? index : nil
        }
        XCTAssertEqual(separators.count, 2_499)
        for separator in separators {
            XCTAssertEqual((separator + 1) % 200, 0)
        }
    }

    func testSwiftFixtureMatchesGeneratedBytesAndDigest() throws {
        let swiftBytes = try swiftFixture()
        let generatedBytes = try pythonGeneratedFixture()

        XCTAssertEqual(swiftBytes, generatedBytes)
        XCTAssertEqual(swiftBytes.count, Self.expectedByteCount)
        XCTAssertEqual(digest(of: swiftBytes), Self.expectedDigest)
        XCTAssertEqual(digest(of: generatedBytes), Self.expectedDigest)
    }

    func testLoadMeasurementEndpointRequiresEditAndMainActorSentinel() async throws {
        let fixture = try swiftFixture()
        let harness = try makeHarness(fixture: fixture)
        let pristine = try await harness.preparePristineSnapshot()
        assertPristineSnapshot(pristine)
        try await harness.resetToPristineSnapshot()

        let trial = try await harness.runLoadTrial(measured: false)

        XCTAssertEqual(
            trial.endpointEvents,
            [
                .snapshotLoadBegan,
                .snapshotRestored,
                .editorAttached,
                .readerAttached,
                .firstReaderLayoutCompleted,
                .syntheticEditAccepted,
                .syntheticEditReflectedInReader,
                .mainActorSentinelCompleted,
                .measurementEnded,
            ]
        )
        assertCompleteLoadEndpoint(trial)
        XCTAssertEqual(trial.syntheticEditCount, 1)
        XCTAssertEqual(trial.openIntervalCount, 0)
    }

    func testThreeHundredEditSequenceRestoresFixtureAfterEveryPair() throws {
        let fixture = try swiftFixture()
        let actions = try exactEditActions(for: fixture)
        var candidate = fixture

        XCTAssertEqual(actions.count, 300)
        XCTAssertEqual(actions.count / 6, 50)
        for (index, action) in actions.enumerated() {
            switch action {
            case .insertASCIIX(let offset):
                XCTAssertTrue(offset == 0 || offset == 250_000 || offset == 499_999)
                candidate.insert(0x78, at: offset)
            case .deleteASCIIX(let offset):
                XCTAssertEqual(candidate[offset], 0x78)
                candidate.remove(at: offset)
            }
            if index % 2 == 1 {
                XCTAssertEqual(candidate, fixture, "pair \((index + 1) / 2)")
            }
        }
        XCTAssertEqual(candidate, fixture)
    }

    func testNearestRankP95UsesSampleTwoHundredEightyFive() {
        let sortedSamples = (1...300).map(Double.init)
        let oneBasedRank = Int(ceil(0.95 * Double(sortedSamples.count)))

        XCTAssertEqual(oneBasedRank, 285)
        XCTAssertEqual(sortedSamples[oneBasedRank - 1], 285)
        XCTAssertEqual(nearestRankP95(sortedSamples), 285)
    }

    func testEveryEditAndMainThreadStallUsesOneHundredMillisecondCeiling() async throws {
        try requireAbsoluteBaseline()
        let fixture = try swiftFixture()
        let harness = try makeHarness(fixture: fixture)
        let receipt = try await harness.preparePristineSnapshot()
        let externalRecord = try M5AbsolutePerformanceEvidenceGate
            .loadValidatedExternalRecord(expected: receipt)
        let result = try await harness.runEditSequence(
            actions: exactEditActions(for: fixture),
            cadence: Self.actionCadence,
            measuresWallClock: false
        )
        let sortedDurations = externalRecord.editDurationsSeconds.sorted()

        XCTAssertEqual(result.scheduledCadence, 0.100, accuracy: 0.000_001)
        XCTAssertEqual(sortedDurations.count, 300)
        XCTAssertEqual(result.editToVisibleIntervalCount, 300)
        XCTAssertFalse(result.mainThreadStallProbeWasActive)
        XCTAssertLessThan(nearestRankP95(sortedDurations), Self.maximumP95EditDuration)
        XCTAssertTrue(
            sortedDurations.allSatisfy { $0 <= Self.maximumEditOrStallDuration }
        )
        XCTAssertTrue(
            externalRecord.mainThreadStallDurationsSeconds.allSatisfy {
                $0 <= Self.maximumEditOrStallDuration
            }
        )
        XCTAssertEqual(result.fullReplacementCountAfter, result.fullReplacementCountBefore)
        XCTAssertEqual(result.resyncCount, 0)
        XCTAssertTrue(result.fixtureWasRestoredAfterEveryPair)
        XCTAssertEqual(result.finalFixture, fixture)
    }

    func testScrollMemoryUsesFivePointOrdinaryLeastSquares() async throws {
        try requireAbsoluteBaseline()
        let fixture = try swiftFixture()
        let harness = try makeHarness(fixture: fixture)
        let receipt = try await harness.preparePristineSnapshot()
        let externalRecord = try M5AbsolutePerformanceEvidenceGate
            .loadValidatedExternalRecord(expected: receipt)
        let result = try await harness.runSixMinuteScrollSession(
            warmupDuration: 60,
            measuredDuration: 300,
            totalSampleTimes: [120, 180, 240, 300, 360]
        )

        XCTAssertEqual(result.totalDuration, 360, accuracy: 0.100)
        XCTAssertEqual(result.warmupDuration, 60, accuracy: 0.000_001)
        XCTAssertEqual(result.measuredDuration, 300, accuracy: 0.000_001)
        XCTAssertEqual(result.totalSampleTimes, [120, 180, 240, 300, 360])
        XCTAssertEqual(result.measuredSampleTimes, [60, 120, 180, 240, 300])
        XCTAssertEqual(result.processFootprintBytes.count, 5)
        XCTAssertEqual(result.memoryEvidenceScope, .processFootprintSemanticOnly)
        XCTAssertFalse(result.provesInstrumentsAllocationSamples)
        XCTAssertEqual(externalRecord.allocationsLiveBytes.count, 5)
        XCTAssertEqual(result.sessionCount, 1)
        XCTAssertTrue(result.usedActualDisplayLink)
        XCTAssertEqual(result.processFootprintBaselineTotalTime, 60, accuracy: 0.100)
        XCTAssertGreaterThan(result.tickCount, 0)
        XCTAssertTrue(result.mainThreadStallProbeWasActive)

        let provisionalProcessMiB = result.processFootprintBytes.map {
            Double($0) / 1_048_576
        }
        XCTAssertEqual(
            result.provisionalProcessFootprintSlopeMiBPerMinute,
            ordinaryLeastSquaresSlope(x: [1, 2, 3, 4, 5], y: provisionalProcessMiB),
            accuracy: 0.000_001
        )

        let liveMiB = externalRecord.allocationsLiveBytes.map { Double($0) / 1_048_576 }
        let slope = ordinaryLeastSquaresSlope(
            x: [1, 2, 3, 4, 5],
            y: liveMiB
        )
        XCTAssertLessThanOrEqual(slope, 1.0)
        XCTAssertLessThanOrEqual(liveMiB[4] - liveMiB[0], 5.0)
        XCTAssertTrue(
            externalRecord.scrollMainThreadStallDurationsSeconds.allSatisfy { $0 <= 0.100 }
        )
        XCTAssertEqual(result.textMutationDelta, 0)
        XCTAssertEqual(result.persistenceEnqueueDelta, 0)
        XCTAssertEqual(result.attributedRebuildDelta, 0)
        XCTAssertEqual(result.swiftUIPublishDelta, 0)
        XCTAssertEqual(result.openTickIntervalCount, 0)
        XCTAssertFalse(result.sessionLeaked)
    }

    func testAbsoluteThresholdsRequireExplicitBaselineOptIn() {
        XCTAssertFalse(Self.baselineOptedIn(environment: [:]))
        XCTAssertFalse(
            Self.baselineOptedIn(
                environment: [Self.baselineEnvironmentKey: "true"]
            )
        )
        XCTAssertFalse(
            Self.baselineOptedIn(
                environment: [Self.baselineEnvironmentKey: "01"]
            )
        )
        XCTAssertTrue(
            Self.baselineOptedIn(
                environment: [Self.baselineEnvironmentKey: "1"]
            )
        )
    }

    func testDelayedFilesystemDoesNotBlockEditAndFinalRevisionFlushes() async throws {
        let fixture = try swiftFixture()
        let result = try await makeHarness(fixture: fixture).runDelayedFilesystemEdit(
            delay: 0.200
        )

        XCTAssertEqual(result.filesystemDelay, 0.200, accuracy: 0.000_001)
        XCTAssertTrue(result.editReturnedBeforeFilesystemCompletion)
        XCTAssertFalse(result.editAwaitedPersistence)
        XCTAssertTrue(result.readerReflectedEditBeforeFilesystemCompletion)
        XCTAssertEqual(result.editToVisibleIntervalCount, 1)
        XCTAssertGreaterThanOrEqual(result.finalSnapshotRevision, result.finalDocumentRevision)
        XCTAssertEqual(result.finalPersistedRevision, result.finalSnapshotRevision)
        XCTAssertGreaterThanOrEqual(result.snapshotWriteCount, 1)
        XCTAssertLessThanOrEqual(result.snapshotWriteCount, 2)
        XCTAssertTrue(result.flushCompleted)
        XCTAssertEqual(result.openIntervalCount, 0)
    }

    // Independent-review contract: this in-process AppRuntime exercise proves semantic
    // endpoints only. It cannot stand in for a fresh process, the normal-store reset in a
    // disposable account, the same executable identity, or Instruments timing.
    func testInProcessLoadTrialIsSemanticOnlyAndCannotProveAbsoluteBaseline() async throws {
        let fixture = try swiftFixture()
        let harness = try makeHarness(fixture: fixture)
        _ = try await harness.preparePristineSnapshot()
        try await harness.resetToPristineSnapshot()

        let trial = try await harness.runLoadTrial(measured: false)

        XCTAssertEqual(trial.evidenceScope, .inProcessSemanticOnly)
        XCTAssertFalse(trial.provesPriorProcessTermination)
        XCTAssertFalse(trial.provesNormalStoreDisposableAccountReset)
        XCTAssertFalse(trial.provesSameExecutableFreshProcess)
        XCTAssertFalse(trial.provesInstrumentsTimeProfile)
        XCTAssertFalse(trial.provesTwoSecondAbsoluteThreshold)
        XCTAssertFalse(trial.provesAbsoluteLoadBaseline)
        XCTAssertThrowsError(
            try M5AbsolutePerformanceEvidenceGate
                .requireExternalFreshProcessInstrumentsLoadRecord(
                for: trial
            )
        )
    }

    // processFootprintBytes is useful semantic instrumentation, but it is not the
    // Allocations live-bytes series required by the absolute five-point OLS gate.
    func testProcessFootprintCannotSubstituteForInstrumentsAllocationSamples() async throws {
        let fixture = try swiftFixture()
        let result = try await makeHarness(fixture: fixture)
            .runProcessFootprintSemanticProbe(sampleCount: 5)

        XCTAssertEqual(result.memoryEvidenceScope, .processFootprintSemanticOnly)
        XCTAssertFalse(result.provesInstrumentsAllocationSamples)
        XCTAssertFalse(result.provesAllocationsLiveBytes)
        XCTAssertThrowsError(
            try M5AbsolutePerformanceEvidenceGate
                .requireExternalInstrumentsAllocationsRecord(
                for: result
            )
        )
    }

    func testExternalInstrumentsRecordIsRequiredAndRejectsProcessFootprintSubstitution() throws {
        let receipt = M5PristineSnapshotReceipt(
            schemaVersion: 1,
            fixtureWordCount: 50_000,
            fixtureByteCount: 499_999,
            fixtureUTF16Count: 499_999,
            fixtureDigest: String(repeating: "a", count: 64),
            isPaused: true,
            isHidden: true,
            runtimeDisplayWasCleared: true,
            requiresDisplayConfirmation: true,
            usedProductionSnapshotStoreImplementation: true,
            seedAndFlushCount: 1,
            usedPasteOrImportPath: false,
            usedDebugUITestStoreOverride: false,
            evidenceScope: .inProcessSemanticOnly,
            usedDisposableBaselineAccount: false,
            normalApplicationSupportWasEmpty: false,
            sourceIdentity: String(repeating: "d", count: 40),
            snapshotIdentity: String(repeating: "b", count: 64),
            executableIdentity: String(repeating: "c", count: 64)
        )
        XCTAssertThrowsError(
            try M5AbsolutePerformanceEvidenceGate.loadValidatedExternalRecord(
                expected: receipt,
                environment: [:]
            )
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-m5-external-record-\(UUID().uuidString).json"
        )
        defer { try? FileManager.default.removeItem(at: url) }
        var record = externalRecordDictionary(receipt: receipt)
        try JSONSerialization.data(withJSONObject: record).write(to: url)
        let environment = [
            M5AbsolutePerformanceEvidenceGate.recordEnvironmentKey: url.path,
            M5AbsolutePerformanceEvidenceGate.sourceSHAEnvironmentKey:
                String(repeating: "d", count: 40),
        ]
        let validated = try M5AbsolutePerformanceEvidenceGate.loadValidatedExternalRecord(
            expected: receipt,
            environment: environment
        )
        XCTAssertEqual(validated.allocationsLiveBytes, [1, 2, 3, 4, 5])

        record["processFootprintBytes"] = [1, 2, 3, 4, 5]
        try JSONSerialization.data(withJSONObject: record).write(to: url)

        XCTAssertThrowsError(
            try M5AbsolutePerformanceEvidenceGate.loadValidatedExternalRecord(
                expected: receipt,
                environment: environment
            )
        ) { error in
            XCTAssertEqual(
                error as? M5AbsolutePerformanceEvidenceError,
                .externalRecordShapeMismatch
            )
        }
    }

    private func assertPristineSnapshot(
        _ receipt: M5PristineSnapshotReceipt,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(receipt.schemaVersion, 1, file: file, line: line)
        XCTAssertEqual(receipt.fixtureWordCount, 50_000, file: file, line: line)
        XCTAssertEqual(receipt.fixtureByteCount, 499_999, file: file, line: line)
        XCTAssertEqual(receipt.fixtureUTF16Count, 499_999, file: file, line: line)
        XCTAssertEqual(receipt.fixtureDigest, Self.expectedDigest, file: file, line: line)
        XCTAssertTrue(receipt.isPaused, file: file, line: line)
        XCTAssertTrue(receipt.isHidden, file: file, line: line)
        XCTAssertTrue(receipt.runtimeDisplayWasCleared, file: file, line: line)
        XCTAssertTrue(receipt.requiresDisplayConfirmation, file: file, line: line)
        XCTAssertTrue(
            receipt.usedProductionSnapshotStoreImplementation,
            file: file,
            line: line
        )
        XCTAssertEqual(receipt.seedAndFlushCount, 1, file: file, line: line)
        XCTAssertFalse(receipt.usedPasteOrImportPath, file: file, line: line)
        XCTAssertFalse(receipt.usedDebugUITestStoreOverride, file: file, line: line)
    }

    private func externalRecordDictionary(
        receipt: M5PristineSnapshotReceipt
    ) -> [String: Any] {
        [
            "schemaVersion": 1,
            "recordKind": "private-presenter-m5-external-instruments",
            "sourceSHA": String(repeating: "d", count: 40),
            "executableSHA256": receipt.executableIdentity,
            "pristineSnapshotSHA256": receipt.snapshotIdentity,
            "fixtureSHA256": receipt.fixtureDigest,
            "fixtureWordCount": receipt.fixtureWordCount,
            "fixtureByteCount": receipt.fixtureByteCount,
            "contentNeutral": true,
            "sameExecutableForAllTrials": true,
            "priorProcessTerminatedBeforeEachTrial": true,
            "freshProcessRelaunchedForEachTrial": true,
            "normalDisposableAccountStore": true,
            "pristineSnapshotResetBeforeEachTrial": true,
            "instrumentsTimeProfileCaptured": true,
            "instrumentsAllocationsCaptured": true,
            "loadDurationsSeconds": [1.0, 1.1, 1.2],
            "editDurationsSeconds": Array(repeating: 0.01, count: 300),
            "mainThreadStallDurationsSeconds": [0.01],
            "scrollMainThreadStallDurationsSeconds": [0.01],
            "allocationSampleMinutes": [1, 2, 3, 4, 5],
            "allocationsLiveBytes": [1, 2, 3, 4, 5],
        ]
    }

    private func assertCompleteLoadEndpoint(
        _ trial: M5LoadTrialResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(trial.fixtureRestored, file: file, line: line)
        XCTAssertTrue(trial.editorAttached, file: file, line: line)
        XCTAssertTrue(trial.readerAttached, file: file, line: line)
        XCTAssertTrue(trial.firstReaderLayoutCompleted, file: file, line: line)
        XCTAssertTrue(trial.syntheticEditAccepted, file: file, line: line)
        XCTAssertTrue(trial.syntheticEditReflectedInReader, file: file, line: line)
        XCTAssertTrue(trial.mainActorSentinelCompleted, file: file, line: line)
        XCTAssertTrue(trial.controllerInteractive, file: file, line: line)
        XCTAssertTrue(trial.measurementEndedAfterSentinel, file: file, line: line)
        XCTAssertTrue(
            trial.restoreIntervalCompletedBeforeMeasurementEnd,
            file: file,
            line: line
        )
        XCTAssertTrue(trial.inProcessRuntimeStopped, file: file, line: line)
        XCTAssertFalse(trial.provesPriorProcessTermination, file: file, line: line)
        XCTAssertEqual(trial.syntheticEditCount, 1, file: file, line: line)
        XCTAssertEqual(trial.openIntervalCount, 0, file: file, line: line)
        XCTAssertFalse(trial.snapshotIdentity.isEmpty, file: file, line: line)
        XCTAssertFalse(trial.executableIdentity.isEmpty, file: file, line: line)
    }

    private func swiftFixture() throws -> Data {
        try M5FiftyThousandWordFixture.makeData(
            wordCount: Self.expectedWordCount,
            lineWidth: 20
        )
    }

    private func makeHarness(
        fixture: Data
    ) throws -> any M5PerformanceHarnessing {
        try M5PerformanceTestHarness(fixture: fixture)
    }

    private func exactEditActions(for fixture: Data) throws -> [M5EditAction] {
        XCTAssertEqual(fixture.count, 499_999)
        let middleToken = Data("word25000".utf8)
        XCTAssertEqual(fixture.subdata(in: 250_000..<250_009), middleToken)
        XCTAssertEqual(Data(fixture.prefix(9)), Data("word00000".utf8))
        XCTAssertEqual(Data(fixture.suffix(9)), Data("word49999".utf8))

        var actions: [M5EditAction] = []
        actions.reserveCapacity(300)
        for _ in 0..<50 {
            XCTAssertEqual(fixture.count, 499_999)
            XCTAssertEqual(fixture.subdata(in: 250_000..<250_009), middleToken)
            actions.append(.insertASCIIX(offset: 0))
            actions.append(.deleteASCIIX(offset: 0))
            actions.append(.insertASCIIX(offset: 250_000))
            actions.append(.deleteASCIIX(offset: 250_000))
            actions.append(.insertASCIIX(offset: 499_999))
            actions.append(.deleteASCIIX(offset: 499_999))
        }
        return actions
    }

    private func nearestRankP95(_ sortedSamples: [Double]) -> Double {
        precondition(!sortedSamples.isEmpty)
        let oneBasedRank = Int(ceil(0.95 * Double(sortedSamples.count)))
        return sortedSamples[oneBasedRank - 1]
    }

    private func ordinaryLeastSquaresSlope(x: [Double], y: [Double]) -> Double {
        precondition(x.count == y.count && !x.isEmpty)
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        let numerator = zip(x, y).reduce(0.0) { partial, pair in
            partial + (pair.0 - meanX) * (pair.1 - meanY)
        }
        let denominator = x.reduce(0.0) { partial, value in
            partial + (value - meanX) * (value - meanX)
        }
        precondition(denominator > 0)
        return numerator / denominator
    }

    private func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func pythonGeneratedFixture() throws -> Data {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("private-presenter-m5-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            repositoryRoot.appendingPathComponent("Scripts/generate-m5-fixture.py").path,
            "--words", "50000",
            "--output", outputURL.path,
        ]
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderr = errorPipe.fileHandleForReading.readDataToEndOfFile()
            throw M5PerformanceContractError.generatorFailed(
                String(decoding: stderr, as: UTF8.self)
            )
        }
        return try Data(contentsOf: outputURL)
    }

    private func requireAbsoluteBaseline() throws {
        guard Self.baselineOptedIn(environment: ProcessInfo.processInfo.environment) else {
            throw XCTSkip(
                "Absolute M5 thresholds require PRIVATE_PRESENTER_M5_BASELINE=1 "
                    + "on the controlled Release/Instruments Mac."
            )
        }
    }

    private static func baselineOptedIn(environment: [String: String]) -> Bool {
        environment[baselineEnvironmentKey] == "1"
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

enum M5EditAction: Equatable, Sendable {
    case insertASCIIX(offset: Int)
    case deleteASCIIX(offset: Int)
}

enum M5LoadEndpointEvent: Equatable, Sendable {
    case snapshotLoadBegan
    case snapshotRestored
    case editorAttached
    case readerAttached
    case firstReaderLayoutCompleted
    case syntheticEditAccepted
    case syntheticEditReflectedInReader
    case mainActorSentinelCompleted
    case measurementEnded
}

enum M5PerformanceEvidenceScope: Equatable, Sendable {
    case inProcessSemanticOnly
    case processFootprintSemanticOnly
    case externalInstruments
}

struct M5PristineSnapshotReceipt: Equatable, Sendable {
    let schemaVersion: Int
    let fixtureWordCount: Int
    let fixtureByteCount: Int
    let fixtureUTF16Count: Int
    let fixtureDigest: String
    let isPaused: Bool
    let isHidden: Bool
    let runtimeDisplayWasCleared: Bool
    let requiresDisplayConfirmation: Bool
    let usedProductionSnapshotStoreImplementation: Bool
    let seedAndFlushCount: Int
    let usedPasteOrImportPath: Bool
    let usedDebugUITestStoreOverride: Bool
    let evidenceScope: M5PerformanceEvidenceScope
    let usedDisposableBaselineAccount: Bool
    let normalApplicationSupportWasEmpty: Bool
    let sourceIdentity: String
    let snapshotIdentity: String
    let executableIdentity: String
}

struct M5LoadTrialResult: Equatable, Sendable {
    let duration: TimeInterval
    let wasMeasured: Bool
    let endpointEvents: [M5LoadEndpointEvent]
    let fixtureRestored: Bool
    let editorAttached: Bool
    let readerAttached: Bool
    let firstReaderLayoutCompleted: Bool
    let syntheticEditAccepted: Bool
    let syntheticEditReflectedInReader: Bool
    let mainActorSentinelCompleted: Bool
    let controllerInteractive: Bool
    let measurementEndedAfterSentinel: Bool
    let restoreIntervalCompletedBeforeMeasurementEnd: Bool
    let inProcessRuntimeStopped: Bool
    let syntheticEditCount: Int
    let openIntervalCount: Int
    let snapshotIdentity: String
    let executableIdentity: String

    var evidenceScope: M5PerformanceEvidenceScope { .inProcessSemanticOnly }
    var provesPriorProcessTermination: Bool { false }
    var provesNormalStoreDisposableAccountReset: Bool { false }
    var provesSameExecutableFreshProcess: Bool { false }
    var provesInstrumentsTimeProfile: Bool { false }
    var provesTwoSecondAbsoluteThreshold: Bool { false }
    var provesAbsoluteLoadBaseline: Bool { false }
}

struct M5EditRunResult: Equatable, Sendable {
    let actionCount: Int
    let acceptedEditCount: Int
    let editToVisibleIntervalCount: Int
    let incrementalReaderMutationCount: Int
    let fullReplacementCountBefore: Int
    let fullReplacementCountAfter: Int
    let resyncCount: Int
    let fixtureWasRestoredAfterEveryPair: Bool
    let finalFixture: Data
    let scheduledCadence: TimeInterval
    let editDurations: [TimeInterval]
    let mainThreadStallDurations: [TimeInterval]
    let mainThreadStallProbeWasActive: Bool
    let reportedNearestRankP95: TimeInterval
    let openIntervalCount: Int
}

struct M5TickProbeResult: Equatable, Sendable {
    let tickCount: Int
    let tickIntervalCount: Int
    let textMutationDelta: Int
    let persistenceEnqueueDelta: Int
    let attributedRebuildDelta: Int
    let swiftUIPublishDelta: Int
    let subsecondCheckpointPublishDelta: Int
    let openTickIntervalCount: Int
    let sessionLeaked: Bool
}

struct M5ScrollMemoryResult: Equatable, Sendable {
    let totalDuration: TimeInterval
    let warmupDuration: TimeInterval
    let measuredDuration: TimeInterval
    let totalSampleTimes: [TimeInterval]
    let measuredSampleTimes: [TimeInterval]
    let processFootprintBytes: [UInt64]
    let provisionalProcessFootprintSlopeMiBPerMinute: Double
    let mainThreadStallDurations: [TimeInterval]
    let mainThreadStallProbeWasActive: Bool
    let sessionCount: Int
    let usedActualDisplayLink: Bool
    let processFootprintBaselineTotalTime: TimeInterval
    let tickCount: Int
    let textMutationDelta: Int
    let persistenceEnqueueDelta: Int
    let attributedRebuildDelta: Int
    let swiftUIPublishDelta: Int
    let openTickIntervalCount: Int
    let sessionLeaked: Bool

    var memoryEvidenceScope: M5PerformanceEvidenceScope { .processFootprintSemanticOnly }
    var provesInstrumentsAllocationSamples: Bool { false }
    var provesAllocationsLiveBytes: Bool { false }
}

struct M5ProcessFootprintDiagnosticResult: Equatable, Sendable {
    let processFootprintBytes: [UInt64]

    var memoryEvidenceScope: M5PerformanceEvidenceScope { .processFootprintSemanticOnly }
    var provesInstrumentsAllocationSamples: Bool { false }
    var provesAllocationsLiveBytes: Bool { false }
}

struct M5DelayedFilesystemResult: Equatable, Sendable {
    let filesystemDelay: TimeInterval
    let editReturnedBeforeFilesystemCompletion: Bool
    let editAwaitedPersistence: Bool
    let mainActorSentinelRanWhileFilesystemWasDelayed: Bool
    let readerReflectedEditBeforeFilesystemCompletion: Bool
    let editToVisibleIntervalCount: Int
    let editToVisibleDuration: TimeInterval
    let finalDocumentRevision: UInt64
    let finalSnapshotRevision: UInt64
    let finalPersistedRevision: UInt64
    let snapshotWriteCount: Int
    let flushCompleted: Bool
    let openIntervalCount: Int
}

@MainActor
protocol M5PerformanceHarnessing: AnyObject {
    var unrecordedWarmupCount: Int { get }
    var recordedCleanLoadCount: Int { get }
    var pristineResetCount: Int { get }

    func preparePristineSnapshot() async throws -> M5PristineSnapshotReceipt
    func resetToPristineSnapshot() async throws
    func runLoadTrial(measured: Bool) async throws -> M5LoadTrialResult
    func runEditSequence(
        actions: [M5EditAction],
        cadence: TimeInterval,
        measuresWallClock: Bool
    ) async throws -> M5EditRunResult
    func runDeterministicTickProbe() async throws -> M5TickProbeResult
    func runSixMinuteScrollSession(
        warmupDuration: TimeInterval,
        measuredDuration: TimeInterval,
        totalSampleTimes: [TimeInterval]
    ) async throws -> M5ScrollMemoryResult
    func runProcessFootprintSemanticProbe(
        sampleCount: Int
    ) async throws -> M5ProcessFootprintDiagnosticResult
    func runDelayedFilesystemEdit(
        delay: TimeInterval
    ) async throws -> M5DelayedFilesystemResult
}

struct M5ExternalInstrumentsRecord: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let recordKind: String
    let sourceSHA: String
    let executableSHA256: String
    let pristineSnapshotSHA256: String
    let fixtureSHA256: String
    let fixtureWordCount: Int
    let fixtureByteCount: Int
    let contentNeutral: Bool
    let sameExecutableForAllTrials: Bool
    let priorProcessTerminatedBeforeEachTrial: Bool
    let freshProcessRelaunchedForEachTrial: Bool
    let normalDisposableAccountStore: Bool
    let pristineSnapshotResetBeforeEachTrial: Bool
    let instrumentsTimeProfileCaptured: Bool
    let instrumentsAllocationsCaptured: Bool
    let loadDurationsSeconds: [Double]
    let editDurationsSeconds: [Double]
    let mainThreadStallDurationsSeconds: [Double]
    let scrollMainThreadStallDurationsSeconds: [Double]
    let allocationSampleMinutes: [Int]
    let allocationsLiveBytes: [UInt64]
}

enum M5AbsolutePerformanceEvidenceError: Error, Equatable, CustomStringConvertible {
    case semanticLoadTrialCannotProveAbsoluteBaseline
    case processFootprintCannotProveAllocations
    case externalRecordPathMissing
    case sourceSHAMissing
    case externalRecordUnreadable
    case externalRecordShapeMismatch
    case externalRecordIdentityMismatch
    case externalRecordProtocolMismatch
    case externalRecordSamplesInvalid

    var description: String {
        switch self {
        case .semanticLoadTrialCannotProveAbsoluteBaseline:
            "An in-process temporary-store AppRuntime trial is semantic-only. Supply the "
                + "external same-executable fresh-process Instruments record."
        case .processFootprintCannotProveAllocations:
            "processFootprintBytes is a provisional diagnostic, not Instruments "
                + "Allocations live bytes."
        case .externalRecordPathMissing:
            "PRIVATE_PRESENTER_M5_EXTERNAL_INSTRUMENTS_RECORD must name the content-neutral "
                + "controlled-Mac JSON record."
        case .sourceSHAMissing:
            "PRIVATE_PRESENTER_M5_SOURCE_SHA must be the exact 40-character source SHA."
        case .externalRecordUnreadable:
            "The external Instruments JSON record could not be read or decoded."
        case .externalRecordShapeMismatch:
            "The external record has missing or extra fields; private/raw trace fields are "
                + "not accepted."
        case .externalRecordIdentityMismatch:
            "The external record does not match the exact source, executable, fixture, and "
                + "pristine snapshot identities."
        case .externalRecordProtocolMismatch:
            "The external record does not attest the approved fresh-process, normal-store, "
                + "same-executable Time Profiler and Allocations protocol."
        case .externalRecordSamplesInvalid:
            "The external record lacks the required real load/edit/stall/Allocations samples."
        }
    }
}

enum M5AbsolutePerformanceEvidenceGate {
    static let recordEnvironmentKey = "PRIVATE_PRESENTER_M5_EXTERNAL_INSTRUMENTS_RECORD"
    static let sourceSHAEnvironmentKey = "PRIVATE_PRESENTER_M5_SOURCE_SHA"

    private static let exactRecordKeys: Set<String> = [
        "schemaVersion", "recordKind", "sourceSHA", "executableSHA256",
        "pristineSnapshotSHA256", "fixtureSHA256", "fixtureWordCount",
        "fixtureByteCount", "contentNeutral", "sameExecutableForAllTrials",
        "priorProcessTerminatedBeforeEachTrial", "freshProcessRelaunchedForEachTrial",
        "normalDisposableAccountStore", "pristineSnapshotResetBeforeEachTrial",
        "instrumentsTimeProfileCaptured", "instrumentsAllocationsCaptured",
        "loadDurationsSeconds", "editDurationsSeconds",
        "mainThreadStallDurationsSeconds", "scrollMainThreadStallDurationsSeconds",
        "allocationSampleMinutes", "allocationsLiveBytes",
    ]

    static func requireExternalFreshProcessInstrumentsLoadRecord(
        for trial: M5LoadTrialResult
    ) throws {
        guard trial.evidenceScope == .externalInstruments else {
            throw M5AbsolutePerformanceEvidenceError
                .semanticLoadTrialCannotProveAbsoluteBaseline
        }
    }

    static func requireExternalInstrumentsAllocationsRecord(
        for result: M5ProcessFootprintDiagnosticResult
    ) throws {
        guard result.memoryEvidenceScope == .externalInstruments else {
            throw M5AbsolutePerformanceEvidenceError.processFootprintCannotProveAllocations
        }
    }

    static func loadValidatedExternalRecord(
        expected receipt: M5PristineSnapshotReceipt,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> M5ExternalInstrumentsRecord {
        guard let path = environment[recordEnvironmentKey], path.hasPrefix("/") else {
            throw M5AbsolutePerformanceEvidenceError.externalRecordPathMissing
        }
        guard let sourceSHA = environment[sourceSHAEnvironmentKey],
            isLowercaseHex(sourceSHA, count: 40)
        else {
            throw M5AbsolutePerformanceEvidenceError.sourceSHAMissing
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw M5AbsolutePerformanceEvidenceError.externalRecordUnreadable
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any],
            Set(dictionary.keys) == exactRecordKeys,
            dictionary["phys_footprint"] == nil,
            dictionary["processFootprintBytes"] == nil
        else {
            throw M5AbsolutePerformanceEvidenceError.externalRecordShapeMismatch
        }
        let record: M5ExternalInstrumentsRecord
        do {
            record = try JSONDecoder().decode(M5ExternalInstrumentsRecord.self, from: data)
        } catch {
            throw M5AbsolutePerformanceEvidenceError.externalRecordUnreadable
        }

        guard
            record.sourceSHA == sourceSHA,
            record.sourceSHA == receipt.sourceIdentity,
            record.executableSHA256 == receipt.executableIdentity,
            record.pristineSnapshotSHA256 == receipt.snapshotIdentity,
            record.fixtureSHA256 == receipt.fixtureDigest,
            record.fixtureWordCount == receipt.fixtureWordCount,
            record.fixtureByteCount == receipt.fixtureByteCount,
            isLowercaseHex(record.executableSHA256, count: 64),
            isLowercaseHex(record.pristineSnapshotSHA256, count: 64),
            isLowercaseHex(record.fixtureSHA256, count: 64)
        else {
            throw M5AbsolutePerformanceEvidenceError.externalRecordIdentityMismatch
        }
        guard
            record.schemaVersion == 1,
            record.recordKind == "private-presenter-m5-external-instruments",
            record.contentNeutral,
            record.sameExecutableForAllTrials,
            record.priorProcessTerminatedBeforeEachTrial,
            record.freshProcessRelaunchedForEachTrial,
            record.normalDisposableAccountStore,
            record.pristineSnapshotResetBeforeEachTrial,
            record.instrumentsTimeProfileCaptured,
            record.instrumentsAllocationsCaptured
        else {
            throw M5AbsolutePerformanceEvidenceError.externalRecordProtocolMismatch
        }
        guard
            record.loadDurationsSeconds.count == 3,
            record.editDurationsSeconds.count == 300,
            !record.mainThreadStallDurationsSeconds.isEmpty,
            !record.scrollMainThreadStallDurationsSeconds.isEmpty,
            record.allocationSampleMinutes == [1, 2, 3, 4, 5],
            record.allocationsLiveBytes.count == 5,
            record.allocationsLiveBytes.allSatisfy({ $0 > 0 }),
            allPositiveFinite(record.loadDurationsSeconds),
            allNonnegativeFinite(record.editDurationsSeconds),
            allNonnegativeFinite(record.mainThreadStallDurationsSeconds),
            allNonnegativeFinite(record.scrollMainThreadStallDurationsSeconds)
        else {
            throw M5AbsolutePerformanceEvidenceError.externalRecordSamplesInvalid
        }
        return record
    }

    private static func isLowercaseHex(_ value: String, count: Int) -> Bool {
        value.count == count
            && value.unicodeScalars.allSatisfy { scalar in
                (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
            }
    }

    private static func allPositiveFinite(_ samples: [Double]) -> Bool {
        samples.allSatisfy { $0.isFinite && $0 > 0 }
    }

    private static func allNonnegativeFinite(_ samples: [Double]) -> Bool {
        samples.allSatisfy { $0.isFinite && $0 >= 0 }
    }
}

private enum M5PerformanceContractError: Error {
    case generatorFailed(String)
}
