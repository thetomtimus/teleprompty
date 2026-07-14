#if DEBUG
import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class DiagnosticHotKeyServiceTests: XCTestCase {
    func testControlOptionHRetainsVisibilityAction() {
        var invocations: [DiagnosticHotKeyAction] = []
        let service = DiagnosticHotKeyService { invocations.append($0) }

        service.invokeForTesting()

        XCTAssertEqual(DiagnosticHotKeyService.visibilityChordDescription, "Control-Option-H")
        XCTAssertEqual(invocations, [.visibility])
    }

    func testControlOptionLDispatchesDistinctLockAction() {
        var invocations: [DiagnosticHotKeyAction] = []
        let service = DiagnosticHotKeyService { invocations.append($0) }

        service.invokeForTesting(.lock)

        XCTAssertEqual(DiagnosticHotKeyService.lockChordDescription, "Control-Option-L")
        XCTAssertEqual(invocations, [.lock])
    }

    func testCarbonIdentifiersDecodeToDistinctActions() {
        let service = DiagnosticHotKeyService { _ in }
        let signature: OSType = 0x5050_5452

        XCTAssertEqual(service.decodeForTesting(id: 1, signature: signature), .visibility)
        XCTAssertEqual(service.decodeForTesting(id: 2, signature: signature), .lock)
        XCTAssertNil(service.decodeForTesting(id: 3, signature: signature))
        XCTAssertNil(service.decodeForTesting(id: 1, signature: 0))
    }

    func testRegistrationFailureCleansUpBothHotKeys() {
        var unregistered: [DiagnosticHotKeyAction] = []
        let service = DiagnosticHotKeyService(
            action: { _ in },
            registrationOverride: { action in
                action == .visibility ? noErr : OSStatus(-1)
            },
            unregistrationObserver: { unregistered.append($0) }
        )

        let status = service.register()

        XCTAssertEqual(status.visibility, noErr)
        XCTAssertNotEqual(status.lock, noErr)
        XCTAssertEqual(service.registeredActionCount, 0)
        XCTAssertEqual(unregistered, [.visibility])
    }

    func testSuccessfulTerminationUnregistersBothDiagnosticChords() {
        var unregistered: Set<DiagnosticHotKeyAction> = []
        let service = DiagnosticHotKeyService(
            action: { _ in },
            registrationOverride: { _ in noErr },
            unregistrationObserver: { unregistered.insert($0) }
        )
        XCTAssertTrue(service.register().allRegistered)

        service.unregister()

        XCTAssertEqual(unregistered, Set(DiagnosticHotKeyAction.allCases))
        XCTAssertEqual(service.registeredActionCount, 0)
    }

    func testBothRegistrationFailuresInvalidatePhysicalPrecondition() async {
        let failures: [DiagnosticHotKeyRegistrationStatus] = [
            .init(visibility: -1, lock: noErr),
            .init(visibility: noErr, lock: -1),
        ]

        for status in failures {
            let evidence = makeDiagnosticRecorderHarness()
            let runtime = AppRuntime(
                proofLevel: .floating,
                diagnosticEvidenceRecorder: evidence.recorder,
                startupSeams: AppRuntimeStartupSeams(
                    load: { .notFound },
                    observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                    registerDiagnosticHotKeys: { status }
                )
            )

            await runtime.startForTesting()

            XCTAssertEqual(
                evidence.recorder.proofStatus,
                .invalid(.hotKeyRegistrationFailed)
            )
            _ = await runtime.stopAndFlush()
        }
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
            carbonReceipt: { correlationID, action in
                evidence.recorder.record(kind: .carbonReceived, correlationID: correlationID)
                XCTAssertEqual(action, .visibility)
            },
            action: { correlationID, action in
                evidence.recorder.record(kind: .mainDispatchBegan, correlationID: correlationID)
                XCTAssertEqual(action, .visibility)
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
            try! XCTUnwrap(
                envelopes.firstIndex {
                    $0.kind == .carbonReceived && $0.correlationID == correlationID
                })
        )
        XCTAssertLessThan(
            try! XCTUnwrap(
                envelopes.firstIndex {
                    $0.kind == .carbonReceived && $0.correlationID == correlationID
                }),
            try! XCTUnwrap(
                envelopes.firstIndex {
                    $0.kind == .mainDispatchBegan && $0.correlationID == correlationID
                })
        )
    }

    func testBothHotKeyActionsPropagateCorrelationID() async {
        let evidence = makeDiagnosticRecorderHarness()
        let dispatches = expectation(description: "both main dispatches")
        dispatches.expectedFulfillmentCount = 2
        let service = DiagnosticHotKeyService(
            carbonReceipt: { correlationID, action in
                evidence.recorder.record(
                    kind: .carbonReceived,
                    correlationID: correlationID,
                    payload: DiagnosticEventPayload(hotKeyAction: action.diagnosticNameForTesting)
                )
            },
            action: { correlationID, action in
                evidence.recorder.record(
                    kind: .mainDispatchBegan,
                    correlationID: correlationID,
                    payload: DiagnosticEventPayload(hotKeyAction: action.diagnosticNameForTesting)
                )
                dispatches.fulfill()
            }
        )

        service.receiveCarbonEventForTesting(.visibility)
        service.receiveCarbonEventForTesting(.lock)
        await fulfillment(of: [dispatches], timeout: 2)
        _ = await evidence.recorder.finish()

        for action in DiagnosticHotKeyAction.allCases {
            let name = action.diagnosticNameForTesting
            let events = evidence.sink.envelopes.filter { $0.payload.hotKeyAction == name }
            XCTAssertEqual(events.map(\.kind), [.carbonReceived, .mainDispatchBegan])
            XCTAssertEqual(Set(events.compactMap(\.correlationID)).count, 1)
        }
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
            try! XCTUnwrap(
                evidence.sink.envelopes.lastIndex {
                    $0.kind == .correlationWindowClosed
                }),
            try! XCTUnwrap(evidence.sink.envelopes.lastIndex { $0.kind == .sessionCompletion })
        )
    }
}

extension DiagnosticHotKeyAction {
    fileprivate var diagnosticNameForTesting: DiagnosticHotKeyActionName {
        switch self {
        case .visibility: .visibility
        case .lock: .lock
        }
    }
}
#endif
