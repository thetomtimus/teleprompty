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

@MainActor
struct AppRuntimeStartupSeams {
    var load: (@MainActor () async -> SnapshotLoadResult)?
    var observeAndQuery: (@MainActor () -> Result<RuntimeDisplayInventory, Error>)?
    var registerDiagnosticHotKey: (@MainActor () -> Int32)?
    var record: @MainActor (AppRuntimeStartupEvent) -> Void

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
}

@MainActor
final class AppRuntime {
    let dependencies: DependencyContainer
    let overlayController: OverlayPanelController
    let model: AppModel
    let controllerWindowController: ControllerWindowController
    let displayService: SystemDisplayService
#if DEBUG
    let diagnosticHotKeyService: DiagnosticHotKeyService
#endif

    private let startupSeams: AppRuntimeStartupSeams
    private var startupTask: Task<Void, Never>?

    init(
        proofLevel: OverlayPanelLevel = .statusBar,
        dependencies: DependencyContainer? = nil,
        startupSeams: AppRuntimeStartupSeams = AppRuntimeStartupSeams()
    ) {
        let dependencies = dependencies
            ?? DependencyContainer(proofLevel: proofLevel)
        let model = dependencies.makeAppModel(restorationRequired: true)
        let controllerWindowController = ControllerWindowController(model: model)

        self.dependencies = dependencies
        overlayController = dependencies.overlayController
        self.model = model
        self.controllerWindowController = controllerWindowController
        displayService = dependencies.displayService
        self.startupSeams = startupSeams
#if DEBUG
        diagnosticHotKeyService = DiagnosticHotKeyService { [weak model] in
            // Direct command-owner dispatch: no controller opening or raising.
            model?.toggleOverlayFromDiagnosticHotKey()
        }
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
        diagnosticHotKeyService.unregister()
#endif
        displayService.stopObserving()
        controllerWindowController.close()
        startupSeams.record(.stopServices)
        return true
    }

    private func runStartup(afterRestore: @MainActor () -> Void = {}) async {
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
        startupSeams.record(.registerDiagnosticHotKey)
#endif
    }

    private func receive(_ result: Result<RuntimeDisplayInventory, Error>) {
        model.refreshDisplayInventory(result)
    }
}
