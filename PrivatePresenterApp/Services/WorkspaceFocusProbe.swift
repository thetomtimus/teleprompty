#if DEBUG
import AppKit

struct WorkspaceFocusSnapshot: Equatable, Sendable {
    let processIdentifier: Int32?
    let bundleIdentifier: String?
    let panelIsKey: Bool
    let panelIsMain: Bool
}

struct LabeledFocusSnapshot: Equatable, Sendable {
    let label: String
    let snapshot: WorkspaceFocusSnapshot
}

@MainActor
enum WorkspaceFocusProbe {
    static func capture(panel: NSPanel) -> WorkspaceFocusSnapshot {
        let application = NSWorkspace.shared.frontmostApplication
        return WorkspaceFocusSnapshot(
            processIdentifier: application?.processIdentifier,
            bundleIdentifier: application?.bundleIdentifier,
            panelIsKey: panel.isKeyWindow,
            panelIsMain: panel.isMainWindow
        )
    }

    static func captureDiagnosticState(
        panel: NSPanel,
        controller: ControllerWindowController,
        controllerShielded: Bool
    ) -> DiagnosticFocusState {
        let application = NSWorkspace.shared.frontmostApplication
        return DiagnosticFocusState(
            frontmostProcessIdentifier: application?.processIdentifier,
            frontmostBundleIdentifier: application?.bundleIdentifier,
            applicationIsActive: NSApp.isActive,
            activationPolicy: activationPolicyName(NSApp.activationPolicy()),
            panel: panel.diagnosticState,
            controller: controller.window?.diagnosticState,
            controllerShowCount: controller.showCount,
            controllerShielded: controllerShielded
        )
    }

    private static func activationPolicyName(
        _ policy: NSApplication.ActivationPolicy
    ) -> String {
        switch policy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
        }
    }
}
#endif
