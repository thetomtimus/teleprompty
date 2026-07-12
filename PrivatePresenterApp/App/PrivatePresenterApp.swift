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
            proofLevel = .statusBar
        }
#else
        proofLevel = .statusBar
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
