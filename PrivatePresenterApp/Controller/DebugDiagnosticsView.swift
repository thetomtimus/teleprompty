import SwiftUI

#if DEBUG
@MainActor
struct DebugDiagnosticsView: View {
    @Bindable var model: AppModel

    var body: some View {
        DisclosureGroup("DEBUG diagnostics") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Control-Option-H toggles panel visibility. Control-Option-L toggles lock.")
                Button("Capture Focus Snapshot") {
                    model.captureFocus(label: "manual capture")
                }
                Text(model.diagnosticSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(.top, 6)
        }
    }
}
#endif
