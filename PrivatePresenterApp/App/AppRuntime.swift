import AppKit

@MainActor
final class AppRuntime {
    let overlayController: OverlayPanelController
    let model: DiagnosticHarnessModel
    let controllerWindowController: ControllerWindowController
    let displayService: SystemDisplayService
#if DEBUG
    let diagnosticHotKeyService: DiagnosticHotKeyService
#endif

    init(proofLevel: OverlayPanelLevel = .floating) {
        let overlayController = OverlayPanelController(proofLevel: proofLevel)
        let model = DiagnosticHarnessModel(overlayController: overlayController)
        let controllerWindowController = ControllerWindowController(model: model)
        let displayService = SystemDisplayService()

        self.overlayController = overlayController
        self.model = model
        self.controllerWindowController = controllerWindowController
        self.displayService = displayService
#if DEBUG
        diagnosticHotKeyService = DiagnosticHotKeyService { [weak model] in
            model?.toggleOverlayFromDiagnosticHotKey()
        }
#endif

        model.onConfirmedDisplay = { [weak controllerWindowController] display in
            // The model is still shielded while the controller moves. Only the
            // explicit confirmation action may reveal the proof controls.
            controllerWindowController?.showShielded(on: display)
        }

        displayService.onReconfigurationBegan = { [weak model] in
            model?.topologyWillChange()
        }
        displayService.onScreensChanged = { [weak self] result in
            self?.receive(result)
        }
    }

    func start() {
        // The controller root is shielded before any display query or window placement.
        controllerWindowController.showShielded(on: nil)
        do {
            try displayService.startObserving()
            receive(.success(try displayService.currentInventory()))
#if DEBUG
            model.setDiagnosticHotKeyStatus(diagnosticHotKeyService.register())
#endif
        } catch {
            receive(.failure(error))
        }
    }

    func stop() {
        model.topologyWillChange()
#if DEBUG
        diagnosticHotKeyService.unregister()
#endif
        displayService.stopObserving()
        controllerWindowController.close()
    }

    private func receive(_ result: Result<RuntimeDisplayInventory, Error>) {
        model.refreshDisplayInventory(result)
        let candidate = model.displays.first(where: {
            $0.id == model.selectedDisplayID && $0.isBuiltIn
        })
        controllerWindowController.showShielded(on: candidate)
    }
}
