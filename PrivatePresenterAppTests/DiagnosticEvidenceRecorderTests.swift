#if DEBUG
import Foundation
import XCTest
@testable import PrivatePresenter

final class DiagnosticEvidenceRecorderTests: XCTestCase {
    func testEvidenceEnvelopeCarriesSessionCorrelationSourceTimeSequenceAndFixedKind() async {
        let correlationID = UUID()
        let harness = makeDiagnosticRecorderHarness(clock: { 42 })

        XCTAssertTrue(harness.recorder.record(kind: .carbonReceived, correlationID: correlationID))
        XCTAssertTrue(await harness.recorder.finish())

        let event = harness.sink.envelopes.first { $0.kind == .carbonReceived }
        XCTAssertEqual(event?.sessionID, harness.recorder.sessionID)
        XCTAssertEqual(event?.correlationID, correlationID)
        XCTAssertEqual(event?.sourceMonotonicNanoseconds, 42)
        XCTAssertNotNil(event?.sequence)
        XCTAssertEqual(event?.kind, .carbonReceived)
    }

    @MainActor
    func testCarbonReceiptIsStampedBeforeMainDispatchForSameCorrelation() async {
        let harness = makeDiagnosticRecorderHarness()
        let mainDispatch = expectation(description: "main dispatch")
        let service = DiagnosticHotKeyService(
            carbonReceipt: { correlationID in
                harness.recorder.record(kind: .carbonReceived, correlationID: correlationID)
            },
            action: { correlationID in
                harness.recorder.record(kind: .mainDispatchBegan, correlationID: correlationID)
                mainDispatch.fulfill()
            }
        )

        service.receiveCarbonEventForTesting()
        await fulfillment(of: [mainDispatch], timeout: 2)
        _ = await harness.recorder.finish()

        let carbonEvent = try! XCTUnwrap(
            harness.sink.envelopes.first { $0.kind == .carbonReceived }
        )
        let correlationID = try! XCTUnwrap(carbonEvent.correlationID)
        let events = harness.sink.envelopes.filter { $0.correlationID == correlationID }
        XCTAssertEqual(events.map(\.kind), [.carbonReceived, .mainDispatchBegan])
        XCTAssertTrue(zip(events, events.dropFirst()).allSatisfy { $0.sequence < $1.sequence })
    }

    func testCorrelatedEventsRetainStrictRecorderOrderAcrossDelayedSamples() async {
        let correlationID = UUID()
        let harness = makeDiagnosticRecorderHarness()
        let kinds: [DiagnosticEventKind] = [
            .focusImmediate,
            .focusNextMainRunLoop,
            .focusDelayed100Milliseconds,
            .focusDelayed500Milliseconds,
            .correlationWindowClosed,
        ]
        kinds.forEach { harness.recorder.record(kind: $0, correlationID: correlationID) }
        _ = await harness.recorder.finish()

        let events = harness.sink.envelopes.filter { $0.correlationID == correlationID }
        XCTAssertEqual(events.map(\.kind), kinds)
        XCTAssertEqual(events.map(\.sequence), events.map(\.sequence).sorted())
    }

    func testEvidenceUsesLocalApplicationSupportValidationDirectory() {
        XCTAssertEqual(DiagnosticEvidenceRecorder.directoryName, "Private Presenter")
        XCTAssertEqual(DiagnosticEvidenceRecorder.validationDirectoryName, "Validation")
        XCTAssertEqual(DiagnosticEvidenceRecorder.filename, "overlay-diagnostics.txt")
    }

    func testEvidenceAppendDoesNotEraseEarlierEvents() async {
        let harness = makeDiagnosticRecorderHarness()
        harness.recorder.record(kind: .commandBefore)
        harness.recorder.record(kind: .commandAfter)
        _ = await harness.recorder.finish()

        let kinds = harness.sink.envelopes.map(\.kind)
        XCTAssertLessThan(
            try! XCTUnwrap(kinds.firstIndex(of: .commandBefore)),
            try! XCTUnwrap(kinds.firstIndex(of: .commandAfter))
        )
    }

    func testEvidenceWriterNeverPerformsFileIOOnHotKeyOrMainCriticalPath() {
        let harness = makeDiagnosticRecorderHarness(blocksFirstAppend: true)
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())

        let acceptedWhileWriterWasBlocked = harness.recorder.record(kind: .carbonReceived)

        XCTAssertTrue(acceptedWhileWriterWasBlocked)
        harness.sink.unblockFirstAppend()
    }

    func testEvidenceAndFixedErrorsNeverContainScriptTitleContextOrRawEnvironment() async {
        let sentinel = "PRIVATE-SCRIPT-TITLE-CONTEXT"
        let resolution = DiagnosticProofConfiguration.resolve(environment: [
            "PRIVATE_PRESENTER_EVIDENCE_COMMIT": sentinel,
            "PRIVATE_PRESENTER_PROOF_LEVEL": sentinel,
            "PRIVATE_PRESENTER_ORDERING": sentinel,
            "PRIVATE_PRESENTER_CONTROLLER_COHORT": sentinel,
            "PRIVATE_PRESENTER_REPETITION": sentinel,
            "PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256": sentinel,
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG": sentinel,
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256": sentinel,
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST": sentinel,
        ])
        let harness = makeDiagnosticRecorderHarness(configuration: resolution.configuration)
        resolution.faults.forEach(harness.recorder.invalidate)
        _ = await harness.recorder.finish()

        let encoded = try! JSONEncoder().encode(harness.sink.envelopes)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(sentinel))
    }

    @MainActor
    func testRecorderFailureDoesNotBlockPrivacyOrHotKeyDispatch() async {
        let harness = makeDiagnosticRecorderHarness(failure: .append)
        let runtime = AppRuntime(
            diagnosticConfiguration: harness.recorder.configuration,
            diagnosticEvidenceRecorder: harness.recorder,
            enforcesDiagnosticControllerCohort: false,
            startupSeams: AppRuntimeStartupSeams(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 }
            )
        )
        await runtime.startForTesting()

        let beforeHotKey = runtime.model.commandDispatchCount
        runtime.diagnosticHotKeyService.invokeForTesting()
        XCTAssertEqual(runtime.model.commandDispatchCount, beforeHotKey + 1)

        let beforePrivacy = runtime.model.commandDispatchCount
        runtime.model.send(.topologyWillChange)
        XCTAssertEqual(runtime.model.commandDispatchCount, beforePrivacy + 1)
        XCTAssertEqual(runtime.model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(runtime.model.overlaySession.visibility, .hidden)
        XCTAssertTrue(runtime.model.isShielded)

        _ = await runtime.stopAndFlush()
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceAppendFailed))
    }

    @MainActor
    func testRecorderFailurePermanentlyInvalidatesCellWhileActionsContinue() {
        let harness = makeDiagnosticRecorderHarness()
        harness.recorder.invalidate(.evidenceAppendFailed)
        let coordinator = PrivacyCoordinator()
        let model = AppModel(
            overlayController: OverlayPanelController(),
            privacyCoordinator: coordinator,
            diagnosticEvidenceRecorder: harness.recorder
        )
        let commandCount = model.commandDispatchCount
        model.send(.topologyWillChange)

        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceAppendFailed))
        XCTAssertEqual(model.commandDispatchCount, commandCount + 1)
        XCTAssertEqual(coordinator.lastDirectives.first, .pauseScrolling)
        XCTAssertEqual(coordinator.lastDirectives.last, .requestConfirmation)
    }

    func testSessionCompletionRequiresResolvedPathExistingFileAndSuccessfulFlush() async {
        let harness = makeDiagnosticRecorderHarness()

        XCTAssertTrue(await harness.recorder.finish())

        let finalURL = try! XCTUnwrap(harness.recorder.finalURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertEqual(Array(harness.sink.operations.suffix(3)), ["synchronize", "close", "publish"])
        XCTAssertEqual(harness.sink.envelopes.last?.kind, .sessionCompletion)
    }

    func testEvidenceHeaderBindsFullCommitLevelAndOrdering() async {
        let configuration = makeDiagnosticConfiguration(level: .floating, ordering: .front)
        let harness = makeDiagnosticRecorderHarness(configuration: configuration)
        _ = await harness.recorder.finish()

        let header = harness.sink.envelopes.first
        XCTAssertEqual(header?.kind, .configurationBound)
        XCTAssertEqual(header?.payload.configuration?.implementationCommit.count, 40)
        XCTAssertEqual(header?.payload.configuration?.proofLevel, .floating)
        XCTAssertEqual(header?.payload.configuration?.ordering, .front)
    }

    func testQueueSaturationAtomicallyInvalidatesCellWithoutDelayingHotKeyOrPrivacy() {
        let harness = makeDiagnosticRecorderHarness(capacity: 1, blocksFirstAppend: true)
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())
        XCTAssertTrue(harness.recorder.record(kind: .carbonReceived))

        let accepted = harness.recorder.record(kind: .commandBefore)

        XCTAssertFalse(accepted)
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
        harness.sink.unblockFirstAppend()
    }

    func testQueueOverflowEmitsFixedFaultWhenCapacityReturns() async {
        let harness = saturatedHarness()
        harness.sink.unblockFirstAppend()
        XCTAssertTrue(harness.sink.waitForAppendCount(3))
        _ = await harness.recorder.finish()

        let fault = harness.sink.envelopes.first { $0.kind == .recorderFault }
        XCTAssertEqual(fault?.payload.faultCode, .evidenceQueueOverflow)
        let sequences = harness.sink.envelopes.map(\.sequence)
        XCTAssertEqual(sequences, sequences.sorted())
    }

    func testQueueOverflowCannotBecomeValidAfterSuccessfulFlush() async {
        let harness = saturatedHarness()
        harness.sink.unblockFirstAppend()
        XCTAssertTrue(harness.sink.waitForAppendCount(3))

        XCTAssertTrue(await harness.recorder.finish())
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
    }

    func testBoundedIngressRejectsNewestEnvelopeAtCapacityWithoutWaiting() {
        let harness = makeDiagnosticRecorderHarness(capacity: 1, blocksFirstAppend: true)
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())
        XCTAssertTrue(harness.recorder.record(kind: .commandBefore))

        XCTAssertFalse(harness.recorder.record(kind: .commandAfter))
        harness.sink.unblockFirstAppend()
    }

    func testQueueOverflowInvalidationDoesNotRequireFaultEnvelopeCapacity() {
        let harness = makeDiagnosticRecorderHarness(capacity: 1, blocksFirstAppend: true)
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())
        XCTAssertTrue(harness.recorder.record(kind: .commandBefore))
        XCTAssertFalse(harness.recorder.record(kind: .commandAfter))

        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
        harness.sink.unblockFirstAppend()
    }

    func testOverflowFaultIsEmittedOnceAfterWriterCapacityReturns() async {
        let harness = saturatedHarness(extraDrops: 3)
        harness.sink.unblockFirstAppend()
        XCTAssertTrue(harness.sink.waitForAppendCount(3))
        _ = await harness.recorder.finish()

        let faults = harness.sink.envelopes.filter {
            $0.kind == .recorderFault && $0.payload.faultCode == .evidenceQueueOverflow
        }
        XCTAssertEqual(faults.count, 1)
    }

    @MainActor
    func testHotKeyDispatchContinuesWhileEvidenceQueueIsSaturated() async {
        let harness = saturatedHarness()
        let runtime = AppRuntime(
            diagnosticConfiguration: harness.recorder.configuration,
            diagnosticEvidenceRecorder: harness.recorder,
            enforcesDiagnosticControllerCohort: false,
            startupSeams: AppRuntimeStartupSeams(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 }
            )
        )
        await runtime.startForTesting()
        let commandCount = runtime.model.commandDispatchCount

        runtime.diagnosticHotKeyService.invokeForTesting()

        XCTAssertEqual(runtime.model.commandDispatchCount, commandCount + 1)
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
        harness.sink.unblockFirstAppend()
        _ = await runtime.stopAndFlush()
    }

    @MainActor
    func testPrivacyDirectivesContinueInOrderWhileEvidenceQueueIsSaturated() async {
        let harness = saturatedHarness()
        let coordinator = PrivacyCoordinator()
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            privacyCoordinator: coordinator,
            diagnosticEvidenceRecorder: harness.recorder,
            effectHandler: { effects.append($0) }
        )
        let commandCount = model.commandDispatchCount

        model.send(.topologyWillChange)

        XCTAssertEqual(model.commandDispatchCount, commandCount + 1)
        XCTAssertEqual(
            coordinator.lastDirectives,
            [
                .pauseScrolling,
                .hideOverlay,
                .shieldController,
                .invalidatePendingShow,
                .queryTopology,
                .evaluatePrivacy,
                .requestConfirmation,
            ]
        )
        XCTAssertEqual(effects, [.hidePanel, .queryTopology, .evaluatePrivacy])
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertTrue(model.isShielded)
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
        harness.sink.unblockFirstAppend()
        XCTAssertTrue(await harness.recorder.finish())
    }

    func testOverflowAndLaterSinkFailurePreserveFirstPermanentInvalidation() async {
        let harness = makeDiagnosticRecorderHarness(
            capacity: 1,
            failure: .synchronize,
            blocksFirstAppend: true
        )
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())
        XCTAssertTrue(harness.recorder.record(kind: .commandBefore))
        XCTAssertFalse(harness.recorder.record(kind: .commandAfter))
        harness.sink.unblockFirstAppend()
        XCTAssertTrue(harness.sink.waitForAppendCount(3))
        _ = await harness.recorder.finish()

        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceQueueOverflow))
    }

    func testConfigurationBoundIncludesControllerCohortAndRepetition() async {
        let configuration = makeDiagnosticConfiguration(cohort: .visibleDesktopSpace, repetition: "3")
        let harness = makeDiagnosticRecorderHarness(configuration: configuration)
        _ = await harness.recorder.finish()

        let header = harness.sink.envelopes.first?.payload.configuration
        XCTAssertEqual(header?.declaredControllerCohort, .visibleDesktopSpace)
        XCTAssertEqual(header?.repetition, "3")
    }

    func testOnlyRepetitionsOneThroughThreeAreAccepted() {
        for repetition in ["1", "2", "3"] {
            let resolution = resolution(repetition: repetition)
            XCTAssertFalse(resolution.faults.contains(.configRepetitionInvalid))
        }
        for repetition in ["0", "4", "01", "１"] {
            let resolution = resolution(repetition: repetition)
            XCTAssertTrue(resolution.faults.contains(.configRepetitionInvalid))
        }
    }

    func testInvalidRepetitionUsesFixedCodeWithoutEchoingInput() throws {
        let sentinel = "PRIVATE-REPETITION-SENTINEL"
        let result = resolution(repetition: sentinel)

        XCTAssertTrue(result.faults.contains(.configRepetitionInvalid))
        XCTAssertFalse(
            String(decoding: try JSONEncoder().encode(result.configuration), as: UTF8.self)
                .contains(sentinel)
        )
    }

    func testConfigurationBoundIncludesExecutableSHA256AndBuildLogPathAndHash() async {
        let configuration = makeDiagnosticConfiguration()
        let harness = makeDiagnosticRecorderHarness(configuration: configuration)
        _ = await harness.recorder.finish()

        let header = harness.sink.envelopes.first?.payload.configuration
        XCTAssertEqual(header?.executableSHA256, configuration.executableSHA256)
        XCTAssertEqual(header?.buildLogPath, configuration.buildLogPath)
        XCTAssertEqual(header?.buildLogSHA256, configuration.buildLogSHA256)
        XCTAssertEqual(header?.buildManifestPath, configuration.buildManifestPath)
    }

    func testExecutableHashRequiresSixtyFourLowercaseHexCharacters() {
        let invalid = [String(repeating: "a", count: 63), String(repeating: "A", count: 64), "not-hex"]

        for value in invalid {
            XCTAssertTrue(resolution(executableHash: value).faults.contains(.configExecutableHashInvalid))
        }
    }

    func testInvalidExecutableHashUsesFixedCodeWithoutEchoingInput() throws {
        let sentinel = "PRIVATE-EXECUTABLE-HASH-SENTINEL"
        let result = resolution(executableHash: sentinel)

        XCTAssertTrue(result.faults.contains(.configExecutableHashInvalid))
        XCTAssertFalse(
            String(decoding: try JSONEncoder().encode(result.configuration), as: UTF8.self)
                .contains(sentinel)
        )
    }

    func testInvalidBuildLogHashUsesFixedCodeWithoutEchoingInput() throws {
        let sentinel = "PRIVATE-BUILD-LOG-HASH-SENTINEL"
        let result = resolution(buildLogHash: sentinel)

        XCTAssertTrue(result.faults.contains(.configBuildLogHashInvalid))
        XCTAssertFalse(
            String(decoding: try JSONEncoder().encode(result.configuration), as: UTF8.self)
                .contains(sentinel)
        )
    }

    func testEvidenceWritesOnlyToSiblingPendingPathBeforeCompletion() {
        let harness = makeDiagnosticRecorderHarness()

        XCTAssertEqual(harness.recorder.pendingURL?.deletingPathExtension(), harness.recorder.finalURL)
        XCTAssertEqual(harness.recorder.pendingURL?.pathExtension, "pending")
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.recorder.finalURL!.path))
    }

    func testSessionCompletionIsLastSerializedEventBeforeSynchronization() async {
        let harness = makeDiagnosticRecorderHarness()
        harness.recorder.record(kind: .commandAfter)
        _ = await harness.recorder.finish()

        XCTAssertEqual(harness.sink.envelopes.last?.kind, .sessionCompletion)
        let lastAppend = try! XCTUnwrap(harness.sink.operations.lastIndex(of: "append"))
        let synchronize = try! XCTUnwrap(harness.sink.operations.firstIndex(of: "synchronize"))
        XCTAssertLessThan(lastAppend, synchronize)
    }

    func testSynchronizationAndClosePrecedeAtomicFinalRename() async {
        let harness = makeDiagnosticRecorderHarness()
        _ = await harness.recorder.finish()

        XCTAssertEqual(Array(harness.sink.operations.suffix(3)), ["synchronize", "close", "publish"])
    }

    func testFinalPathAppearsOnlyAfterAtomicRename() async {
        let harness = makeDiagnosticRecorderHarness()
        let finalURL = harness.recorder.finalURL!
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))

        _ = await harness.recorder.finish()

        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
    }

    func testSynchronizationFailureNeverPublishesFinalEvidenceFile() async {
        let harness = makeDiagnosticRecorderHarness(failure: .synchronize)

        XCTAssertFalse(await harness.recorder.finish())
        XCTAssertFalse(harness.sink.operations.contains("publish"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.recorder.finalURL!.path))
    }

    func testCloseFailureNeverPublishesFinalEvidenceFile() async {
        let harness = makeDiagnosticRecorderHarness(failure: .close)

        XCTAssertFalse(await harness.recorder.finish())
        XCTAssertFalse(harness.sink.operations.contains("publish"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.recorder.finalURL!.path))
    }

    func testAtomicRenameFailureNeverPublishesAcceptedFinalFile() async {
        let harness = makeDiagnosticRecorderHarness(failure: .publish)

        XCTAssertFalse(await harness.recorder.finish())
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.recorder.finalURL!.path))
        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceFinalizeFailed))
    }

    func testPendingFileIsNeverAcceptedAsProof() async {
        let harness = makeDiagnosticRecorderHarness(failure: .synchronize)
        _ = await harness.recorder.finish()

        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.recorder.pendingURL!.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.recorder.finalURL!.path))
        XCTAssertNotEqual(harness.recorder.proofStatus, .valid)
    }

    func testFinalizationFailurePermanentlyInvalidatesCell() async {
        let harness = makeDiagnosticRecorderHarness(failure: .close)
        _ = await harness.recorder.finish()

        XCTAssertEqual(harness.recorder.proofStatus, .invalid(.evidenceCloseFailed))
    }

    private func saturatedHarness(extraDrops: Int = 0) -> DiagnosticRecorderHarness {
        let harness = makeDiagnosticRecorderHarness(capacity: 1, blocksFirstAppend: true)
        XCTAssertTrue(harness.sink.waitUntilFirstAppendStarts())
        XCTAssertTrue(harness.recorder.record(kind: .commandBefore))
        XCTAssertFalse(harness.recorder.record(kind: .commandAfter))
        for _ in 0 ..< extraDrops {
            XCTAssertFalse(harness.recorder.record(kind: .effectEmitted))
        }
        return harness
    }

    private func resolution(
        repetition: String = "1",
        executableHash: String = String(repeating: "b", count: 64),
        buildLogHash: String = String(repeating: "c", count: 64)
    ) -> DiagnosticConfigurationResolution {
        DiagnosticProofConfiguration.resolve(environment: [
            "PRIVATE_PRESENTER_EVIDENCE_COMMIT": String(repeating: "a", count: 40),
            "PRIVATE_PRESENTER_PROOF_LEVEL": "statusBar",
            "PRIVATE_PRESENTER_ORDERING": "frontRegardless",
            "PRIVATE_PRESENTER_CONTROLLER_COHORT": "orderedOut",
            "PRIVATE_PRESENTER_REPETITION": repetition,
            "PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256": executableHash,
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG": "/tmp/private-presenter-generated-proof-build.log",
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256": buildLogHash,
            "PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST": "/tmp/private-presenter-generated-proof-manifest.txt",
        ])
    }
}
#endif
