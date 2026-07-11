import SwiftUI

struct ControllerView: View {
    @Bindable var model: DiagnosticHarnessModel

    var body: some View {
        if model.isShielded {
            ControllerPrivacyShieldView(
                displays: model.displays,
                selectedDisplayID: Binding(
                    get: { model.selectedDisplayID },
                    set: { model.selectDisplay($0) }
                ),
                warning: model.warning,
                onConfirm: model.confirmSelectedDisplay,
                onKeepHidden: model.keepScriptHidden
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Milestone 0 overlay proof")
                    .font(.title2.bold())
                Text("Selected private display: \(model.selectedDisplayName)")
                Text("Use these controls only for the real Mac / Keynote / projector gate.")
                    .foregroundStyle(.secondary)
                Text("Private M0 proof content: this line must disappear behind the privacy shield.")
                    .font(.headline)
                HStack {
                    Button("Show", action: model.showOverlay)
                    Button(model.isLocked ? "Unlock" : "Lock") {
                        model.setLocked(!model.isLocked)
                    }
                    Button("Hide", action: model.hideOverlay)
                }
#if DEBUG
                Button("Capture Focus Snapshot") {
                    model.captureFocus(label: "manual capture")
                }
                Text(model.diagnosticSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
#endif
            }
            .padding(24)
            .frame(minWidth: 520, minHeight: 280)
        }
    }
}
