import AppKit
import SwiftUI

#if DEBUG
enum ControllerWindowOperation: Equatable, Sendable {
    case placementEntry
    case frameChanged
    case placementExit
    case presentationEntry
    case showWindow
    case presentationExit
}
#endif

@MainActor
final class ControllerWindowController: NSWindowController {
    private let model: AppModel
    #if DEBUG
    private let operationRecorder: (ControllerWindowOperation) -> Void
    #endif
    private(set) var placementCount = 0
    private(set) var presentationCount = 0

    var showCount: Int { presentationCount }

    var modelIdentity: ObjectIdentifier {
        ObjectIdentifier(model)
    }

    #if DEBUG
    convenience init(
        model: AppModel,
        untrustedInitialFrame: NSRect? = ControllerWindowController.debugSeedFrame(),
        operationRecorder: @escaping (ControllerWindowOperation) -> Void = { _ in }
    ) {
        self.init(
            model: model,
            untrustedInitialFrame: untrustedInitialFrame,
            operationRecorderObject: operationRecorder
        )
    }
    #else
    convenience init(
        model: AppModel,
        untrustedInitialFrame: NSRect? = ControllerWindowController.debugSeedFrame()
    ) {
        self.init(
            model: model,
            untrustedInitialFrame: untrustedInitialFrame,
            operationRecorderObject: nil
        )
    }
    #endif

    private init(
        model: AppModel,
        untrustedInitialFrame: NSRect?,
        operationRecorderObject: Any?
    ) {
        self.model = model
        #if DEBUG
        operationRecorder =
            operationRecorderObject
            as? (ControllerWindowOperation) -> Void ?? { _ in }
        #endif
        let initialFrame =
            untrustedInitialFrame
            ?? NSRect(x: 0, y: 0, width: 620, height: 360)
        let window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Private Presenter — Overlay Proof"
        window.contentViewController = NSHostingController(rootView: ControllerView(model: model))
        window.setFrame(initialFrame, display: false)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Moves the controller while preserving its current ordered-in/ordered-out state.
    /// Saved frames are ignored during M0 and the destination is always clamped.
    func placeControllerWhileShielded(on candidate: RuntimeDisplay?) {
        guard let window else { return }
        #if DEBUG
        operationRecorder(.placementEntry)
        #endif
        placementCount += 1
        let screenFrame = candidate?.visibleFrame ?? NSScreen.main?.visibleFrame
        if let screenFrame {
            let origin = NSPoint(
                x: screenFrame.midX - window.frame.width / 2,
                y: screenFrame.midY - window.frame.height / 2
            )
            let clamped = ClampedPanelInteractionController.clamp(
                NSRect(origin: origin, size: window.frame.size),
                inside: screenFrame,
                minimumSize: window.frame.size,
                maximumSize: screenFrame.size
            )
            window.setFrame(clamped, display: false)
            #if DEBUG
            operationRecorder(.frameChanged)
            #endif
        }
        #if DEBUG
        operationRecorder(.placementExit)
        #endif
    }

    /// Startup is the sole implicit controller presentation in the M0 proof app.
    func presentShieldedControllerAtStartup(on candidate: RuntimeDisplay?) {
        guard window != nil else { return }
        #if DEBUG
        operationRecorder(.presentationEntry)
        #endif
        placeControllerWhileShielded(on: candidate)
        presentationCount += 1
        #if DEBUG
        operationRecorder(.showWindow)
        #endif
        showWindow(nil)
        #if DEBUG
        operationRecorder(.presentationExit)
        #endif
    }

    #if DEBUG
    func observedDiagnosticCohort() -> DiagnosticControllerCohort? {
        guard let window else { return nil }
        return window.isVisible ? .visibleDesktopSpace : .orderedOut
    }
    #endif

    static func debugSeedFrame() -> NSRect? {
        #if DEBUG
        guard
            let raw = ProcessInfo.processInfo.environment[
                "PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME"
            ]
        else {
            return nil
        }
        let values = raw.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard values.count == 4, values.allSatisfy(\.isFinite) else {
            return nil
        }
        return NSRect(
            x: CGFloat(values[0]),
            y: CGFloat(values[1]),
            width: CGFloat(values[2]),
            height: CGFloat(values[3])
        )
        #else
        return nil
        #endif
    }
}
