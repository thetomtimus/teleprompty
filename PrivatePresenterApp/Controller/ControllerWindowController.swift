import AppKit
import SwiftUI

@MainActor
final class ControllerWindowController: NSWindowController {
    private let model: AppModel
    private(set) var showCount = 0

    var modelIdentity: ObjectIdentifier {
        ObjectIdentifier(model)
    }

    init(
        model: AppModel,
        untrustedInitialFrame: NSRect? = ControllerWindowController.debugSeedFrame()
    ) {
        self.model = model
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
        }
        showWindow(nil)
    }

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
