import Foundation
import TeleprompterCore

@MainActor
final class AppEffectAdapter {
    private let snapshotStore: SnapshotStore
    private let overlayController: OverlayPanelController
    private weak var model: AppModel?
    private weak var controllerWindowController: ControllerWindowController?
    private var persistenceTask: Task<Void, Never>?
    private var persistenceGeneration: UInt64 = 0
    private var isTerminationDraining = false
    private var terminalFlushStarted = false
    private var terminalFlushSucceeded = false
    private let terminationFlushOverride: (@Sendable () async -> Bool)?
    #if DEBUG
    private let diagnosticRecorder: DiagnosticEvidenceRecorder?
    #endif

    #if DEBUG
    convenience init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        diagnosticRecorder: DiagnosticEvidenceRecorder? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            snapshotStore: snapshotStore,
            overlayController: overlayController,
            diagnosticRecorderObject: diagnosticRecorder,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #else
    convenience init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            snapshotStore: snapshotStore,
            overlayController: overlayController,
            diagnosticRecorderObject: nil,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #endif

    private init(
        snapshotStore: SnapshotStore,
        overlayController: OverlayPanelController,
        diagnosticRecorderObject: AnyObject?,
        terminationFlushOverride: (@Sendable () async -> Bool)?
    ) {
        self.snapshotStore = snapshotStore
        self.overlayController = overlayController
        #if DEBUG
        diagnosticRecorder = diagnosticRecorderObject as? DiagnosticEvidenceRecorder
        #endif
        self.terminationFlushOverride = terminationFlushOverride
    }

    func connect(model: AppModel, controller: ControllerWindowController) {
        self.model = model
        controllerWindowController = controller
    }

    func handle(_ effect: AppEffect) {
        #if DEBUG
        let correlationID = model?.diagnosticCorrelationID
        diagnosticRecorder?.record(
            kind: .effectApplyBefore,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(effect: effect.diagnosticName)
        )
        #endif
        switch effect {
        case .scheduleSnapshot(let snapshot):
            enqueuePersistence { store in
                try await store.scheduleSave(snapshot)
            }
        case .flushSnapshot(let token, let requiredRevision):
            enqueuePersistence { [weak self] store in
                do {
                    try await store.flush()
                    let status = await store.status()
                    let persistedRevision = status.persistedRevision ?? 0
                    await self?.completeClear(
                        token: token,
                        persistedRevision: persistedRevision,
                        succeeded: status.persistedRevision == requiredRevision
                    )
                } catch {
                    await self?.completeClear(
                        token: token,
                        persistedRevision: requiredRevision,
                        succeeded: false
                    )
                }
            }
        case .saveSnapshotImmediately(let snapshot):
            enqueuePersistence(allowDuringTermination: true) { store in
                try await store.scheduleSave(snapshot)
                try await store.flush()
            }
        case .flushPersistence:
            enqueuePersistence { store in
                try await store.flush()
            }
        case .stagePanelHidden(let display):
            #if DEBUG
            recordPanelOperation(.stageHidden, correlationID: correlationID)
            #endif
            overlayController.stageHidden(
                proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame
            )
        case .showPanel(let display):
            #if DEBUG
            let operation: DiagnosticPanelOperationName =
                overlayController.orderingMode == .front
                ? .orderFront
                : .orderFrontRegardless
            recordPanelOperation(operation, correlationID: correlationID)
            #endif
            overlayController.show(
                proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame
            )
        case .hidePanel:
            #if DEBUG
            recordPanelOperation(.orderOut, correlationID: correlationID)
            #endif
            overlayController.hide()
        case .setPanelLocked(let locked):
            #if DEBUG
            recordPanelOperation(.setLocked, correlationID: correlationID)
            #endif
            overlayController.setLocked(locked)
        case .moveControllerWhileShielded(let display):
            controllerWindowController?.showShielded(on: display)
            let model = model
            Task { @MainActor in
                await Task.yield()
                model?.send(.completeShieldedMove(screenID: display.id))
            }
        case .resetViewport, .reassessPrivacy, .queryTopology, .evaluatePrivacy:
            break
        }
        #if DEBUG
        diagnosticRecorder?.record(
            kind: .effectApplyAfter,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(effect: effect.diagnosticName)
        )
        #endif
    }

    func flushForTermination() async -> Bool {
        // Reject new durable intent at the model boundary, but drain any completion
        // causally owned by an already-enqueued operation (notably pre-clear flush).
        // Each such completion synchronously extends `persistenceGeneration` before
        // its predecessor task returns, so the loop cannot miss its immediate save.
        isTerminationDraining = true

        while true {
            let observedGeneration = persistenceGeneration
            let observedTask = persistenceTask
            _ = await observedTask?.value
            await Task.yield()
            guard observedGeneration == persistenceGeneration else { continue }
            break
        }

        // This is the terminal barrier. `enqueuePersistence` refuses every later
        // operation once it is set, and this flush is appended after the stable tail.
        terminalFlushStarted = true
        let precedingTask = persistenceTask
        let snapshotStore = snapshotStore
        let terminationFlushOverride = terminationFlushOverride
        let expectedRevision = model?.snapshotRevision ?? 0
        persistenceGeneration += 1
        let terminalTask = Task { @MainActor [weak self] in
            _ = await precedingTask?.value
            let didFlush: Bool
            if let terminationFlushOverride {
                didFlush = await terminationFlushOverride()
            } else {
                do {
                    try await snapshotStore.flush()
                    let status = await snapshotStore.status()
                    didFlush =
                        status.persistedRevision == expectedRevision
                        || (expectedRevision == 0 && status.persistedRevision == nil)
                } catch {
                    didFlush = false
                }
            }
            self?.terminalFlushSucceeded = didFlush
        }
        persistenceTask = terminalTask
        _ = await terminalTask.value
        return terminalFlushSucceeded
    }

    private func enqueuePersistence(
        allowDuringTermination: Bool = false,
        _ operation: @escaping @Sendable (SnapshotStore) async throws -> Void
    ) {
        guard
            !isTerminationDraining
                || (allowDuringTermination && !terminalFlushStarted)
        else { return }
        let precedingTask = persistenceTask
        let snapshotStore = snapshotStore
        persistenceGeneration += 1
        persistenceTask = Task { @MainActor in
            _ = await precedingTask?.value
            do {
                try await operation(snapshotStore)
            } catch {
                // SnapshotStore retains pending data for retry and exposes only
                // content-neutral diagnostics. No script content is surfaced here.
            }
        }
    }

    private func completeClear(
        token: ClearToken,
        persistedRevision: UInt64,
        succeeded: Bool
    ) {
        model?.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: persistedRevision,
                succeeded: succeeded
            ))
    }

    #if DEBUG
    private func recordPanelOperation(
        _ operation: DiagnosticPanelOperationName,
        correlationID: UUID?
    ) {
        diagnosticRecorder?.record(
            kind: .panelOperation,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(
                panelOperation: operation,
                panelState: overlayController.teleprompterPanel.diagnosticState
            )
        )
    }
    #endif
}

@MainActor
final class DependencyContainer {
    let snapshotStore: SnapshotStore
    let overlayController: OverlayPanelController
    let displayService: SystemDisplayService
    let effectAdapter: AppEffectAdapter
    #if DEBUG
    let diagnosticRecorder: DiagnosticEvidenceRecorder?
    #endif
    private(set) var appModelConstructionCount = 0

    #if DEBUG
    convenience init(
        proofLevel: OverlayPanelLevel,
        orderingMode: OverlayPanelOrderingMode = .frontRegardless,
        diagnosticRecorder: DiagnosticEvidenceRecorder? = nil,
        snapshotStore: SnapshotStore? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            proofLevel: proofLevel,
            orderingModeObject: orderingMode,
            diagnosticRecorderObject: diagnosticRecorder,
            snapshotStore: snapshotStore,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #else
    convenience init(
        proofLevel: OverlayPanelLevel,
        snapshotStore: SnapshotStore? = nil,
        terminationFlushOverride: (@Sendable () async -> Bool)? = nil
    ) {
        self.init(
            proofLevel: proofLevel,
            orderingModeObject: nil,
            diagnosticRecorderObject: nil,
            snapshotStore: snapshotStore,
            terminationFlushOverride: terminationFlushOverride
        )
    }
    #endif

    private init(
        proofLevel: OverlayPanelLevel,
        orderingModeObject: Any?,
        diagnosticRecorderObject: AnyObject?,
        snapshotStore: SnapshotStore?,
        terminationFlushOverride: (@Sendable () async -> Bool)?
    ) {
        #if DEBUG
        let orderingMode =
            orderingModeObject as? OverlayPanelOrderingMode
            ?? .frontRegardless
        let diagnosticRecorder = diagnosticRecorderObject as? DiagnosticEvidenceRecorder
        #endif
        let resolvedStore: SnapshotStore
        if let snapshotStore {
            resolvedStore = snapshotStore
        } else if let productionStore = try? SnapshotStore.production() {
            resolvedStore = productionStore
        } else {
            // A path-resolution failure remains fail-closed: this unusable root
            // causes content-neutral load/save failures rather than alternate storage.
            resolvedStore = SnapshotStore(
                rootURL: URL(fileURLWithPath: "/dev/null/private-presenter-unavailable")
            )
        }

        self.snapshotStore = resolvedStore
        #if DEBUG
        self.diagnosticRecorder = diagnosticRecorder
        overlayController = OverlayPanelController(
            proofLevel: proofLevel,
            orderingMode: orderingMode
        )
        #else
        overlayController = OverlayPanelController(proofLevel: proofLevel)
        #endif
        displayService = SystemDisplayService()
        #if DEBUG
        effectAdapter = AppEffectAdapter(
            snapshotStore: resolvedStore,
            overlayController: overlayController,
            diagnosticRecorder: diagnosticRecorder,
            terminationFlushOverride: terminationFlushOverride
        )
        #else
        effectAdapter = AppEffectAdapter(
            snapshotStore: resolvedStore,
            overlayController: overlayController,
            terminationFlushOverride: terminationFlushOverride
        )
        #endif
    }

    func makeAppModel(restorationRequired: Bool = true) -> AppModel {
        appModelConstructionCount += 1
        let adapter = effectAdapter
        #if DEBUG
        return AppModel(
            overlayController: overlayController,
            restorationRequired: restorationRequired,
            diagnosticEvidenceRecorder: diagnosticRecorder,
            effectHandler: { [weak adapter] effect in
                adapter?.handle(effect)
            }
        )
        #else
        return AppModel(
            overlayController: overlayController,
            restorationRequired: restorationRequired,
            effectHandler: { [weak adapter] effect in
                adapter?.handle(effect)
            }
        )
        #endif
    }
}
