import AppKit

@main
@MainActor
enum PrivatePresenterApplication {
    static func main() {
        let application = NSApplication.shared
        let runtime: AppRuntime
        #if DEBUG
        if ProcessInfo.processInfo.environment["PRIVATE_PRESENTER_EVIDENCE_COMMIT"] != nil {
            let resolution = DiagnosticProofConfiguration.resolve()
            let evidenceRecorder = DiagnosticEvidenceRecorder.production(resolution: resolution)
            runtime = AppRuntime(
                proofLevel: resolution.configuration.proofLevel,
                diagnosticConfiguration: resolution.configuration,
                diagnosticEvidenceRecorder: evidenceRecorder,
                enforcesDiagnosticControllerCohort: !resolution.faults.contains(
                    .configControllerCohortInvalid
                ),
                hotKeyStartupMode: .legacyDiagnostic
            )
        } else {
            runtime = AppRuntime(
                proofLevel: .statusBar,
                hotKeyStartupMode: .product
            )
        }
        #else
        runtime = AppRuntime(proofLevel: .statusBar)
        #endif
        let delegate = AppDelegate(runtime: runtime)
        application.setActivationPolicy(.regular)
        ApplicationMenuInstaller.install(on: application)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
enum ApplicationMenuInstaller {
    static func install(on application: NSApplication) {
        application.mainMenu = makeMainMenu()
    }

    static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Private Presenter")
        mainMenu.addItem(applicationMenuItem())
        mainMenu.addItem(editMenuItem())
        return mainMenu
    }

    private static func applicationMenuItem() -> NSMenuItem {
        let rootItem = NSMenuItem(title: "Private Presenter", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Private Presenter")
        menu.addItem(
            NSMenuItem(
                title: "About Private Presenter",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Hide Private Presenter",
                action: #selector(NSApplication.hide(_:)),
                keyEquivalent: "h"
            )
        )
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(
            NSMenuItem(
                title: "Show All",
                action: #selector(NSApplication.unhideAllApplications(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Private Presenter",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        rootItem.submenu = menu
        return rootItem
    }

    private static func editMenuItem() -> NSMenuItem {
        let rootItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Edit")
        menu.addItem(
            NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        )
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        )
        menu.addItem(
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        )
        menu.addItem(
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        )
        menu.addItem(
            NSMenuItem(
                title: "Select All",
                action: #selector(NSText.selectAll(_:)),
                keyEquivalent: "a"
            )
        )
        rootItem.submenu = menu
        return rootItem
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime: AppRuntime
    private var terminationTask: Task<Void, Never>?

    init(runtime: AppRuntime) {
        self.runtime = runtime
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        runtime.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else { return .terminateLater }
        terminationTask = Task { @MainActor [runtime, weak self] in
            let didFlush = await runtime.stopAndFlush()
            self?.terminationTask = nil
            sender.reply(toApplicationShouldTerminate: didFlush)
        }
        return .terminateLater
    }
}
