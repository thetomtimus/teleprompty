import AppKit
import QuartzCore

@MainActor
protocol FrameClock: AnyObject {
    func invalidate()
}

typealias FrameClockFactory = @MainActor (
    NSView,
    @escaping @MainActor (TimeInterval) -> Void
) -> FrameClock?

@MainActor
final class DisplayLinkFrameClock: FrameClock {
    private final class Target: NSObject {
        let onTick: @MainActor (TimeInterval) -> Void

        init(onTick: @escaping @MainActor (TimeInterval) -> Void) {
            self.onTick = onTick
        }

        @objc func displayLinkDidFire(_ link: CADisplayLink) {
            MainActor.assumeIsolated {
                onTick(link.timestamp)
            }
        }
    }

    private weak var attachedView: NSView?
    private var link: CADisplayLink?
    private var target: Target?

    private init(
        attachedView: NSView,
        link: CADisplayLink,
        target: Target
    ) {
        self.attachedView = attachedView
        self.link = link
        self.target = target
    }

    static func make(
        attachedTo readerView: NSView,
        onTick: @escaping @MainActor (TimeInterval) -> Void
    ) -> FrameClock? {
        guard readerView.window != nil, readerView.window?.screen != nil else {
            return nil
        }
        let target = Target(onTick: onTick)
        // Required view-bound API: displayLink(target:selector:)
        let link = readerView.displayLink(
            target: target,
            selector: #selector(Target.displayLinkDidFire(_:))
        )
        link.add(to: RunLoop.main, forMode: .common)
        return DisplayLinkFrameClock(
            attachedView: readerView,
            link: link,
            target: target
        )
    }

    func invalidate() {
        guard let link else { return }
        self.link = nil
        link.invalidate()
        target = nil
        attachedView = nil
    }

    deinit {
        link?.invalidate()
    }
}
