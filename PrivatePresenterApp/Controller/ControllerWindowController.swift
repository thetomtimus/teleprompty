import AppKit
import SwiftUI

#if DEBUG
enum ControllerWindowOperation: Equatable, Sendable {
    case showShieldedEntry
    case frameChanged
    case showWindow
    case showShieldedExit
}
#endif

@MainActor
final class ControllerWindowController: NSWindowController {
    private let model: AppModel
#if DEBUG
    private let operationRecorder: (ControllerWindowOperation) -> Void
#endif
    private(set) var showCount = 0

    var modelIdentity: ObjectIdentifier {
        ObjectIdentifier(model)
    }

    init(
        model: AppModel,
        untrustedInitialFrame: NSRect? = ControllerWindowController.debugSeedFrame(),
#if DEBUG
        operationRecorder: @escaping (ControllerWindowOperation) -> Void = { _ in }
#endif
    ) {
        self.model = model
#if DEBUG
        self.operationRecorder = operationRecorder
#endif
        let initialFrame = untrustedInitialFrame
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

    /// Saved frames are deliberately ignored during M0. The shielded controller is
    /// positioned only on the current built-in candidate (or main screen fallback).
    func showShielded(on candidate: RuntimeDisplay?) {
        guard let window else { return }
#if DEBUG
        operationRecorder(.showShieldedEntry)
#endif
        showCount += 1
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
        operationRecorder(.showWindow)
#endif
        showWindow(nil)
#if DEBUG
        operationRecorder(.showShieldedExit)
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
        guard let raw = ProcessInfo.processInfo.environment[
            "PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME"
        ] else {
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
