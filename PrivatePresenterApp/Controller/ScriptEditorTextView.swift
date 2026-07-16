import AppKit
import SwiftUI

@MainActor
struct ScriptEditorTextView: NSViewRepresentable {
    let text: String
    let revision: UInt64
    let performanceRegistry: PerformanceIntervalRegistry
    let restorePerformanceGate: RestoreInteractivePerformanceGate?
    let onEdit: @MainActor (ScriptTextEdit) -> Void

    @MainActor
    final class Coordinator {
        let system: EditorTextSystem

        init(
            text: String,
            revision: UInt64,
            performanceRegistry: PerformanceIntervalRegistry,
            restorePerformanceGate: RestoreInteractivePerformanceGate?,
            onEdit: @escaping @MainActor (ScriptTextEdit) -> Void
        ) {
            system = EditorTextSystem(
                text: text,
                revision: revision,
                performanceRegistry: performanceRegistry,
                restorePerformanceGate: restorePerformanceGate,
                onEdit: onEdit
            )
        }
    }

    @MainActor
    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: text,
            revision: revision,
            performanceRegistry: performanceRegistry,
            restorePerformanceGate: restorePerformanceGate,
            onEdit: onEdit
        )
    }

    @MainActor
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = context.coordinator.system.textView
        context.coordinator.system.textView.identifier = NSUserInterfaceItemIdentifier(
            "privatePresenter.scriptEditor"
        )
        configureDocumentView(in: scrollView, system: context.coordinator.system)
        return scrollView
    }

    @MainActor
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        configureDocumentView(in: scrollView, system: context.coordinator.system)
        context.coordinator.system.synchronize(text: text, revision: revision)
    }

    private func configureDocumentView(
        in scrollView: NSScrollView,
        system: EditorTextSystem
    ) {
        let size = scrollView.contentSize
        guard size.width > 1, size.height > 1 else { return }
        system.configureViewport(size)
    }
}
