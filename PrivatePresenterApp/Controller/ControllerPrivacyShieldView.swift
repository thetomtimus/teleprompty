import SwiftUI

struct ControllerPrivacyShieldView: View {
    let displays: [RuntimeDisplay]
    @Binding var selectedDisplayID: UInt32?
    let warning: String?
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

            if let warning {
                Text(visibleWarning(warning))
                    .font(.headline)
                    .accessibilityLabel(visibleWarning(warning))
            }

            Picker("Private display", selection: $selectedDisplayID) {
                Text("Select a display").tag(UInt32?.none)
                ForEach(displays) { display in
                    Text(display.localizedName).tag(Optional(display.id))
                }
            }

            HStack {
                Button("Confirm \"\(selectedName)\" as Private", action: onConfirm)
                    .disabled(selectedDisplayID == nil)
                Button("Keep Script Hidden", action: onKeepHidden)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 280)
    }

    private func visibleWarning(_ warning: String) -> String {
        guard warning == DiagnosticHarnessModel.mirroringWarning else { return warning }
        return warning + " Your script is hidden until display privacy is confirmed again."
    }

    private var selectedName: String {
        displays.first(where: { $0.id == selectedDisplayID })?.localizedName ?? "display"
    }
}
