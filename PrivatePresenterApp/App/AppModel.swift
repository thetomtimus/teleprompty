import AppKit
import Observation
import TeleprompterCore

@MainActor
@Observable
final class AppModel {
    static let mirroringWarning =
        "Display mirroring is on. Students may see the teleprompter. Use Extended Display mode."
    static let queryFailureWarning =
        "Display safety could not be verified. Your script is hidden and the teleprompter is closed."
    static let ambiguityWarning =
        "Private Presenter cannot reliably distinguish these displays. Select and confirm the display only you can see."
    static let noSeparationWarning =
        "No separate audience display protection."

    private(set) var document: ScriptDocument
    private(set) var preferences: TeleprompterPreferences
    private(set) var overlaySession: OverlaySession
    private(set) var panelFrames: [PersistedPanelFrame]
    private(set) var shortcutBindings: [ShortcutBinding]
    private(set) var snapshotRevision: UInt64

    private(set) var displays: [RuntimeDisplay] = []
    private(set) var selectedDisplayID: UInt32?
    private(set) var isSelectionConfirmed = false
    private(set) var isShielded = true
    private(set) var warning: String?
    private(set) var localError: AppLocalError?
    private(set) var pendingShowGeneration = 0
    private(set) var commandDispatchCount = 0
    private(set) var restorationCompleted: Bool
    private(set) var isPersistenceLoadSafe: Bool
    private(set) var isTerminationQuiescing = false
    let proofConfigurationSnapshot: OverlayConfigurationSnapshot

#if DEBUG
    private(set) var focusEvidence: [LabeledFocusSnapshot] = []
    private(set) var diagnosticHotKeyStatus = "Control-Option-H not registered"
#endif

    @ObservationIgnored private let overlayController: OverlayPanelController
    @ObservationIgnored private let privacyCoordinator: PrivacyCoordinator
    @ObservationIgnored private let topologyEvaluator = DisplayTopologyEvaluator()
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let effectHandler: @MainActor (AppEffect) -> Void
    @ObservationIgnored private var latestTopology: DisplayTopologySnapshot?
    @ObservationIgnored private var candidateFingerprint: DisplayFingerprint?
    @ObservationIgnored private var pendingClear: PendingClear?
    @ObservationIgnored private var pendingShieldedMoveDisplayID: UInt32?

    private struct PendingClear {
        enum Phase: Equatable {
            case confirmationRequired
            case awaitingPreClearFlush
        }

        let token: ClearToken
        let documentRevision: UInt64
        let snapshotRevision: UInt64
        var phase: Phase
    }

    init(
        overlayController: OverlayPanelController,
        privacyCoordinator: PrivacyCoordinator = PrivacyCoordinator(),
        document: ScriptDocument? = nil,
        now: @escaping @MainActor () -> Date = { Date() },
        restorationRequired: Bool = false,
        effectHandler: (@MainActor (AppEffect) -> Void)? = nil
    ) {
        self.overlayController = overlayController
        self.privacyCoordinator = privacyCoordinator
        self.now = now
        self.document = document ?? ScriptDocument(updatedAt: now())
        preferences = TeleprompterPreferences()
        overlaySession = OverlaySession()
        panelFrames = []
        shortcutBindings = Self.defaultShortcutBindings
        snapshotRevision = 0
        restorationCompleted = !restorationRequired
        isPersistenceLoadSafe = !restorationRequired
        proofConfigurationSnapshot = overlayController.configurationSnapshot
        self.effectHandler = effectHandler ?? { effect in
            Self.applyDefault(effect, overlayController: overlayController)
        }
    }

    var isPaused: Bool {
        overlaySession.playbackPhase == .paused
    }

    var isLocked: Bool {
        preferences.isLocked
    }

    var pendingClearToken: ClearToken? {
        pendingClear?.token
    }

    var isAwaitingPreClearFlush: Bool {
        pendingClear?.phase == .awaitingPreClearFlush
    }

    var selectedDisplayName: String {
        displays.first(where: { $0.id == selectedDisplayID })?.localizedName
            ?? "No display selected"
    }

    var configurationSnapshot: OverlayConfigurationSnapshot {
        overlayController.configurationSnapshot
    }

    func send(_ command: AppCommand) {
        guard acceptsDuringTermination(command) else { return }
        commandDispatchCount += 1
        switch command {
        case let .replaceScript(text):
            replaceScript(text)
        case .requestClear:
            requestClear()
        case let .confirmClear(token):
            confirmClear(token)
        case .cancelClear:
            pendingClear = nil
        case let .completePreClearFlush(token, persistedRevision, succeeded):
            completePreClearFlush(
                token: token,
                persistedRevision: persistedRevision,
                succeeded: succeeded
            )
        case .start:
            startPlayback()
        case .pause:
            overlaySession.playbackPhase = .paused
        case .togglePlayback:
            if overlaySession.playbackPhase == .playing {
                overlaySession.playbackPhase = .paused
            } else {
                startPlayback()
            }
        case .restart:
            restart()
        case .showOverlay:
            showOverlayCommand()
        case .hideOverlay:
            hideOverlayCommand()
        case let .setLocked(locked):
            setLockedCommand(locked)
        case let .restore(snapshot):
            restore(snapshot)
        case .restoreFailed:
            restoreFailed()
        case .flushPersistence:
            effectHandler(.flushPersistence)
        case .topologyWillChange:
            pendingShieldedMoveDisplayID = nil
            emit(applyPrivacyDirectives(privacyCoordinator.topologyWillChange()))
        case let .displayInventoryLoaded(inventory):
            refreshDisplayInventory(inventory)
        case .displayInventoryFailed:
            refreshDisplayInventoryFailed()
        case let .selectDisplay(id):
            selectDisplayCommand(id)
        case .confirmSelectedDisplay:
            confirmSelectedDisplayCommand()
        case let .completeShieldedMove(screenID):
            completeShieldedMove(screenID: screenID)
        case .keepScriptHidden:
            keepScriptHiddenCommand()
        }
    }

    func beginTerminationQuiescence() {
        isTerminationQuiescing = true
    }

    // MARK: - Milestone 0 mechanical compatibility

    func refreshDisplays(_ result: Result<[RuntimeDisplay], Error>) {
        switch result {
        case let .success(displays):
            send(.displayInventoryLoaded(RuntimeDisplayInventory(displays: displays)))
        case .failure:
            send(.displayInventoryFailed)
        }
    }

    func refreshDisplayInventory(_ result: Result<RuntimeDisplayInventory, Error>) {
        switch result {
        case let .success(inventory):
            send(.displayInventoryLoaded(inventory))
        case .failure:
            send(.displayInventoryFailed)
        }
    }

    func topologyWillChange() {
        send(.topologyWillChange)
    }

    func selectDisplay(_ id: UInt32?) {
        send(.selectDisplay(id))
    }

    func confirmSelectedDisplay() {
        send(.confirmSelectedDisplay)
    }

    func keepScriptHidden() {
        send(.keepScriptHidden)
    }

    func showOverlay() {
        send(.showOverlay)
    }

    func hideOverlay() {
        send(.hideOverlay)
#if DEBUG
        captureFocus(label: "after hide")
#endif
    }

    func setLocked(_ locked: Bool) {
        send(.setLocked(locked))
#if DEBUG
        captureFocus(label: locked ? "after lock" : "after unlock")
#endif
    }

#if DEBUG
    func setDiagnosticHotKeyStatus(_ status: Int32) {
        diagnosticHotKeyStatus = status == 0
            ? "Control-Option-H registered"
            : "Control-Option-H registration failed (OSStatus \(status))"
    }

    func toggleOverlayFromDiagnosticHotKey() {
        if overlaySession.visibility == .visible {
            send(.hideOverlay)
        } else {
            send(.showOverlay)
        }
    }

    func captureFocus(label: String) {
        focusEvidence.append(
            LabeledFocusSnapshot(
                label: label,
                snapshot: WorkspaceFocusProbe.capture(
                    panel: overlayController.teleprompterPanel
                )
            )
        )
    }

    var diagnosticSummary: String {
        let configuration = proofConfigurationSnapshot
        let configurationLine = [
            "level=\(configuration.level)",
            "panels=\(configuration.panelCount)",
            "borderless=\(configuration.isBorderless)",
            "nonactivating=\(configuration.isNonactivating)",
            "resizable=\(configuration.isNativelyResizable)",
            "allSpaces=\(configuration.joinsAllSpaces)",
            "fullScreenAuxiliary=\(configuration.isFullScreenAuxiliary)",
            "opaqueInterior=\(configuration.interiorIsFullyOpaque)",
        ].joined(separator: " | ")
        guard !focusEvidence.isEmpty else {
            return configurationLine + "\n" + diagnosticHotKeyStatus + "\nNo focus capture yet"
        }
        let focusLines = focusEvidence.suffix(8).map { record in
            let focus = record.snapshot
            return [
                record.label,
                "pid=\(focus.processIdentifier.map { String($0) } ?? "nil")",
                "bundle=\(focus.bundleIdentifier ?? "nil")",
                "panelKey=\(focus.panelIsKey)",
                "panelMain=\(focus.panelIsMain)",
            ].joined(separator: " | ")
        }
        return ([configurationLine, diagnosticHotKeyStatus] + focusLines)
            .joined(separator: "\n")
    }
#endif

    // MARK: - Durable state reducer

    private func replaceScript(_ text: String) {
        guard text != document.text else { return }
        localError = nil
        invalidatePendingClearForDurableChange()
        document.text = text
        document.revision += 1
        document.updatedAt = now()
        overlaySession.readingAnchor = overlaySession.readingAnchor.clamped(to: text)
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
    }

    private func requestClear() {
        guard !document.text.isEmpty else { return }
        pendingClear = PendingClear(
            token: .issue(),
            documentRevision: document.revision,
            snapshotRevision: snapshotRevision,
            phase: .confirmationRequired
        )
    }

    private func confirmClear(_ token: ClearToken) {
        guard
            var request = pendingClear,
            request.token == token,
            request.phase == .confirmationRequired,
            request.documentRevision == document.revision,
            request.snapshotRevision == snapshotRevision
        else { return }
        request.phase = .awaitingPreClearFlush
        pendingClear = request
        effectHandler(.flushSnapshot(
            token: token,
            requiredRevision: request.snapshotRevision
        ))
    }

    private func completePreClearFlush(
        token: ClearToken,
        persistedRevision: UInt64,
        succeeded: Bool
    ) {
        guard
            let request = pendingClear,
            request.token == token,
            request.phase == .awaitingPreClearFlush,
            request.documentRevision == document.revision,
            request.snapshotRevision == snapshotRevision
        else { return }

        guard succeeded, persistedRevision == request.snapshotRevision else {
            pendingClear = nil
            localError = .preClearFlushFailed
            return
        }

        pendingClear = nil
        localError = nil
        document.text = ""
        document.revision += 1
        document.updatedAt = now()
        snapshotRevision += 1
        overlaySession.readingAnchor = ReadingAnchor()
        overlaySession.pixelOffset = 0
        overlaySession.playbackPhase = .paused
        effectHandler(.saveSnapshotImmediately(snapshot()))
    }

    private func startPlayback() {
        guard !document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            overlaySession.playbackPhase = .paused
            return
        }
        overlaySession.playbackPhase = .playing
    }

    private func restart() {
        localError = nil
        invalidatePendingClearForDurableChange()
        overlaySession.playbackPhase = .paused
        overlaySession.readingAnchor = ReadingAnchor()
        overlaySession.pixelOffset = 0
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
        effectHandler(.resetViewport)
    }

    private func restore(_ persistedSnapshot: PersistedSnapshot?) {
        if let persistedSnapshot {
            document = persistedSnapshot.document
            preferences = persistedSnapshot.preferences
            panelFrames = persistedSnapshot.panelFrames
            shortcutBindings = persistedSnapshot.shortcutBindings
            snapshotRevision = persistedSnapshot.revision
            overlaySession = RestoredState(snapshot: persistedSnapshot).overlaySession
            candidateFingerprint = preferences.selectedDisplayFingerprint
        } else {
            overlaySession = OverlaySession()
            candidateFingerprint = preferences.selectedDisplayFingerprint
        }
        restorationCompleted = true
        isPersistenceLoadSafe = true
        displays = []
        latestTopology = nil
        selectedDisplayID = nil
        isSelectionConfirmed = false
        isShielded = true
        warning = nil
        localError = nil
        pendingClear = nil
        pendingShieldedMoveDisplayID = nil
        emit([
            .reassessPrivacy,
            .setPanelLocked(preferences.isLocked),
        ])
    }

    private func restoreFailed() {
        restorationCompleted = true
        isPersistenceLoadSafe = false
        overlaySession = OverlaySession()
        displays = []
        latestTopology = nil
        selectedDisplayID = nil
        candidateFingerprint = preferences.selectedDisplayFingerprint
        isSelectionConfirmed = false
        isShielded = true
        warning = Self.queryFailureWarning
        localError = .snapshotLoadFailed
        pendingClear = nil
        pendingShieldedMoveDisplayID = nil
        emit([.reassessPrivacy, .setPanelLocked(preferences.isLocked)])
    }

    private func snapshot() -> PersistedSnapshot {
        PersistedSnapshot(
            revision: snapshotRevision,
            document: document,
            readingAnchor: overlaySession.readingAnchor,
            preferences: preferences,
            panelFrames: panelFrames,
            shortcutBindings: shortcutBindings
        )
    }

    // MARK: - Display/privacy reducer

    private func refreshDisplayInventory(_ inventory: RuntimeDisplayInventory) {
        isSelectionConfirmed = false
        displays = inventory.displays
        latestTopology = inventory.topology
        var effects = applyPrivacyDirectives(
            privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
        )

        let evaluation = topologyEvaluator.evaluate(
            snapshot: inventory.topology,
            selection: unconfirmedSelection()
        )
        warning = warningMessage(for: evaluation.assessment)
        if let candidate = evaluation.candidate,
           let runtimeDisplay = displays.first(where: { $0.id == candidate.sessionID }) {
            selectedDisplayID = candidate.sessionID
            candidateFingerprint = candidate.fingerprint
            effects.append(.stagePanelHidden(runtimeDisplay))
            effects.append(.moveControllerWhileShielded(runtimeDisplay))
        } else {
            selectedDisplayID = nil
            candidateFingerprint = nil
        }
        emit(effects)
    }

    private func refreshDisplayInventoryFailed() {
        displays = []
        selectedDisplayID = nil
        candidateFingerprint = nil
        latestTopology = nil
        let effects = applyPrivacyDirectives(
            privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
        )
        warning = Self.queryFailureWarning
        emit(effects)
    }

    private func selectDisplayCommand(_ id: UInt32?) {
        isSelectionConfirmed = false
        isShielded = true
        overlaySession.visibility = .hidden
        overlaySession.currentSessionDisplayID = nil
        overlaySession.recoveryConfirmationState = .required
        pendingShieldedMoveDisplayID = nil
        var effects: [AppEffect] = [.hidePanel]
        selectedDisplayID = id
        guard
            let id,
            let display = displays.first(where: { $0.id == id }),
            let descriptor = latestTopology?.displays.first(where: { $0.sessionID == id })
        else {
            candidateFingerprint = nil
            emit(effects)
            return
        }
        candidateFingerprint = descriptor.fingerprint
        if let latestTopology {
            let evaluation = topologyEvaluator.evaluate(
                snapshot: latestTopology,
                selection: unconfirmedSelection()
            )
            warning = warningMessage(for: evaluation.assessment)
            if display.isOnline {
                effects.append(.stagePanelHidden(display))
            }
        }
        emit(effects)
    }

    private func confirmSelectedDisplayCommand() {
        guard
            isPersistenceLoadSafe,
            let latestTopology,
            let selection = confirmedSelection(),
            let selectedDisplayID,
            displays.contains(where: { $0.id == selectedDisplayID })
        else {
            isSelectionConfirmed = false
            isShielded = true
            return
        }
        let evaluation = topologyEvaluator.evaluate(
            snapshot: latestTopology,
            selection: selection
        )
        guard
            evaluation.canOpenOverlay,
            evaluation.candidate?.sessionID == selectedDisplayID
        else {
            isSelectionConfirmed = false
            isShielded = true
            warning = warningMessage(for: evaluation.assessment)
            return
        }

        overlaySession.currentSessionDisplayID = selectedDisplayID
        overlaySession.recoveryConfirmationState = .confirmed
        isSelectionConfirmed = true
        let directives = privacyCoordinator.topologyWasEvaluated(
            confirmedSafeScreenID: selectedDisplayID,
            isSafe: true
        )
        var effects = applyPrivacyDirectives(directives)
        warning = warningMessage(for: evaluation.assessment)
        pendingShieldedMoveDisplayID = selectedDisplayID

        if preferences.selectedDisplayFingerprint != candidateFingerprint {
            invalidatePendingClearForDurableChange()
            preferences.selectedDisplayFingerprint = candidateFingerprint
            snapshotRevision += 1
            effects.append(.scheduleSnapshot(snapshot()))
        }
        emit(effects)
    }

    private func completeShieldedMove(screenID: UInt32) {
        guard
            isPersistenceLoadSafe,
            pendingShieldedMoveDisplayID == screenID,
            selectedDisplayID == screenID,
            isSelectionConfirmed,
            overlaySession.recoveryConfirmationState == .confirmed
        else { return }
        pendingShieldedMoveDisplayID = nil
        isShielded = false
    }

    private func keepScriptHiddenCommand() {
        isSelectionConfirmed = false
        isShielded = true
        overlaySession.visibility = .hidden
        overlaySession.playbackPhase = .paused
        overlaySession.currentSessionDisplayID = nil
        overlaySession.recoveryConfirmationState = .required
        pendingShieldedMoveDisplayID = nil
        emit([.hidePanel])
    }

    private func showOverlayCommand() {
        guard
            restorationCompleted,
            isPersistenceLoadSafe,
            isSelectionConfirmed,
            !isShielded,
            pendingShieldedMoveDisplayID == nil,
            overlaySession.recoveryConfirmationState == .confirmed,
            let latestTopology,
            let selection = confirmedSelection(),
            let selectedDisplayID,
            let display = displays.first(where: { $0.id == selectedDisplayID })
        else { return }
        let evaluation = topologyEvaluator.evaluate(
            snapshot: latestTopology,
            selection: selection
        )
        guard evaluation.canOpenOverlay,
              evaluation.candidate?.sessionID == selectedDisplayID else { return }
        pendingShowGeneration += 1
        overlaySession.visibility = .visible
#if DEBUG
        captureFocus(label: "before show")
#endif
        effectHandler(.showPanel(display))
#if DEBUG
        captureFocus(label: "after show")
#endif
    }

    private func hideOverlayCommand() {
        overlaySession.visibility = .hidden
        effectHandler(.hidePanel)
    }

    private func setLockedCommand(_ locked: Bool) {
        guard preferences.isLocked != locked else { return }
        invalidatePendingClearForDurableChange()
        preferences.isLocked = locked
        snapshotRevision += 1
        emit([.setPanelLocked(locked), .scheduleSnapshot(snapshot())])
    }

    private func applyPrivacyDirectives(_ directives: [PrivacyDirective]) -> [AppEffect] {
        var externalEffects: [AppEffect] = []
        for directive in directives {
            switch directive {
            case .pauseScrolling:
                overlaySession.playbackPhase = .paused
            case .hideOverlay:
                overlaySession.visibility = .hidden
                externalEffects.append(.hidePanel)
            case .shieldController:
                isShielded = true
            case .invalidatePendingShow:
                pendingShowGeneration += 1
            case .queryTopology:
                externalEffects.append(.queryTopology)
            case .evaluatePrivacy:
                externalEffects.append(.evaluatePrivacy)
            case let .moveWindowsWhileShielded(screenID):
                if let display = displays.first(where: { $0.id == screenID }) {
                    externalEffects.append(.stagePanelHidden(display))
                    externalEffects.append(.moveControllerWhileShielded(display))
                }
            case .requestConfirmation:
                isSelectionConfirmed = false
                pendingShieldedMoveDisplayID = nil
                overlaySession.currentSessionDisplayID = nil
                overlaySession.recoveryConfirmationState = .required
            case .publishSafeState:
                break
            }
        }
        return externalEffects
    }

    private func unconfirmedSelection() -> DisplaySelection? {
        guard let fingerprint = candidateFingerprint
            ?? preferences.selectedDisplayFingerprint else { return nil }
        return DisplaySelection(
            fingerprint: fingerprint,
            isConfirmed: false,
            isConfirmedInCurrentSession: false,
            currentSessionID: selectedDisplayID
        )
    }

    private func confirmedSelection() -> DisplaySelection? {
        guard let fingerprint = candidateFingerprint
            ?? preferences.selectedDisplayFingerprint else { return nil }
        return DisplaySelection(
            fingerprint: fingerprint,
            isConfirmed: true,
            isConfirmedInCurrentSession: true,
            currentSessionID: selectedDisplayID
        )
    }

    private func warningMessage(for assessment: DisplayPrivacyAssessment) -> String? {
        switch assessment {
        case .blockedMirroring:
            Self.mirroringWarning
        case .ambiguousIdentity:
            Self.ambiguityWarning
        case .systemQueryFailed:
            Self.queryFailureWarning
        case .singleDisplayNoAudienceSeparation:
            Self.noSeparationWarning
        case .selectedDisplayMissing:
            "The selected private display is missing. Confirm a safe display before showing."
        case .selectionRequired:
            "Select and confirm the display only you can see."
        case .confirmationRequired, .safeCandidate:
            nil
        }
    }

    private static var defaultShortcutBindings: [ShortcutBinding] {
        KeyboardShortcut.defaultMap.map {
            ShortcutBinding(action: $0.key, shortcut: $0.value)
        }.sorted { $0.action.rawValue < $1.action.rawValue }
    }

    private func acceptsDuringTermination(_ command: AppCommand) -> Bool {
        guard isTerminationQuiescing else { return true }
        switch command {
        case .completePreClearFlush, .pause, .hideOverlay, .flushPersistence,
             .topologyWillChange, .displayInventoryLoaded, .displayInventoryFailed,
             .keepScriptHidden, .completeShieldedMove:
            return true
        case .replaceScript, .requestClear, .confirmClear, .cancelClear,
             .start, .togglePlayback, .restart, .showOverlay, .setLocked,
             .restore, .restoreFailed, .selectDisplay, .confirmSelectedDisplay:
            return false
        }
    }

    private func invalidatePendingClearForDurableChange() {
        if pendingClear?.phase == .awaitingPreClearFlush {
            localError = .clearRequestInvalidated
        }
        pendingClear = nil
    }

    private func emit(_ effects: [AppEffect]) {
        for effect in effects {
            effectHandler(effect)
        }
    }

    private static func applyDefault(
        _ effect: AppEffect,
        overlayController: OverlayPanelController
    ) {
        switch effect {
        case let .stagePanelHidden(display):
            overlayController.stageHidden(
                proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame
            )
        case let .showPanel(display):
            overlayController.show(
                proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame
            )
        case .hidePanel:
            overlayController.hide()
        case let .setPanelLocked(locked):
            overlayController.setLocked(locked)
        case .scheduleSnapshot, .flushSnapshot, .saveSnapshotImmediately,
             .flushPersistence, .moveControllerWhileShielded, .resetViewport,
             .reassessPrivacy, .queryTopology, .evaluatePrivacy:
            break
        }
    }

    // Explicit state setup seams used only to prove reducer invariants.
    func setReadingPositionForTesting(utf16Offset: Int, pixelOffset: Double) {
        overlaySession.readingAnchor = ReadingAnchor(
            utf16Offset: utf16Offset,
            document: document.text
        )
        overlaySession.pixelOffset = pixelOffset
    }

    func setCurrentSessionDisplayIdentityForTesting(_ id: UInt32, confirmed: Bool) {
        overlaySession.currentSessionDisplayID = id
        overlaySession.recoveryConfirmationState = confirmed ? .confirmed : .required
        isSelectionConfirmed = confirmed
    }
}
