#if DEBUG
import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class DiagnosticHotKeyServiceTests: XCTestCase {
    func testControlOptionHRetainsVisibilityAction() {
        var invocationCount = 0
        let service = DiagnosticHotKeyService { invocationCount += 1 }

        service.invokeForTesting()

        XCTAssertEqual(DiagnosticHotKeyService.chordDescription, "Control-Option-H")
        XCTAssertEqual(invocationCount, 1)
    }

    func testObserversInstallBeforeVisibilityHotKeyAndTearDownAfterUnregistration() async {
        var lifecycle: [AppRuntimeDiagnosticLifecycleEvent] = []
        let runtime = AppRuntime(
            proofLevel: .floating,
            startupSeams: AppRuntimeStartupSeams(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 },
                recordDiagnosticLifecycle: { lifecycle.append($0) }
            )
        )

        await runtime.startForTesting()
        _ = await runtime.stopAndFlush()

        XCTAssertEqual(
            lifecycle,
            [
                .installObservers,
                .registerHotKey,
                .unregisterHotKey,
                .drainCorrelations,
                .tearDownObservers,
                .finalizeEvidence,
            ]
        )
    }

    func testControllerCohortMismatchPermanentlyInvalidatesCellBeforeFirstHotKey() async {
        let evidence = makeDiagnosticRecorderHarness(
            configuration: makeDiagnosticConfiguration(cohort: .orderedOut)
        )
        let runtime = AppRuntime(
            proofLevel: .statusBar,
            diagnosticConfiguration: evidence.recorder.configuration,
            diagnosticEvidenceRecorder: evidence.recorder,
            startupSeams: AppRuntimeStartupSeams(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 }
            )
        )
        await runtime.startForTesting()
        let commandCount = runtime.model.commandDispatchCount

        runtime.diagnosticHotKeyService.invokeForTesting()

        XCTAssertEqual(
            evidence.recorder.proofStatus,
            .invalid(.controllerCohortMismatch)
        )
        XCTAssertEqual(runtime.model.commandDispatchCount, commandCount)
        _ = await runtime.stopAndFlush()
    }

    func testConfigurationBoundPrecedesCorrelatedCarbonReceipt() async {
        let evidence = makeDiagnosticRecorderHarness()
        let mainDispatch = expectation(description: "main dispatch")
        let service = DiagnosticHotKeyService(
            carbonReceipt: { correlationID in
                evidence.recorder.record(kind: .carbonReceived, correlationID: correlationID)
            },
            action: { correlationID in
                evidence.recorder.record(kind: .mainDispatchBegan, correlationID: correlationID)
                mainDispatch.fulfill()
            }
        )

        service.receiveCarbonEventForTesting()
        await fulfillment(of: [mainDispatch], timeout: 2)
        _ = await evidence.recorder.finish()

        let envelopes = evidence.sink.envelopes
        XCTAssertEqual(envelopes.first?.kind, .configurationBound)
        let carbonEvent = try! XCTUnwrap(envelopes.first { $0.kind == .carbonReceived })
        let correlationID = try! XCTUnwrap(carbonEvent.correlationID)
        XCTAssertLessThan(
            try! XCTUnwrap(envelopes.firstIndex { $0.kind == .configurationBound }),
            try! XCTUnwrap(envelopes.firstIndex {
                $0.kind == .carbonReceived && $0.correlationID == correlationID
            })
        )
        XCTAssertLessThan(
            try! XCTUnwrap(envelopes.firstIndex {
                $0.kind == .carbonReceived && $0.correlationID == correlationID
            }),
            try! XCTUnwrap(envelopes.firstIndex {
                $0.kind == .mainDispatchBegan && $0.correlationID == correlationID
            })
        )
    }

    func testNormalQuitWaitsForAllCorrelatedSamplesBeforeCompletion() async {
        let evidence = makeDiagnosticRecorderHarness(
            configuration: makeDiagnosticConfiguration(cohort: .visibleDesktopSpace)
        )
        var lifecycle: [AppRuntimeDiagnosticLifecycleEvent] = []
        let runtime = AppRuntime(
            proofLevel: .statusBar,
            diagnosticConfiguration: evidence.recorder.configuration,
            diagnosticEvidenceRecorder: evidence.recorder,
            startupSeams: AppRuntimeStartupSeams(
                load: { .notFound },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 },
                recordDiagnosticLifecycle: { lifecycle.append($0) }
            )
        )
        await runtime.startForTesting()
        runtime.diagnosticHotKeyService.invokeForTesting()

        _ = await runtime.stopAndFlush()

        XCTAssertEqual(runtime.diagnosticObserverSet?.activeCorrelationCount, 0)
        XCTAssertLessThan(
            try! XCTUnwrap(lifecycle.firstIndex(of: .drainCorrelations)),
            try! XCTUnwrap(lifecycle.firstIndex(of: .tearDownObservers))
        )
        XCTAssertLessThan(
            try! XCTUnwrap(evidence.sink.envelopes.lastIndex {
                $0.kind == .correlationWindowClosed
            }),
            try! XCTUnwrap(evidence.sink.envelopes.lastIndex { $0.kind == .sessionCompletion })
        )
    }
}
#endif
