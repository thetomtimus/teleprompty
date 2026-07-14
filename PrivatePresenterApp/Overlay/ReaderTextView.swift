import AppKit
import SwiftUI

@MainActor
final class StaticReaderScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Reader viewport motion belongs to M3. M2 remains anchored and static.
    }
}

@MainActor
final class StaticReaderClipView: NSClipView {
    override func scroll(to newOrigin: NSPoint) {
        super.scroll(to: .zero)
    }
}

@MainActor
struct ReaderTextView: NSViewRepresentable {
    let system: ReaderTextSystem

    @MainActor
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let scrollView = StaticReaderScrollView()
        scrollView.contentView = StaticReaderClipView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = system.textView
        system.textView.identifier = NSUserInterfaceItemIdentifier(
            "privatePresenter.staticReader"
        )

        for view in [scrollView, system.activeBandView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            system.activeBandView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            system.activeBandView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            system.activeBandView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            system.activeBandView.heightAnchor.constraint(equalToConstant: 84),
        ])
        return container
    }

    @MainActor
    func updateNSView(_ view: NSView, context: Context) {
        guard
            let scrollView = view.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
            scrollView.contentSize.width > 1,
            scrollView.contentSize.height > 1
        else { return }
        system.configureViewport(scrollView.contentSize)
    }
}
