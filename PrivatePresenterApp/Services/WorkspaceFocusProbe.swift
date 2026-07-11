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
}
#endif
