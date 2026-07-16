import AppKit

struct RuntimeDisplayGeneration: Equatable, Comparable, Sendable {
    let rawValue: UInt64

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AppRuntimeStartupEvent: Equatable {
    case shieldController
    case load
    case restore
    case observeAndQuery
    case evaluatePrivacy
    case registerProductHotKeys
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
    #if DEBUG
    var registerDiagnosticHotKeys: (@MainActor () -> DiagnosticHotKeyRegistrationStatus)?
    #endif

    #if DEBUG
    var requestsLegacyDiagnosticMode: Bool {
        registerDiagnosticHotKey != nil || registerDiagnosticHotKeys != nil
    }
    #endif
    var record: @MainActor (AppRuntimeStartupEvent) -> Void
    #if DEBUG
    var recordDiagnosticLifecycle: @MainActor (AppRuntimeDiagnosticLifecycleEvent) -> Void
    #endif

    #if DEBUG
    init(
        load: (@MainActor () async -> SnapshotLoadResult)? = nil,
        observeAndQuery: (@MainActor () -> Result<RuntimeDisplayInventory, Error>)? = nil,
        registerDiagnosticHotKey: (@MainActor () -> Int32)? = nil,
        registerDiagnosticHotKeys:
            (@MainActor () -> DiagnosticHotKeyRegistrationStatus)? = nil,
        record: @escaping @MainActor (AppRuntimeStartupEvent) -> Void = { _ in },
        recordDiagnosticLifecycle:
            @escaping @MainActor (
                AppRuntimeDiagnosticLifecycleEvent
            ) -> Void = { _ in }
    ) {
        self.load = load
        self.observeAndQuery = observeAndQuery
        self.registerDiagnosticHotKey = registerDiagnosticHotKey
        self.registerDiagnosticHotKeys = registerDiagnosticHotKeys
        self.record = record
        self.recordDiagnosticLifecycle = recordDiagnosticLifecycle
    }
    #else
    init(
        load: (@MainActor () async -> SnapshotLoadResult)? = nil,
        observeAndQuery: (@MainActor () -> Result<RuntimeDisplayInventory, Error>)? = nil,
        registerDiagnosticHotKey: (@MainActor () -> Int32)? = nil,
        record: @escaping @MainActor (AppRuntimeStartupEvent) -> Void = { _ in }
    ) {
        self.load = load
        self.observeAndQuery = observeAndQuery
        self.registerDiagnosticHotKey = registerDiagnosticHotKey
        self.record = record
    }
    #endif
}

@MainActor
final class AppRuntime {
    let dependencies: DependencyContainer
    let overlayController: OverlayPanelController
    let model: AppModel
    let controllerWindowController: ControllerWindowController
    let statusItemController: StatusItemController
    let displayService: SystemDisplayService
    let hotKeyStartupMode: HotKeyStartupMode
    #if DEBUG
    let diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder?
    let diagnosticConfiguration: DiagnosticProofConfiguration?
    let enforcesDiagnosticControllerCohort: Bool
    lazy var diagnosticObserverSet: DiagnosticObserverSet? = makeDiagnosticObserverSet()
    lazy var diagnosticHotKeyService: DiagnosticHotKeyService = makeDiagnosticHotKeyService()
    #endif

    private let startupSeams: AppRuntimeStartupSeams
    private var startupTask: Task<Void, Never>?
    private var nextDisplayGenerationRawValue: UInt64 = 0
    private(set) var observationGeneration: RuntimeDisplayGeneration?
    private(set) var topologyGeneration: RuntimeDisplayGeneration?
    private(set) var hotKeyShutdownReport: HotKeyShutdownReport?
    lazy var lifecycleCoordinator = AppLifecycleCoordinator(
        model: model,
        flushPausedSnapshot: { [weak self] in
            guard let self else { return false }
            self.startupSeams.record(.flushPersistence)
            return await self.dependencies.effectAdapter.flushForTermination()
        },
        closeCarbonDispatch: { [weak self] in
            guard let self, self.hotKeyStartupMode == .product else { return }
            self.dependencies.effectAdapter.carbonHotKeyService.closeDispatch()
        },
        unregisterHotKeys: { [weak self] in
            await self?.unregisterSelectedHotKeys()
        },
        stopFocusPointerDisplay: { [weak self] in
            guard let self else { return }
            self.dependencies.effectAdapter.handle(.teardownFocusMode)
            let invalidation = self.issueDisplayGeneration()
            self.observationGeneration = nil
            self.topologyGeneration = nil
            self.displayService.stopObserving(invalidatedBy: invalidation)
        },
        teardownScrollSession: { [weak self] in
            self?.model.send(.teardownScrollSession)
            self?.overlayController.teardownConnection()
            self?.dependencies.restorePerformanceGate.cancel()
            self?.dependencies.performanceRegistry.cancelAll()
        },
        removeStatusItem: { [weak self] in
            self?.statusItemController.remove()
        },
        closeController: { [weak self] in
            self?.controllerWindowController.close()
            self?.startupSeams.record(.stopServices)
        }
    )
    #if DEBUG
    private var activeDiagnosticCorrelations: [UUID] = []
    private var currentDiagnosticCorrelationID: UUID?
    private var firstShowCohortValidated = false
    private var closedDiagnosticCorrelationCount = 0
    private var topologyDiagnosticCorrelationID: UUID?
    #endif

    #if DEBUG
    convenience init(
        proofLevel: OverlayPanelLevel = .statusBar,
        diagnosticConfiguration: DiagnosticProofConfiguration? = nil,
        diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder? = nil,
        enforcesDiagnosticControllerCohort: Bool = true,
        dependencies: DependencyContainer? = nil,
        hotKeyStartupMode: HotKeyStartupMode? = nil,
        startupSeams: AppRuntimeStartupSeams = AppRuntimeStartupSeams()
    ) {
        self.init(
            proofLevel: proofLevel,
            diagnosticConfigurationObject: diagnosticConfiguration,
            diagnosticEvidenceRecorderObject: diagnosticEvidenceRecorder,
            enforcesDiagnosticControllerCohort: enforcesDiagnosticControllerCohort,
            dependencies: dependencies,
            hotKeyStartupModeObject: hotKeyStartupMode,
            startupSeams: startupSeams
        )
    }
    #else
    convenience init(
        proofLevel: OverlayPanelLevel = .statusBar,
        dependencies: DependencyContainer? = nil,
        hotKeyStartupMode: HotKeyStartupMode = .product,
        startupSeams: AppRuntimeStartupSeams = AppRuntimeStartupSeams()
    ) {
        self.init(
            proofLevel: proofLevel,
            diagnosticConfigurationObject: nil,
            diagnosticEvidenceRecorderObject: nil,
            enforcesDiagnosticControllerCohort: true,
            dependencies: dependencies,
            hotKeyStartupModeObject: hotKeyStartupMode,
            startupSeams: startupSeams
        )
    }
    #endif

    private init(
        proofLevel: OverlayPanelLevel,
        diagnosticConfigurationObject: Any?,
        diagnosticEvidenceRecorderObject: AnyObject?,
        enforcesDiagnosticControllerCohort: Bool,
        dependencies suppliedDependencies: DependencyContainer?,
        hotKeyStartupModeObject: Any?,
        startupSeams: AppRuntimeStartupSeams
    ) {
        #if DEBUG
        let diagnosticConfiguration =
            diagnosticConfigurationObject
            as? DiagnosticProofConfiguration
        let diagnosticEvidenceRecorder =
            diagnosticEvidenceRecorderObject
            as? DiagnosticEvidenceRecorder
        #endif
        let dependencies: DependencyContainer
        if let supplied = suppliedDependencies {
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
        #if DEBUG
        let controllerWindowController = ControllerWindowController(
            model: model,
            performanceRegistry: dependencies.performanceRegistry,
            operationRecorder: { [weak diagnosticEvidenceRecorder, weak model] operation in
                diagnosticEvidenceRecorder?.record(
                    kind: .controllerOperation,
                    correlationID: model?.diagnosticCorrelationID,
                    payload: DiagnosticEventPayload(controllerOperation: operation.diagnosticName)
                )
            }
        )
        #else
        let controllerWindowController = ControllerWindowController(
            model: model,
            performanceRegistry: dependencies.performanceRegistry
        )
        #endif

        self.dependencies = dependencies
        overlayController = dependencies.overlayController
        self.model = model
        self.controllerWindowController = controllerWindowController
        statusItemController = StatusItemController(model: model)
        displayService = dependencies.displayService
        #if DEBUG
        hotKeyStartupMode =
            hotKeyStartupModeObject as? HotKeyStartupMode
            ?? ((diagnosticConfiguration != nil
                || diagnosticEvidenceRecorder != nil
                || startupSeams.requestsLegacyDiagnosticMode)
                ? .legacyDiagnostic : .product)
        #else
        hotKeyStartupMode = hotKeyStartupModeObject as? HotKeyStartupMode ?? .product
        #endif
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
        displayService.onReconfigurationBegan = { [weak self] observation in
            self?.receiveTopologyWillChange(observation: observation)
        }
        displayService.onScreensChanged = { [weak self] observation, topology, result in
            self?.receive(
                result,
                observation: observation,
                topology: topology
            )
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
        dependencies.restorePerformanceGate.cancel()
        return await lifecycleCoordinator.stopAndFlush()
    }

    private func unregisterSelectedHotKeys() async {
        switch hotKeyStartupMode {
        case .product:
            hotKeyShutdownReport = dependencies.effectAdapter.carbonHotKeyService.shutdown()
        case .legacyDiagnostic:
            #if DEBUG
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
            #else
            break
            #endif
        }
    }

    private func runStartup(afterRestore: @MainActor () -> Void = {}) async {
        #if DEBUG
        if hotKeyStartupMode == .legacyDiagnostic {
            diagnosticObserverSet?.install(
                panel: overlayController.teleprompterPanel,
                controller: controllerWindowController.window
            )
            startupSeams.recordDiagnosticLifecycle(.installObservers)
        }
        #endif
        startupSeams.record(.shieldController)
        controllerWindowController.presentShieldedControllerAtStartup(on: nil)

        startupSeams.record(.load)
        dependencies.restorePerformanceGate.begin(reason: .restore)
        let loadResult: SnapshotLoadResult
        if let load = startupSeams.load {
            loadResult = await load()
        } else {
            loadResult = await dependencies.snapshotStore.load()
        }
        guard !Task.isCancelled else {
            dependencies.restorePerformanceGate.cancel()
            return
        }

        switch loadResult {
        case .loaded(let restored):
            model.send(.restore(restored.snapshot))
        case .notFound:
            model.send(.restore(nil))
        case .recoveredMalformed, .unsupportedFutureSchema, .recoveryFailed:
            model.send(.restoreFailed)
        }
        startupSeams.record(.restore)
        dependencies.restorePerformanceGate.restoreCompleted()
        if overlayController.readerTextSystem.viewportAdapter?.attachmentView?.window != nil {
            dependencies.restorePerformanceGate.readerAttached()
        }
        afterRestore()

        startupSeams.record(.observeAndQuery)
        let observation = issueDisplayGeneration()
        observationGeneration = observation
        let topology = beginTopologyTransaction(observation: observation)
        let inventoryResult: Result<RuntimeDisplayInventory, Error>
        if let observeAndQuery = startupSeams.observeAndQuery {
            inventoryResult = observeAndQuery()
        } else {
            do {
                try displayService.startObserving(generation: observation)
                inventoryResult = .success(try displayService.currentInventory())
            } catch {
                inventoryResult = .failure(error)
            }
        }
        if let topology {
            receive(
                inventoryResult,
                observation: observation,
                topology: topology
            )
        }
        startupSeams.record(.evaluatePrivacy)

        switch hotKeyStartupMode {
        case .product:
            let result = dependencies.effectAdapter.carbonHotKeyService.register(
                model.shortcutBindings
            )
            model.send(.hotKeyReconfigurationCompleted(result))
            startupSeams.record(.registerProductHotKeys)
        case .legacyDiagnostic:
            #if DEBUG
            let status: DiagnosticHotKeyRegistrationStatus
            if let register = startupSeams.registerDiagnosticHotKeys {
                status = register()
            } else if let register = startupSeams.registerDiagnosticHotKey {
                let overriddenStatus = register()
                status = DiagnosticHotKeyRegistrationStatus(
                    visibility: overriddenStatus,
                    lock: overriddenStatus
                )
            } else {
                status = diagnosticHotKeyService.register()
            }
            model.setDiagnosticHotKeyStatus(status)
            if !status.allRegistered {
                diagnosticEvidenceRecorder?.invalidate(.hotKeyRegistrationFailed)
            }
            startupSeams.recordDiagnosticLifecycle(.registerHotKey)
            startupSeams.record(.registerDiagnosticHotKey)
            #else
            break
            #endif
        }
        statusItemController.setActionsReady(true)
    }

    private func receive(
        _ result: Result<RuntimeDisplayInventory, Error>,
        observation: RuntimeDisplayGeneration,
        topology: RuntimeDisplayGeneration
    ) {
        guard
            observation == observationGeneration,
            topology == topologyGeneration
        else { return }
        #if DEBUG
        if let topologyDiagnosticCorrelationID {
            switch result {
            case .success(let inventory):
                model.acceptDisplayInventory(
                    inventory,
                    generation: topology,
                    correlationID: topologyDiagnosticCorrelationID
                )
            case .failure:
                model.acceptDisplayInventoryFailure(
                    generation: topology,
                    correlationID: topologyDiagnosticCorrelationID
                )
            }
            self.topologyDiagnosticCorrelationID = nil
            return
        }
        #endif
        switch result {
        case .success(let inventory):
            model.acceptDisplayInventory(inventory, generation: topology)
        case .failure:
            model.acceptDisplayInventoryFailure(generation: topology)
        }
    }

    private func receiveTopologyWillChange(
        observation: RuntimeDisplayGeneration
    ) -> RuntimeDisplayGeneration? {
        beginTopologyTransaction(observation: observation)
    }

    private func beginTopologyTransaction(
        observation: RuntimeDisplayGeneration
    ) -> RuntimeDisplayGeneration? {
        guard
            observation == observationGeneration,
            !model.isTerminationAttempting,
            !model.isTerminationQuiescing
        else { return nil }
        let generation = issueDisplayGeneration()
        topologyGeneration = generation
        #if DEBUG
        let correlationID = UUID()
        topologyDiagnosticCorrelationID = correlationID
        model.beginTopologyTransaction(
            generation: generation,
            correlationID: correlationID
        )
        #else
        model.beginTopologyTransaction(generation: generation)
        #endif
        return generation
    }

    private func issueDisplayGeneration() -> RuntimeDisplayGeneration {
        let (next, overflow) = nextDisplayGenerationRawValue.addingReportingOverflow(1)
        precondition(!overflow, "Runtime display generation exhausted")
        nextDisplayGenerationRawValue = next
        return RuntimeDisplayGeneration(rawValue: next)
    }

    #if DEBUG
    func validateControllerCohortBeforeFirstHotKey() -> Bool {
        guard !firstShowCohortValidated else { return true }
        guard enforcesDiagnosticControllerCohort else { return true }
        guard let configuration = diagnosticConfiguration,
            let recorder = diagnosticEvidenceRecorder,
            let observed = controllerWindowController.observedDiagnosticCohort()
        else {
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
            carbonReceipt: { correlationID, hotKeyAction in
                recorder?.record(
                    kind: .carbonReceived,
                    correlationID: correlationID,
                    payload: DiagnosticEventPayload(
                        hotKeyAction: hotKeyAction.diagnosticName
                    )
                )
            },
            action: { [weak self] correlationID, hotKeyAction in
                self?.handleDiagnosticHotKey(
                    hotKeyAction,
                    correlationID: correlationID
                )
            }
        )
    }

    private func makeDiagnosticObserverSet() -> DiagnosticObserverSet? {
        guard let diagnosticEvidenceRecorder else { return nil }
        return DiagnosticObserverSet(
            recorder: diagnosticEvidenceRecorder,
            correlationProvider: { [weak self] in self?.currentDiagnosticCorrelationID },
            postCorrelationQuitEligibilityProvider: { [weak self] in
                guard let self else { return false }
                return self.closedDiagnosticCorrelationCount >= 3
                    && self.activeDiagnosticCorrelations.isEmpty
            }
        )
    }

    private func handleDiagnosticHotKey(
        _ hotKeyAction: DiagnosticHotKeyAction,
        correlationID: UUID
    ) {
        diagnosticEvidenceRecorder?.record(
            kind: .mainDispatchBegan,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(
                hotKeyAction: hotKeyAction.diagnosticName,
                focus: captureDiagnosticFocus()
            )
        )
        activeDiagnosticCorrelations.append(correlationID)
        currentDiagnosticCorrelationID = correlationID

        if validateControllerCohortBeforeFirstHotKey() {
            // Direct command-owner dispatch: no controller opening or raising.
            switch hotKeyAction {
            case .visibility:
                model.toggleOverlayFromDiagnosticHotKey(correlationID: correlationID)
            case .lock:
                model.toggleLockFromDiagnosticHotKey(correlationID: correlationID)
            }
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
                self.closedDiagnosticCorrelationCount += 1
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
extension ControllerWindowOperation {
    fileprivate var diagnosticName: DiagnosticControllerOperationName {
        switch self {
        case .placementEntry: .placementEntry
        case .frameChanged: .frameChanged
        case .placementExit: .placementExit
        case .presentationEntry: .presentationEntry
        case .showWindow: .showWindow
        case .presentationExit: .presentationExit
        }
    }
}

extension DiagnosticHotKeyAction {
    fileprivate var diagnosticName: DiagnosticHotKeyActionName {
        switch self {
        case .visibility: .visibility
        case .lock: .lock
        }
    }
}

extension DiagnosticFocusState {
    fileprivate static let unavailable = DiagnosticFocusState(
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
