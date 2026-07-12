import AppKit
import SwiftUI
import TeleprompterCore

struct OverlayConfigurationSnapshot: Equatable, Sendable {
    let panelCount: Int
    let isBorderless: Bool
    let isNonactivating: Bool
    let isNativelyResizable: Bool
    let joinsAllSpaces: Bool
    let isFullScreenAuxiliary: Bool
    let level: String
    let isLocked: Bool
    let ignoresMouseEvents: Bool
    let canBecomeKey: Bool
    let canBecomeMain: Bool
    let interiorIsFullyOpaque: Bool
}

/// Sole owner and creator of the process's one teleprompter panel.
@MainActor
final class OverlayPanelController: NSWindowController {
    let teleprompterPanel: TeleprompterPanel
    let interactionController: ClampedPanelInteractionController
    private(set) var selectedScreenFrame: NSRect?
    private(set) var appliedFrames: [NSRect] = []
    private var interactionStartFrame: NSRect?

    init(
        initialFrame: NSRect = NSRect(x: 0, y: 0, width: 700, height: 350),
        proofLevel: OverlayPanelLevel = .statusBar
    ) {
        let panel = TeleprompterPanel(contentRect: initialFrame, proofLevel: proofLevel)
        teleprompterPanel = panel
        interactionController = ClampedPanelInteractionController { [weak panel] frame in
            panel?.setFrame(frame, display: false)
        }
        super.init(window: panel)

        panel.contentViewController = NSHostingController(
            rootView: OverlayRootView(
                onDragChanged: { [weak self] translation in
                    self?.updateDrag(translation: translation)
                },
                onDragEnded: { [weak self] in
                    self?.endInteraction()
                },
                onResizeChanged: { [weak self] edge, translation in
                    self?.updateResize(edge: edge, translation: translation)
                },
                onResizeEnded: { [weak self] in
                    self?.endInteraction()
                }
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func stageHidden(proposedFrame: NSRect, on screenFrame: NSRect) {
        selectedScreenFrame = screenFrame
        teleprompterPanel.containmentFrame = screenFrame
        teleprompterPanel.orderOut(nil)
        applyContainedFrame(proposedFrame)
    }

    func show(proposedFrame: NSRect, on screenFrame: NSRect) {
        selectedScreenFrame = screenFrame
        teleprompterPanel.containmentFrame = screenFrame
        applyContainedFrame(proposedFrame)
        // Intentionally neither makeKeyAndOrderFront nor NSApp.activate.
        teleprompterPanel.orderFrontRegardless()
    }

    func hide() {
        teleprompterPanel.orderOut(nil)
    }

    func setLocked(_ locked: Bool) {
        teleprompterPanel.setLocked(locked)
    }

    @discardableResult
    func applyContainedFrame(_ candidate: NSRect) -> NSRect? {
        guard let selectedScreenFrame else { return nil }
        let frame = interactionController.apply(candidate: candidate, inside: selectedScreenFrame)
        appliedFrames.append(frame)
        return frame
    }

    func defaultFrame(on visibleFrame: NSRect) -> NSRect {
        NSRect(
            PanelFramePolicy(safeTopInset: 24).defaultFrame(
                in: DisplayRect(visibleFrame)
            )
        )
    }

    func updateDrag(translation: CGSize) {
        guard let selectedScreenFrame else { return }
        let start = interactionStartFrame ?? teleprompterPanel.frame
        interactionStartFrame = start
        let frame = interactionController.drag(
            frame: start,
            delta: NSSize(width: translation.width, height: translation.height),
            inside: selectedScreenFrame
        )
        appliedFrames.append(frame)
    }

    func updateResize(
        edge: ClampedPanelInteractionController.ResizeEdge,
        translation: CGSize
    ) {
        guard let selectedScreenFrame else { return }
        let start = interactionStartFrame ?? teleprompterPanel.frame
        interactionStartFrame = start
        let frame = interactionController.resize(
            frame: start,
            edge: edge,
            delta: NSSize(width: translation.width, height: translation.height),
            inside: selectedScreenFrame
        )
        appliedFrames.append(frame)
    }

    func endInteraction() {
        interactionStartFrame = nil
    }

    var configurationSnapshot: OverlayConfigurationSnapshot {
        let mask = teleprompterPanel.styleMask
        let behavior = teleprompterPanel.collectionBehavior
        return OverlayConfigurationSnapshot(
            panelCount: 1,
            isBorderless: !mask.contains(.titled),
            isNonactivating: mask.contains(.nonactivatingPanel),
            isNativelyResizable: mask.contains(.resizable),
            joinsAllSpaces: behavior.contains(.canJoinAllSpaces),
            isFullScreenAuxiliary: behavior.contains(.fullScreenAuxiliary),
            level: OverlayPanelLevel.allCases.first(where: {
                $0.appKitLevel == teleprompterPanel.level
            })?.rawValue ?? "unbounded",
            isLocked: teleprompterPanel.isOverlayLocked,
            ignoresMouseEvents: teleprompterPanel.ignoresMouseEvents,
            canBecomeKey: teleprompterPanel.canBecomeKey,
            canBecomeMain: teleprompterPanel.canBecomeMain,
            interiorIsFullyOpaque: OverlayRootView.interiorIsFullyOpaque
        )
    }
}
