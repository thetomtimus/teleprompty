import AppKit

enum AppRuntimeStartupEvent: Equatable {
    case shieldController
    case load
    case restore
    case observeAndQuery
    case evaluatePrivacy
    case registerDiagnosticHotKey
    case flushPersistence
    case stopServices
}

#if DEBUG
enum AppRuntimeDiagnosticLifecycleEvent: Equatable {
    case installObservers
    case registerHotKey
    case unregisterHotKey
    case drainCorrelations
    case tearDownObservers
    case finalizeEvidence
}
#endif

@MainActor
struct AppRuntimeStartupSeams {
    var load: (@MainActor () async -> SnapshotLoadResult)?
    var observeAndQuery: (@MainActor () -> Result<RuntimeDisplayInventory, Error>)?
    var registerDiagnosticHotKey: (@MainActor () -> Int32)?
    var record: @MainActor (AppRuntimeStartupEvent) -> Void
#if DEBUG
    var recordDiagnosticLifecycle: @MainActor (AppRuntimeDiagnosticLifecycleEvent) -> Void
#endif

    init(
        load: (@MainActor () async -> SnapshotLoadResult)? = nil,
        observeAndQuery: (@MainActor () -> Result<RuntimeDisplayInventory, Error>)? = nil,
        registerDiagnosticHotKey: (@MainActor () -> Int32)? = nil,
        record: @escaping @MainActor (AppRuntimeStartupEvent) -> Void = { _ in },
#if DEBUG
        recordDiagnosticLifecycle: @escaping @MainActor (
            AppRuntimeDiagnosticLifecycleEvent
        ) -> Void = { _ in }
#endif
    ) {
        self.load = load
        self.observeAndQuery = observeAndQuery
        self.registerDiagnosticHotKey = registerDiagnosticHotKey
        self.record = record
#if DEBUG
        self.recordDiagnosticLifecycle = recordDiagnosticLifecycle
#endif
    }
}

@MainActor
final class AppRuntime {
    let dependencies: DependencyContainer
    let overlayController: OverlayPanelController
    let model: AppModel
    let controllerWindowController: ControllerWindowController
    let displayService: SystemDisplayService
#if DEBUG
    let diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder?
    let diagnosticConfiguration: DiagnosticProofConfiguration?
    let enforcesDiagnosticControllerCohort: Bool
    lazy var diagnosticObserverSet: DiagnosticObserverSet? = makeDiagnosticObserverSet()
    lazy var diagnosticHotKeyService: DiagnosticHotKeyService = makeDiagnosticHotKeyService()
#endif

    private let startupSeams: AppRuntimeStartupSeams
    private var startupTask: Task<Void, Never>?
#if DEBUG
    private var activeDiagnosticCorrelations: [UUID] = []
    private var currentDiagnosticCorrelationID: UUID?
    private var firstShowCohortValidated = false
    private var hasClosedDiagnosticCorrelation = false
    private var isNormalTerminationFinalizing = false
#endif

    init(
        proofLevel: OverlayPanelLevel = .statusBar,
#if DEBUG
        diagnosticConfiguration: DiagnosticProofConfiguration? = nil,
        diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder? = nil,
        enforcesDiagnosticControllerCohort: Bool = true,
#endif
        dependencies: DependencyContainer? = nil,
        startupSeams: AppRuntimeStartupSeams = AppRuntimeStartupSeams()
    ) {
        let dependencies: DependencyContainer
        if let supplied = dependencies {
            dependencies = supplied
        } else {
#if DEBUG
            dependencies = DependencyContainer(
                proofLevel: proofLevel,
                orderingMode: diagnosticConfiguration?.ordering ?? .frontRegardless,
                diagnosticRecorder: diagnosticEvidenceRecorder
            )
#else
            dependencies = DependencyContainer(proofLevel: proofLevel)
#endif
        }
        let model = dependencies.makeAppModel(restorationRequired: true)
        let controllerWindowController = ControllerWindowController(
            model: model,
#if DEBUG
            operationRecorder: { [weak diagnosticEvidenceRecorder, weak model] operation in
                diagnosticEvidenceRecorder?.record(
                    kind: .controllerOperation,
                    correlationID: model?.diagnosticCorrelationID,
                    payload: DiagnosticEventPayload(controllerOperation: operation.diagnosticName)
                )
            }
#endif
        )

        self.dependencies = dependencies
        overlayController = dependencies.overlayController
        self.model = model
        self.controllerWindowController = controllerWindowController
        displayService = dependencies.displayService
        self.startupSeams = startupSeams
#if DEBUG
        self.diagnosticConfiguration = diagnosticConfiguration
        self.diagnosticEvidenceRecorder = diagnosticEvidenceRecorder
        self.enforcesDiagnosticControllerCohort = enforcesDiagnosticControllerCohort
#endif

        dependencies.effectAdapter.connect(
            model: model,
            controller: controllerWindowController
        )
        displayService.onReconfigurationBegan = { [weak model] in
            model?.send(.topologyWillChange)
        }
        displayService.onScreensChanged = { [weak self] result in
            self?.receive(result)
        }
    }

    func start() {
        guard startupTask == nil else { return }
        startupTask = Task { [weak self] in
            await self?.runStartup()
        }
    }

    func startForTesting(afterRestore: @MainActor () -> Void = {}) async {
        await runStartup(afterRestore: afterRestore)
    }

    func stopAndFlush() async -> Bool {
        startupTask?.cancel()
        startupTask = nil
        model.send(.topologyWillChange)
        model.beginTerminationQuiescence()
        startupSeams.record(.flushPersistence)
        let didFlush = await dependencies.effectAdapter.flushForTermination()
        guard didFlush else { return false }
#if DEBUG
        isNormalTerminationFinalizing = true
        diagnosticHotKeyService.unregister()
        startupSeams.recordDiagnosticLifecycle(.unregisterHotKey)
        startupSeams.recordDiagnosticLifecycle(.drainCorrelations)
        while diagnosticObserverSet?.activeCorrelationCount ?? 0 > 0 {
            do { try await Task.sleep(for: .milliseconds(10)) } catch { break }
        }
        diagnosticObserverSet?.tearDown()
        startupSeams.recordDiagnosticLifecycle(.tearDownObservers)
        _ = await diagnosticEvidenceRecorder?.finish()
        startupSeams.recordDiagnosticLifecycle(.finalizeEvidence)
#endif
        displayService.stopObserving()
        controllerWindowController.close()
        startupSeams.record(.stopServices)
        return true
    }

    private func runStartup(afterRestore: @MainActor () -> Void = {}) async {
#if DEBUG
        diagnosticObserverSet?.install(
            panel: overlayController.teleprompterPanel,
            controller: controllerWindowController.window
        )
        startupSeams.recordDiagnosticLifecycle(.installObservers)
#endif
        startupSeams.record(.shieldController)
        controllerWindowController.showShielded(on: nil)

        startupSeams.record(.load)
        let loadResult: SnapshotLoadResult
        if let load = startupSeams.load {
            loadResult = await load()
        } else {
            loadResult = await dependencies.snapshotStore.load()
        }
        guard !Task.isCancelled else { return }

        switch loadResult {
        case let .loaded(restored):
            model.send(.restore(restored.snapshot))
        case .notFound:
            model.send(.restore(nil))
        case .recoveredMalformed, .unsupportedFutureSchema, .recoveryFailed:
            model.send(.restoreFailed)
        }
        startupSeams.record(.restore)
        afterRestore()

        startupSeams.record(.observeAndQuery)
        let inventoryResult: Result<RuntimeDisplayInventory, Error>
        if let observeAndQuery = startupSeams.observeAndQuery {
            inventoryResult = observeAndQuery()
        } else {
            do {
                try displayService.startObserving()
                inventoryResult = .success(try displayService.currentInventory())
            } catch {
                inventoryResult = .failure(error)
            }
        }
        receive(inventoryResult)
        startupSeams.record(.evaluatePrivacy)

#if DEBUG
        let status: Int32
        if let register = startupSeams.registerDiagnosticHotKey {
            status = register()
        } else {
            status = diagnosticHotKeyService.register()
        }
        model.setDiagnosticHotKeyStatus(status)
        startupSeams.recordDiagnosticLifecycle(.registerHotKey)
        startupSeams.record(.registerDiagnosticHotKey)
#endif
    }

    private func receive(_ result: Result<RuntimeDisplayInventory, Error>) {
        model.refreshDisplayInventory(result)
    }

#if DEBUG
    func validateControllerCohortBeforeFirstHotKey() -> Bool {
        guard !firstShowCohortValidated else { return true }
        guard enforcesDiagnosticControllerCohort else { return true }
        guard let configuration = diagnosticConfiguration,
              let recorder = diagnosticEvidenceRecorder,
              let observed = controllerWindowController.observedDiagnosticCohort() else {
            diagnosticEvidenceRecorder?.invalidate(.controllerCohortMismatch)
            return diagnosticConfiguration == nil
        }
        recorder.record(
            kind: .controllerCohortObserved,
            correlationID: currentDiagnosticCorrelationID,
            payload: DiagnosticEventPayload(
                declaredControllerCohort: configuration.declaredControllerCohort,
                observedControllerCohort: observed,
                controllerState: controllerWindowController.window?.diagnosticState
            )
        )
        guard observed == configuration.declaredControllerCohort else {
            recorder.invalidate(.controllerCohortMismatch)
            return false
        }
        firstShowCohortValidated = true
        return true
    }

    private func makeDiagnosticHotKeyService() -> DiagnosticHotKeyService {
        let recorder = diagnosticEvidenceRecorder
        return DiagnosticHotKeyService(
            carbonReceipt: { correlationID in
                recorder?.record(kind: .carbonReceived, correlationID: correlationID)
            },
            action: { [weak self] correlationID in
                self?.handleDiagnosticVisibilityHotKey(correlationID: correlationID)
            }
        )
    }

    private func makeDiagnosticObserverSet() -> DiagnosticObserverSet? {
        guard let diagnosticEvidenceRecorder else { return nil }
        return DiagnosticObserverSet(
            recorder: diagnosticEvidenceRecorder,
            correlationProvider: { [weak self] in self?.currentDiagnosticCorrelationID },
            observationPhaseProvider: { [weak self] in
                guard let self else { return .correlatedAction }
                return self.isNormalTerminationFinalizing
                    && self.hasClosedDiagnosticCorrelation
                    && self.activeDiagnosticCorrelations.isEmpty
                    ? .postCorrelationQuit
                    : .correlatedAction
            }
        )
    }

    private func handleDiagnosticVisibilityHotKey(correlationID: UUID) {
        diagnosticEvidenceRecorder?.record(
            kind: .mainDispatchBegan,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(focus: captureDiagnosticFocus())
        )
        activeDiagnosticCorrelations.append(correlationID)
        currentDiagnosticCorrelationID = correlationID

        let isFirstShow = model.overlaySession.visibility != .visible
        if !isFirstShow || validateControllerCohortBeforeFirstHotKey() {
            // Direct command-owner dispatch: no controller opening or raising.
            model.toggleOverlayFromDiagnosticHotKey(correlationID: correlationID)
        }

        diagnosticObserverSet?.scheduleFocusSamples(
            correlationID: correlationID,
            capture: { [weak self] in
                self?.captureDiagnosticFocus() ?? DiagnosticFocusState.unavailable
            },
            onClosed: { [weak self] in
                guard let self else { return }
                self.activeDiagnosticCorrelations.removeAll { $0 == correlationID }
                self.currentDiagnosticCorrelationID = self.activeDiagnosticCorrelations.last
                self.hasClosedDiagnosticCorrelation = true
            }
        )
    }

    private func captureDiagnosticFocus() -> DiagnosticFocusState {
        WorkspaceFocusProbe.captureDiagnosticState(
            panel: overlayController.teleprompterPanel,
            controller: controllerWindowController,
            controllerShielded: model.isShielded
        )
    }
#endif
}

#if DEBUG
private extension ControllerWindowOperation {
    var diagnosticName: DiagnosticControllerOperationName {
        switch self {
        case .showShieldedEntry: .showShieldedEntry
        case .frameChanged: .frameChanged
        case .showWindow: .showWindow
        case .showShieldedExit: .showShieldedExit
        }
    }
}

private extension DiagnosticFocusState {
    static let unavailable = DiagnosticFocusState(
        frontmostProcessIdentifier: nil,
        frontmostBundleIdentifier: nil,
        applicationIsActive: false,
        activationPolicy: "unknown",
        panel: DiagnosticWindowState(
            isVisible: false,
            isKey: false,
            isMain: false,
            frame: DiagnosticRect(.zero),
            occlusionState: 0
        ),
        controller: nil,
        controllerShowCount: 0,
        controllerShielded: true
    )
}
#endif
