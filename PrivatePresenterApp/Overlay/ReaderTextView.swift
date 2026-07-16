import AppKit
import SwiftUI

@MainActor
final class ReaderScrollView: NSScrollView {
    static let userScrollingIsDisabled = true

    override func scrollWheel(with event: NSEvent) {
        // Only ReaderViewportAdapter may move the reader clip origin.
    }
}

@MainActor
final class ReaderClipView: NSClipView {
    override func scroll(to newOrigin: NSPoint) {
        // External callers, scroll input, and inherited NSScrollView behavior
        // cannot move the rehearsal viewport. The adapter-only method below is
        // the sole production path that deliberately invokes super.
    }

    func setProgrammaticOriginY(_ offset: Double, maximumOffset: Double) {
        let acceptedMaximum = maximumOffset.isFinite ? max(maximumOffset, 0) : 0
        let acceptedOffset = offset.isFinite ? offset : 0
        let origin = NSPoint(
            x: 0,
            y: CGFloat(min(max(acceptedOffset, 0), acceptedMaximum))
        )
        super.scroll(to: origin)
        (superview as? NSScrollView)?.reflectScrolledClipView(self)
    }
}

@MainActor
final class ReaderActiveBandView: NSView {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class ReaderViewportContainerView: NSView {
    static let activeBandHeight = 84.0

    let backgroundView = NSView()
    let scrollView = ReaderScrollView()
    private let system: ReaderTextSystem
    private var viewportFraction: Double
    private let onAttachmentChanged: @MainActor (Bool) -> Void
    private let onScreenChanged: @MainActor () -> Void
    private let onBoundsWillChange: @MainActor () -> Void
    private let onBoundsChanged: @MainActor () -> Void
    private(set) var viewportAdapter: ReaderViewportAdapter!

    override var isFlipped: Bool { true }

    init(
        system: ReaderTextSystem,
        viewportFraction: Double,
        onAttachmentChanged: @escaping @MainActor (Bool) -> Void = { _ in },
        onScreenChanged: @escaping @MainActor () -> Void = {},
        onBoundsWillChange: @escaping @MainActor () -> Void = {},
        onBoundsChanged: @escaping @MainActor () -> Void = {}
    ) {
        self.system = system
        self.viewportFraction = Self.clampedFraction(viewportFraction)
        self.onAttachmentChanged = onAttachmentChanged
        self.onScreenChanged = onScreenChanged
        self.onBoundsWillChange = onBoundsWillChange
        self.onBoundsChanged = onBoundsChanged
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(
            red: 0.05,
            green: 0.06,
            blue: 0.09,
            alpha: 1
        ).cgColor
        backgroundView.identifier = NSUserInterfaceItemIdentifier(
            "privatePresenter.readerBackground"
        )
        backgroundView.setAccessibilityElement(false)
        system.activeBandView.identifier = NSUserInterfaceItemIdentifier(
            "privatePresenter.readerBand"
        )
        system.activeBandView.setAccessibilityElement(false)

        scrollView.contentView = ReaderClipView()
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.allowsMagnification = false
        scrollView.documentView = system.textView

        system.textView.identifier = NSUserInterfaceItemIdentifier(
            "privatePresenter.reader"
        )

        // AppKit subview order is back-to-front: opaque background, fixed band,
        // then the transparent clipped text view.
        addSubview(backgroundView)
        addSubview(system.activeBandView)
        addSubview(scrollView)

        viewportAdapter = ReaderViewportAdapter(
            system: system,
            attachmentView: self,
            scrollView: scrollView,
            viewportFraction: self.viewportFraction
        )
        system.attachViewportAdapter(viewportAdapter)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        scrollView.frame = bounds
        let bandHeight = CGFloat(Self.activeBandHeight)
        system.activeBandView.frame = NSRect(
            x: bounds.minX,
            y: bounds.height * CGFloat(viewportFraction) - bandHeight / 2,
            width: bounds.width,
            height: bandHeight
        )
        if bounds.width > 1, bounds.height > 1 {
            viewportAdapter.ensureLayout()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        onAttachmentChanged(newWindow != nil)
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        onScreenChanged()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize && frame.size != .zero && newSize != .zero
        if changed { onBoundsWillChange() }
        super.setFrameSize(newSize)
        if changed {
            needsLayout = true
            layoutSubtreeIfNeeded()
            onBoundsChanged()
        }
    }

    func updateViewportFraction(_ fraction: Double) {
        viewportFraction = Self.clampedFraction(fraction)
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private static func clampedFraction(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0.5 }
        return min(max(fraction, 0), 1)
    }
}

@MainActor
struct ReaderTextView: NSViewRepresentable {
    let system: ReaderTextSystem
    var viewportFraction = 0.5
    var onAttachmentChanged: @MainActor (Bool) -> Void = { _ in }
    var onScreenChanged: @MainActor () -> Void = {}
    var onBoundsWillChange: @MainActor () -> Void = {}
    var onBoundsChanged: @MainActor () -> Void = {}

    static func makeReaderView(
        system: ReaderTextSystem,
        viewportFraction: Double = 0.5,
        onAttachmentChanged: @escaping @MainActor (Bool) -> Void = { _ in },
        onScreenChanged: @escaping @MainActor () -> Void = {},
        onBoundsWillChange: @escaping @MainActor () -> Void = {},
        onBoundsChanged: @escaping @MainActor () -> Void = {}
    ) -> ReaderViewportContainerView {
        ReaderViewportContainerView(
            system: system,
            viewportFraction: viewportFraction,
            onAttachmentChanged: onAttachmentChanged,
            onScreenChanged: onScreenChanged,
            onBoundsWillChange: onBoundsWillChange,
            onBoundsChanged: onBoundsChanged
        )
    }

    func makeNSView(context: Context) -> ReaderViewportContainerView {
        Self.makeReaderView(
            system: system,
            viewportFraction: viewportFraction,
            onAttachmentChanged: onAttachmentChanged,
            onScreenChanged: onScreenChanged,
            onBoundsWillChange: onBoundsWillChange,
            onBoundsChanged: onBoundsChanged
        )
    }

    func updateNSView(_ view: ReaderViewportContainerView, context: Context) {
        view.updateViewportFraction(viewportFraction)
    }
}
