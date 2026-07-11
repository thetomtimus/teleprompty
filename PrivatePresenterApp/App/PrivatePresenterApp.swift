import AppKit

@main
@MainActor
enum PrivatePresenterApplication {
    static func main() {
        let application = NSApplication.shared
        let proofLevel: OverlayPanelLevel
#if DEBUG
        if let requestedLevel = ProcessInfo.processInfo.environment[
            "PRIVATE_PRESENTER_PROOF_LEVEL"
        ], let requestedLevel = OverlayPanelLevel(rawValue: requestedLevel) {
            proofLevel = requestedLevel
        } else {
            proofLevel = .floating
        }
#else
        proofLevel = .floating
#endif
        let runtime = AppRuntime(proofLevel: proofLevel)
        let delegate = AppDelegate(runtime: runtime)
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime: AppRuntime

    init(runtime: AppRuntime) {
        self.runtime = runtime
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        runtime.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.stop()
    }
}
