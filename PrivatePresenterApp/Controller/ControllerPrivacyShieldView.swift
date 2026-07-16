import SwiftUI

struct ControllerPrivacyShieldView: View {
    @AccessibilityFocusState private var safetyStatusFocused: Bool
    @State private var lastFocusedUnsafeGeneration: Int?

    let displays: [RuntimeDisplay]
    @Binding var selectedDisplayID: UInt32?
    let topologyStatus: ControllerTopologyStatus
    let warning: String?
    let unsafeGeneration: Int
    let controllerIsActive: Bool
    let onConfirm: () -> Void
    let onKeepHidden: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your private presenter display")
                .font(.title2.bold())
            Text(
                "Select the display only you can see. Private Presenter will keep the script editor hidden and the teleprompter closed until you confirm. Do not select the projector or audience display."
            )
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: safetyIconName)
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.displaySafetyIcon")
                    )
                Text("Display safety: \(PresenterAccessibility.genericSafetyState(topologyStatus))")
                    .foregroundStyle(.secondary)
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.displaySafetyStatus")
                    )
                    .accessibilityFocused($safetyStatusFocused)
            }

            if let warning {
                Text(warning)
                    .font(.headline)
                    .accessibilityLabel(warning)
                if warning == AppModel.mirroringWarning {
                    Text(ControllerPresentation.mirroringRecoveryGuidance)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Private display", selection: $selectedDisplayID) {
                Text("Select a display").tag(UInt32?.none)
                ForEach(displays) { display in
                    Text(display.localizedName).tag(Optional(display.id))
                }
            }
            .presenterAccessibility(
                accessibilityEntry("privatePresenter.privateDisplayPicker")
            )

            HStack {
                Button("Confirm \"\(selectedName)\" as Private", action: onConfirm)
                    .disabled(selectedDisplayID == nil)
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.confirmPrivateDisplay")
                    )
                Button("Keep Script Hidden", action: onKeepHidden)
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.keepScriptHidden")
                    )
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 280)
        .onAppear { updateSafetyFocus(generation: unsafeGeneration) }
        .onChange(of: unsafeGeneration) { _, generation in
            updateSafetyFocus(generation: generation)
        }
    }

    private var selectedName: String {
        displays.first(where: { $0.id == selectedDisplayID })?.localizedName ?? "display"
    }

    private var accessibilityState: PresenterAccessibility.State {
        PresenterAccessibility.State(
            scriptTitle: "",
            scriptText: "",
            displayName: selectedDisplayID == nil ? "" : selectedName,
            fontSizePoints: 42,
            speedPointsPerSecond: 60,
            alignment: .center,
            isActiveBandEnabled: true,
            isPlaying: false,
            isVisible: false,
            isLocked: true,
            isFocusModeEnabled: true,
            retryShortcutsVisible: false,
            topologyStatus: topologyStatus
        )
    }

    private var isUnsafe: Bool {
        warning != nil || topologyStatus != .extended
    }

    private var safetyIconName: String {
        isUnsafe ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
    }

    private func accessibilityEntry(
        _ identifier: String
    ) -> PresenterAccessibility.Entry {
        PresenterAccessibility.entry(identifier, state: accessibilityState)
    }

    private func updateSafetyFocus(generation: Int) {
        guard isUnsafe else { return }
        let decision = PresenterAccessibility.warningFocusDecision(
            unsafeGeneration: generation,
            lastFocusedGeneration: lastFocusedUnsafeGeneration,
            controllerIsActive: controllerIsActive
        )
        guard decision.shouldMoveFocus else { return }
        lastFocusedUnsafeGeneration = decision.consumedGeneration
        safetyStatusFocused = true
    }
}
