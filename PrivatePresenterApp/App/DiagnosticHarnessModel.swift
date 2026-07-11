import AppKit
import Observation
import TeleprompterCore

@MainActor
@Observable
final class DiagnosticHarnessModel {
    static let mirroringWarning =
        "Display mirroring is on. Students may see the teleprompter. Use Extended Display mode."
    static let queryFailureWarning =
        "Display safety could not be verified. Your script is hidden and the teleprompter is closed."
    static let ambiguityWarning =
        "Private Presenter cannot reliably distinguish these displays. Select and confirm the display only you can see."
    static let noSeparationWarning =
        "No separate audience display protection."

    private(set) var displays: [RuntimeDisplay] = []
    var selectedDisplayID: UInt32?
    private(set) var isSelectionConfirmed = false
    private(set) var isShielded = true
    private(set) var isPaused = true
    private(set) var isLocked = false
    private(set) var warning: String?
    private(set) var pendingShowGeneration = 0
    let proofConfigurationSnapshot: OverlayConfigurationSnapshot

#if DEBUG
    private(set) var focusEvidence: [LabeledFocusSnapshot] = []
    private(set) var diagnosticHotKeyStatus = "Control-Option-H not registered"
#endif

    private let overlayController: OverlayPanelController
    private let privacyCoordinator: PrivacyCoordinator
    private let topologyEvaluator = DisplayTopologyEvaluator()
    private var latestTopology: DisplayTopologySnapshot?
    private var selectedFingerprint: DisplayFingerprint?
    var onConfirmedDisplay: ((RuntimeDisplay) -> Void)?

    init(
        overlayController: OverlayPanelController,
        privacyCoordinator: PrivacyCoordinator = PrivacyCoordinator()
    ) {
        self.overlayController = overlayController
        self.privacyCoordinator = privacyCoordinator
        proofConfigurationSnapshot = overlayController.configurationSnapshot
        privacyCoordinator.setEffectHandler { [weak self] effect in
            self?.apply(effect)
        }
    }

    var selectedDisplayName: String {
        displays.first(where: { $0.id == selectedDisplayID })?.localizedName ?? "No display selected"
    }

    var configurationSnapshot: OverlayConfigurationSnapshot {
        overlayController.configurationSnapshot
    }

    func refreshDisplays(_ result: Result<[RuntimeDisplay], Error>) {
        refreshDisplayInventory(result.map(RuntimeDisplayInventory.init))
    }

    func refreshDisplayInventory(_ result: Result<RuntimeDisplayInventory, Error>) {
        isSelectionConfirmed = false
        switch result {
        case let .success(inventory):
            displays = inventory.displays
            latestTopology = inventory.topology
            _ = privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
            let evaluation = topologyEvaluator.evaluate(
                snapshot: inventory.topology,
                selection: unconfirmedSelection()
            )
            warning = warningMessage(for: evaluation.assessment)
            if let candidate = evaluation.candidate,
               let runtimeDisplay = displays.first(where: { $0.id == candidate.sessionID }) {
                selectedDisplayID = candidate.sessionID
                selectedFingerprint = candidate.fingerprint
                stageHidden(on: runtimeDisplay)
            } else {
                selectedDisplayID = nil
            }

        case .failure:
            displays = []
            selectedDisplayID = nil
            selectedFingerprint = nil
            latestTopology = nil
            _ = privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
            warning = Self.queryFailureWarning
        }
    }

    func topologyWillChange() {
        isSelectionConfirmed = false
        _ = privacyCoordinator.topologyWillChange()
    }

    func selectDisplay(_ id: UInt32?) {
        isSelectionConfirmed = false
        isShielded = true
        overlayController.hide()
        selectedDisplayID = id
        guard
            let id,
            let display = displays.first(where: { $0.id == id }),
            let descriptor = latestTopology?.displays.first(where: { $0.sessionID == id })
        else {
            selectedFingerprint = nil
            return
        }
        selectedFingerprint = descriptor.fingerprint
        if let latestTopology {
            let evaluation = topologyEvaluator.evaluate(
                snapshot: latestTopology,
                selection: unconfirmedSelection()
            )
            warning = warningMessage(for: evaluation.assessment)
            if display.isOnline {
                stageHidden(on: display)
            }
        }
    }

    func confirmSelectedDisplay() {
        guard
            let latestTopology,
            let selection = confirmedSelection(),
            let selectedDisplayID
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
            evaluation.candidate?.sessionID == selectedDisplayID,
            displays.contains(where: { $0.id == selectedDisplayID })
        else {
            isSelectionConfirmed = false
            isShielded = true
            warning = warningMessage(for: evaluation.assessment)
            return
        }
        _ = privacyCoordinator.topologyWasEvaluated(
            confirmedSafeScreenID: selectedDisplayID,
            isSafe: true
        )
        isSelectionConfirmed = true
        warning = warningMessage(for: evaluation.assessment)
        isShielded = false
    }

    func keepScriptHidden() {
        isSelectionConfirmed = false
        isShielded = true
        overlayController.hide()
    }

    func showOverlay() {
        guard
            isSelectionConfirmed,
            !isShielded,
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
#if DEBUG
        captureFocus(label: "before show")
#endif
        pendingShowGeneration += 1
        overlayController.show(
            proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
            on: display.visibleFrame
        )
#if DEBUG
        captureFocus(label: "after show")
#endif
    }

    func hideOverlay() {
        overlayController.hide()
#if DEBUG
        captureFocus(label: "after hide")
#endif
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
        overlayController.setLocked(locked)
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
        if overlayController.teleprompterPanel.isVisible {
            hideOverlay()
        } else {
            showOverlay()
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
        return (
            [configurationLine, diagnosticHotKeyStatus] + focusLines
        ).joined(separator: "\n")
    }
#endif

    private func stageHidden(on display: RuntimeDisplay) {
        overlayController.stageHidden(
            proposedFrame: overlayController.defaultFrame(on: display.visibleFrame),
            on: display.visibleFrame
        )
    }

    private func apply(_ effect: PrivacyEffect) {
        switch effect {
        case .pauseScrolling:
            isPaused = true
        case .hideOverlay:
            overlayController.hide()
        case .shieldController:
            isShielded = true
        case .invalidatePendingShow:
            pendingShowGeneration += 1
        case .queryTopology, .evaluatePrivacy:
            break
        case let .moveWindowsWhileShielded(screenID):
            if let display = displays.first(where: { $0.id == screenID }) {
                stageHidden(on: display)
                onConfirmedDisplay?(display)
            }
        case .requestConfirmation:
            isSelectionConfirmed = false
        case .publishSafeState:
            // Publishing a safe assessment never reveals content. Only the explicit
            // confirmation action above may lower the shield.
            break
        }
    }

    private func unconfirmedSelection() -> DisplaySelection? {
        guard let selectedFingerprint else { return nil }
        return DisplaySelection(
            fingerprint: selectedFingerprint,
            isConfirmed: false,
            isConfirmedInCurrentSession: false,
            currentSessionID: selectedDisplayID
        )
    }

    private func confirmedSelection() -> DisplaySelection? {
        guard let selectedFingerprint else { return nil }
        return DisplaySelection(
            fingerprint: selectedFingerprint,
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
}
