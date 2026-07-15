import SwiftUI
import TeleprompterCore

@MainActor
struct ControllerView: View {
    @Bindable var model: AppModel
    @State private var clearToken: ClearToken?

    var body: some View {
        if model.isShielded {
            ControllerPrivacyShieldView(
                displays: model.displays,
                selectedDisplayID: Binding(
                    get: { model.selectedDisplayID },
                    set: { model.selectDisplay($0) }
                ),
                topologyStatus: model.topologyStatus,
                warning: model.warning,
                onConfirm: model.confirmSelectedDisplay,
                onKeepHidden: model.keepScriptHidden
            )
        } else {
            productController
        }
    }

    private var presentation: ControllerPresentation {
        ControllerPresentation(
            scriptText: model.document.text,
            isPanelVisible: model.overlaySession.visibility == .visible,
            isClearConfirmationRequired: clearToken != nil
        )
    }

    private var productController: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Private Presenter")
                    .font(.title.bold())
                Text(
                    ControllerPresentation.selectedDisplayStatus(
                        name: model.selectedDisplayName,
                        isConfirmedInCurrentSession: model.isSelectionConfirmed
                    )
                )
                    .foregroundStyle(.secondary)
                Text(ControllerPresentation.topologyLabel(for: model.topologyStatus))
                    .foregroundStyle(.secondary)

                TextField(
                    "Script title",
                    text: Binding(
                        get: { model.document.title },
                        set: { model.send(.setScriptTitle($0)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("privatePresenter.scriptTitle")

                if let instruction = presentation.emptyInstruction {
                    Text(instruction)
                        .foregroundStyle(.secondary)
                }

                ScriptEditorTextView(
                    text: model.document.text,
                    revision: model.document.revision,
                    onEdit: { model.send(.applyScriptEdit($0)) }
                )
                .frame(minHeight: 300)

                HStack {
                    Button(presentation.openCloseLabel) { dispatch(.openClose) }
                    Button(presentation.hideShowLabel) { dispatch(.hideShow) }
                    Button(model.isLocked ? "Unlock" : "Lock") {
                        model.setLocked(!model.isLocked)
                    }
                    Spacer()
                    Button("Clear", role: .destructive) {
                        model.send(.requestClear)
                        clearToken = model.pendingClearToken
                    }
                    .disabled(!presentation.isEnabled(.clear))
                }

                Divider()

                HStack {
                    Text("Font size")
                    Slider(
                        value: Binding(
                            get: { model.preferences.fontSizePoints },
                            set: { model.send(.setFontSize($0)) }
                        ),
                        in: 24...96,
                        step: 2
                    )
                    Text("\(Int(model.preferences.fontSizePoints)) pt")
                        .monospacedDigit()
                }

                Picker(
                    "Alignment",
                    selection: Binding(
                        get: { model.preferences.textAlignment },
                        set: { model.send(.setTextAlignment($0)) }
                    )
                ) {
                    Text("Left").tag(TeleprompterTextAlignment.left)
                    Text("Center").tag(TeleprompterTextAlignment.center)
                }
                .pickerStyle(.segmented)

                Toggle(
                    "Static active band",
                    isOn: Binding(
                        get: { model.preferences.isActiveBandEnabled },
                        set: { model.send(.setActiveBandEnabled($0)) }
                    )
                )

                rehearsalControls

                #if DEBUG
                DebugDiagnosticsView(model: model)
                #endif
            }
            .padding(24)
        }
        .frame(minWidth: 760, minHeight: 680)
        .confirmationDialog(
            "Clear this script?",
            isPresented: Binding(
                get: { clearToken != nil },
                set: { if !$0 { clearToken = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear Script", role: .destructive) {
                guard let clearToken else { return }
                model.send(.confirmClear(token: clearToken))
                self.clearToken = nil
            }
            Button("Cancel", role: .cancel) {
                model.send(.cancelClear)
                clearToken = nil
            }
        } message: {
            Text("Private Presenter saves the current script before clearing it.")
        }
    }

    private var rehearsalControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Start") { dispatch(.start) }
                    .disabled(!presentation.isEnabled(.start))
                Button("Pause") { dispatch(.pause) }
                    .disabled(!presentation.isEnabled(.pause))
                Button("Restart") { dispatch(.restart) }
                    .disabled(!presentation.isEnabled(.restart))
                Button("Back") { dispatch(.back) }
                    .disabled(!presentation.isEnabled(.back))
                Button("Forward") { dispatch(.forward) }
                    .disabled(!presentation.isEnabled(.forward))
            }
            HStack {
                Text("Speed")
                Slider(
                    value: Binding(
                        get: { model.preferences.speedPointsPerSecond },
                        set: { model.send(.setSpeed($0)) }
                    ),
                    in: TeleprompterPreferences.speedRange,
                    step: TeleprompterPreferences.speedStep
                )
                .disabled(!presentation.isEnabled(.speed))
                Text("\(Int(model.preferences.speedPointsPerSecond)) pt/s")
                    .monospacedDigit()
            }
            Toggle("Focus Mode", isOn: .constant(false)).disabled(true)
            Text(ControllerPresentation.m4Explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }

    private func dispatch(_ control: ControllerControl) {
        guard let command = presentation.productCommand(for: control) else { return }
        model.send(command)
    }
}
