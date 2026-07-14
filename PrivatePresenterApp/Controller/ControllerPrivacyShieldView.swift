import SwiftUI

struct ControllerPrivacyShieldView: View {
    let displays: [RuntimeDisplay]
    @Binding var selectedDisplayID: UInt32?
    let topologyStatus: ControllerTopologyStatus
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

            Text(ControllerPresentation.topologyLabel(for: topologyStatus))
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "Display safety: \(ControllerPresentation.topologyLabel(for: topologyStatus))"
                )

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

            HStack {
                Button("Confirm \"\(selectedName)\" as Private", action: onConfirm)
                    .disabled(selectedDisplayID == nil)
                Button("Keep Script Hidden", action: onKeepHidden)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 280)
    }

    private var selectedName: String {
        displays.first(where: { $0.id == selectedDisplayID })?.localizedName ?? "display"
    }
}
