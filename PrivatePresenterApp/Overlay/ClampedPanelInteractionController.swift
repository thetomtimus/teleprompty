import AppKit
import TeleprompterCore

/// AppKit interaction adapter used by the M0 drag/resize proof. Every candidate is
/// clamped before the sole `setFrame` call; native unconstrained drag/resize is absent.
@MainActor
final class ClampedPanelInteractionController {
    enum ResizeEdge: CaseIterable, Hashable, Sendable {
        case top, bottom, left, right
        case topLeft, topRight, bottomLeft, bottomRight

        var policyEdges: PanelResizeEdges {
            switch self {
            case .top: [.top]
            case .bottom: [.bottom]
            case .left: [.left]
            case .right: [.right]
            case .topLeft: [.top, .left]
            case .topRight: [.top, .right]
            case .bottomLeft: [.bottom, .left]
            case .bottomRight: [.bottom, .right]
            }
        }
    }

    let minimumSize: NSSize
    private let policy: PanelFramePolicy
    private let frameApplier: (NSRect) -> Void

    init(
        minimumSize: NSSize = NSSize(width: 320, height: 180),
        frameApplier: @escaping (NSRect) -> Void
    ) {
        self.minimumSize = minimumSize
        policy = PanelFramePolicy(
            safeTopInset: 0,
            minimumSize: DisplaySize(
                width: Double(minimumSize.width),
                height: Double(minimumSize.height)
            )
        )
        self.frameApplier = frameApplier
    }

    @discardableResult
    func apply(candidate: NSRect, inside screenFrame: NSRect) -> NSRect {
        let result = policy.clamp(
            DisplayRect(candidate),
            to: DisplayRect(screenFrame),
            minimumSize: DisplaySize(
                width: Double(minimumSize.width),
                height: Double(minimumSize.height)
            ),
            maximumSize: DisplaySize(
                width: Double(screenFrame.width),
                height: Double(screenFrame.height)
            )
        )
        let contained = NSRect(result)
        frameApplier(contained)
        return contained
    }

    @discardableResult
    func drag(frame: NSRect, delta: NSSize, inside screenFrame: NSRect) -> NSRect {
        apply(
            candidate: frame.offsetBy(dx: delta.width, dy: delta.height),
            inside: screenFrame
        )
    }

    @discardableResult
    func resize(
        frame: NSRect,
        edge: ResizeEdge,
        delta: NSSize,
        inside screenFrame: NSRect
    ) -> NSRect {
        let contained = NSRect(
            policy.resizedFrame(
                DisplayRect(frame),
                edges: edge.policyEdges,
                deltaX: Double(delta.width),
                deltaY: Double(delta.height),
                in: DisplayRect(screenFrame)
            )
        )
        frameApplier(contained)
        return contained
    }

    static func clamp(
        _ frame: NSRect,
        inside bounds: NSRect,
        minimumSize: NSSize,
        maximumSize: NSSize
    ) -> NSRect {
        let policy = PanelFramePolicy(
            safeTopInset: 0,
            minimumSize: DisplaySize(
                width: Double(minimumSize.width),
                height: Double(minimumSize.height)
            )
        )
        return NSRect(
            policy.clamp(
                DisplayRect(frame),
                to: DisplayRect(bounds),
                minimumSize: DisplaySize(
                    width: Double(minimumSize.width),
                    height: Double(minimumSize.height)
                ),
                maximumSize: DisplaySize(
                    width: Double(maximumSize.width),
                    height: Double(maximumSize.height)
                )
            )
        )
    }
}

extension DisplayRect {
    init(_ rect: NSRect) {
        self.init(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }
}

extension NSRect {
    init(_ rect: DisplayRect) {
        self.init(
            x: CGFloat(rect.x),
            y: CGFloat(rect.y),
            width: CGFloat(rect.width),
            height: CGFloat(rect.height)
        )
    }
}
