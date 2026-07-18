import AppKit
import SwiftUI
import TeleprompterCore

@MainActor
struct ControllerView: View {
    @Bindable var model: AppModel
    let performanceRegistry: PerformanceIntervalRegistry
    let restorePerformanceGate: RestoreInteractivePerformanceGate?
    @State private var clearToken: ClearToken?

    var body: some View {
        VStack(spacing: 0) {
            if model.isShielded {
                ControllerPrivacyShieldView(
                    displays: model.displays,
                    selectedDisplayID: Binding(
                        get: { model.selectedDisplayID },
                        set: { model.selectDisplay($0) }
                    ),
                    topologyStatus: model.topologyStatus,
                    warning: model.warning,
                    unsafeGeneration: model.pendingShowGeneration,
                    controllerIsActive: NSApp.isActive,
                    onConfirm: model.confirmSelectedDisplay,
                    onKeepHidden: model.keepScriptHidden
                )
            } else {
                productController
            }
            globalShortcutStatus
        }
    }

    private var presentation: ControllerPresentation {
        ControllerPresentation(
            scriptText: model.document.text,
            isPanelVisible: model.overlaySession.visibility == .visible,
            isClearConfirmationRequired: clearToken != nil
        )
    }

    private var accessibilityState: PresenterAccessibility.State {
        PresenterAccessibility.state(model: model)
    }

    private func accessibilityEntry(
        _ identifier: String
    ) -> PresenterAccessibility.Entry {
        PresenterAccessibility.entry(identifier, state: accessibilityState)
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
                .presenterAccessibility(
                    accessibilityEntry("privatePresenter.scriptTitle")
                )

                if let instruction = presentation.emptyInstruction {
                    Text(instruction)
                        .foregroundStyle(.secondary)
                }

                TextField(
                    "Script editor",
                    text: scriptTextBinding,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(12...24)
                .presenterAccessibility(
                    accessibilityEntry("privatePresenter.scriptEditor")
                )
                .frame(minHeight: 300)
                .onAppear { restorePerformanceGate?.editorReady() }

                HStack {
                    Button(presentation.openCloseLabel) { dispatch(.openClose) }
                        .presenterAccessibility(
                            accessibilityEntry("privatePresenter.openClose")
                        )
                    Button(presentation.hideShowLabel) { dispatch(.hideShow) }
                        .presenterAccessibility(
                            accessibilityEntry("privatePresenter.hideShow")
                        )
                    Button(model.isLocked ? "Unlock" : "Lock") {
                        model.setLocked(!model.isLocked)
                    }
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.lock")
                    )
                    Spacer()
                    Button("Clear", role: .destructive) {
                        model.send(.requestClear)
                        clearToken = model.pendingClearToken
                    }
                    .disabled(!presentation.isEnabled(.clear))
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.clear")
                    )
                }

                Divider()

                HStack {
                    Text("Font size")
                    Stepper(
                        onIncrement: { model.send(.increaseFontSize) },
                        onDecrement: { model.send(.decreaseFontSize) }
                    ) { EmptyView() }
                    .labelsHidden()
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.fontSize")
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
                .presenterAccessibility(
                    accessibilityEntry("privatePresenter.alignment")
                )

                Toggle(
                    "Static active band",
                    isOn: Binding(
                        get: { model.preferences.isActiveBandEnabled },
                        set: { model.send(.setActiveBandEnabled($0)) }
                    )
                )
                .presenterAccessibility(
                    accessibilityEntry("privatePresenter.activeBand")
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
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.start")
                    )
                Button("Pause") { dispatch(.pause) }
                    .disabled(!presentation.isEnabled(.pause))
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.pause")
                    )
                Button("Restart") { dispatch(.restart) }
                    .disabled(!presentation.isEnabled(.restart))
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.restart")
                    )
                Button("Back") { dispatch(.back) }
                    .disabled(!presentation.isEnabled(.back))
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.back")
                    )
                Button("Forward") { dispatch(.forward) }
                    .disabled(!presentation.isEnabled(.forward))
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.forward")
                    )
            }
            HStack {
                Text("Speed")
                Stepper(
                    value: Binding(
                        get: { model.preferences.speedPointsPerSecond },
                        set: { model.send(.setSpeed($0)) }
                    ),
                    in: TeleprompterPreferences.speedRange,
                    step: TeleprompterPreferences.speedStep
                ) { EmptyView() }
                .labelsHidden()
                .disabled(!presentation.isEnabled(.speed))
                .presenterAccessibility(
                    accessibilityEntry("privatePresenter.speed")
                )
                Text("\(Int(model.preferences.speedPointsPerSecond)) pt/s")
                    .monospacedDigit()
            }
            Toggle(
                "Focus Mode",
                isOn: Binding(
                    get: { model.preferences.isFocusModeEnabled },
                    set: { model.send(.setFocusModeEnabled($0)) }
                )
            )
            .presenterAccessibility(
                accessibilityEntry("privatePresenter.focusMode")
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var globalShortcutStatus: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(globalShortcutStatusText)
                    .font(.caption)
                Text("Shortcut editing is unavailable until the controlled-Mac proof is accepted.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if canRetryGlobalShortcuts {
                Button("Retry") { model.send(.retryHotKeyRegistration) }
                    .presenterAccessibility(
                        accessibilityEntry("privatePresenter.retryShortcuts")
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityIdentifier("privatePresenter.globalShortcutStatus")
    }

    private var globalShortcutStatusText: String {
        ControllerPresentation.globalShortcutStatusText(model.hotKeyStatus)
    }

    private var scriptTextBinding: Binding<String> {
        Binding(
            get: { model.document.text },
            set: { replacement in
                let current = model.document.text
                guard let edit = try? ControllerTextEditing.minimalEdit(
                    from: current,
                    to: replacement,
                    baseRevision: model.document.revision
                ) else { return }
                performanceRegistry.beginEditToVisible(for: edit.revision)
                model.send(.applyScriptEdit(edit))
                performanceRegistry.endEditToVisible(
                    for: edit.revision,
                    outcome: .failure
                )
            }
        )
    }

    private var canRetryGlobalShortcuts: Bool {
        guard let status = model.hotKeyStatus else { return false }
        switch status {
        case .conflict, .degradedClean:
            return true
        case .committed, .cleanupUnknown, .invalid:
            return false
        }
    }

    private func dispatch(_ control: ControllerControl) {
        guard let command = presentation.productCommand(for: control) else { return }
        model.send(command)
    }
}

enum ControllerTextEditing {
    static func minimalEdit(
        from current: String,
        to replacement: String,
        baseRevision: UInt64
    ) throws -> ScriptTextEdit? {
        guard current != replacement else { return nil }

        let currentUTF16 = current.utf16
        let replacementUTF16 = replacement.utf16
        var currentPrefix = currentUTF16.startIndex
        var replacementPrefix = replacementUTF16.startIndex
        var prefixLength = 0

        while currentPrefix != currentUTF16.endIndex,
            replacementPrefix != replacementUTF16.endIndex,
            currentUTF16[currentPrefix] == replacementUTF16[replacementPrefix]
        {
            currentUTF16.formIndex(after: &currentPrefix)
            replacementUTF16.formIndex(after: &replacementPrefix)
            prefixLength += 1
        }

        if splitsSurrogatePair(at: currentPrefix, in: currentUTF16)
            || splitsSurrogatePair(at: replacementPrefix, in: replacementUTF16)
        {
            currentUTF16.formIndex(before: &currentPrefix)
            replacementUTF16.formIndex(before: &replacementPrefix)
            prefixLength -= 1
        }

        var currentSuffix = currentUTF16.endIndex
        var replacementSuffix = replacementUTF16.endIndex
        var suffixLength = 0
        while currentSuffix != currentPrefix,
            replacementSuffix != replacementPrefix
        {
            let precedingCurrent = currentUTF16.index(before: currentSuffix)
            let precedingReplacement = replacementUTF16.index(before: replacementSuffix)
            guard currentUTF16[precedingCurrent] == replacementUTF16[precedingReplacement]
            else { break }
            currentSuffix = precedingCurrent
            replacementSuffix = precedingReplacement
            suffixLength += 1
        }

        if splitsSurrogatePair(at: currentSuffix, in: currentUTF16)
            || splitsSurrogatePair(at: replacementSuffix, in: replacementUTF16)
        {
            currentUTF16.formIndex(after: &currentSuffix)
            replacementUTF16.formIndex(after: &replacementSuffix)
            suffixLength -= 1
        }

        let replacementLength = replacementUTF16.count - prefixLength - suffixLength
        let replacementText = (replacement as NSString).substring(
            with: NSRange(location: prefixLength, length: replacementLength)
        )
        return try ScriptTextEdit.replacing(
            in: current,
            range: UTF16TextRange(
                location: prefixLength,
                length: currentUTF16.count - prefixLength - suffixLength
            ),
            with: replacementText,
            baseRevision: baseRevision
        )
    }

    private static func splitsSurrogatePair(
        at index: String.UTF16View.Index,
        in utf16: String.UTF16View
    ) -> Bool {
        guard index != utf16.startIndex, index != utf16.endIndex else { return false }
        let previous = utf16[utf16.index(before: index)]
        let current = utf16[index]
        return (0xD800...0xDBFF).contains(previous)
            && (0xDC00...0xDFFF).contains(current)
    }
}
