import AppKit

@main
@MainActor
enum PrivatePresenterApplication {
    static func main() {
        let application = NSApplication.shared
        #if DEBUG
        let resolution = DiagnosticProofConfiguration.resolve()
        let evidenceRecorder = DiagnosticEvidenceRecorder.production(resolution: resolution)
        let runtime = AppRuntime(
            proofLevel: resolution.configuration.proofLevel,
            diagnosticConfiguration: resolution.configuration,
            diagnosticEvidenceRecorder: evidenceRecorder,
            enforcesDiagnosticControllerCohort: !resolution.faults.contains(
                .configControllerCohortInvalid
            )
        )
        #else
        let runtime = AppRuntime(proofLevel: .floating)
        #endif
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
