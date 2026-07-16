import SwiftUI

/// Opaque, nonactivating reader surface with its header outside the clipped document.
@MainActor
struct OverlayRootView: View {
    static let cornerRadius: CGFloat = 18
    static let readerHeaderHeight: CGFloat = 36
    static let interiorIsFullyOpaque = true
    static let resizeZones = ClampedPanelInteractionController.ResizeEdge.allCases

    let model: AppModel?
    let readerSystem: ReaderTextSystem?
    let readerViewportFraction: Double
    let onReaderAttachmentChanged: @MainActor (Bool) -> Void
    let onReaderScreenChanged: @MainActor () -> Void
    let onReaderBoundsWillChange: @MainActor () -> Void
    let onReaderBoundsChanged: @MainActor () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onResizeChanged: (ClampedPanelInteractionController.ResizeEdge, CGSize) -> Void
    let onResizeEnded: () -> Void

    init(
        model: AppModel? = nil,
        readerSystem: ReaderTextSystem? = nil,
        readerViewportFraction: Double = 0.5,
        onReaderAttachmentChanged: @escaping @MainActor (Bool) -> Void = { _ in },
        onReaderScreenChanged: @escaping @MainActor () -> Void = {},
        onReaderBoundsWillChange: @escaping @MainActor () -> Void = {},
        onReaderBoundsChanged: @escaping @MainActor () -> Void = {},
        onDragChanged: @escaping (CGSize) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {},
        onResizeChanged:
            @escaping (
                ClampedPanelInteractionController.ResizeEdge,
                CGSize
            ) -> Void = { _, _ in },
        onResizeEnded: @escaping () -> Void = {}
    ) {
        self.model = model
        self.readerSystem = readerSystem
        self.readerViewportFraction = readerViewportFraction
        self.onReaderAttachmentChanged = onReaderAttachmentChanged
        self.onReaderScreenChanged = onReaderScreenChanged
        self.onReaderBoundsWillChange = onReaderBoundsWillChange
        self.onReaderBoundsChanged = onReaderBoundsChanged
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onResizeChanged = onResizeChanged
        self.onResizeEnded = onResizeEnded
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .accessibilityIdentifier("privatePresenter.readerBackground")
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                if isChromeVisible {
                    if let model {
                        OverlayChromeView(model: model)
                            .frame(height: Self.readerHeaderHeight)
                    } else {
                        Text("Private Presenter")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.readerHeaderHeight)
                    }
                }
                if let readerSystem {
                    ReaderTextView(
                        system: readerSystem,
                        viewportFraction: readerViewportFraction,
                        onAttachmentChanged: onReaderAttachmentChanged,
                        onScreenChanged: onReaderScreenChanged,
                        onBoundsWillChange: onReaderBoundsWillChange,
                        onBoundsChanged: onReaderBoundsChanged
                    )
                } else {
                    Color.clear
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .animation(chromeAnimation, value: isChromeVisible)
        .overlay(alignment: .top) {
            interactionZone(edge: nil).frame(height: Self.readerHeaderHeight)
        }
        .overlay(alignment: .top) {
            interactionZone(edge: .top).frame(height: 10)
        }
        .overlay(alignment: .bottom) {
            interactionZone(edge: .bottom).frame(height: 10)
        }
        .overlay(alignment: .leading) {
            interactionZone(edge: .left).frame(width: 10)
        }
        .overlay(alignment: .trailing) {
            interactionZone(edge: .right).frame(width: 10)
        }
        .overlay(alignment: .topLeading) {
            interactionZone(edge: .topLeft).frame(width: 18, height: 18)
        }
        .overlay(alignment: .topTrailing) {
            interactionZone(edge: .topRight).frame(width: 18, height: 18)
        }
        .overlay(alignment: .bottomLeading) {
            interactionZone(edge: .bottomLeft).frame(width: 18, height: 18)
        }
        .overlay(alignment: .bottomTrailing) {
            interactionZone(edge: .bottomRight).frame(width: 18, height: 18)
        }
    }

    private var isChromeVisible: Bool {
        model?.focusChromeState != .lockedFocusChromeHidden
    }

    private var chromeAnimation: Animation? {
        guard let model, model.focusChromeTransitionDuration > 0 else { return nil }
        return .easeInOut(duration: model.focusChromeTransitionDuration)
    }

    private func interactionZone(
        edge: ClampedPanelInteractionController.ResizeEdge?
    ) -> some View {
        Color.clear
            .accessibilityIdentifier(interactionIdentifier(edge))
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if let edge {
                            onResizeChanged(edge, value.translation)
                        } else {
                            onDragChanged(value.translation)
                        }
                    }
                    .onEnded { _ in
                        if edge == nil {
                            onDragEnded()
                        } else {
                            onResizeEnded()
                        }
                    }
            )
    }

    private func interactionIdentifier(
        _ edge: ClampedPanelInteractionController.ResizeEdge?
    ) -> String {
        guard let edge else { return "privatePresenter.overlayDragZone" }
        switch edge {
        case .top: "privatePresenter.resizeTop"
        case .bottom: "privatePresenter.resizeBottom"
        case .left: "privatePresenter.resizeLeft"
        case .right: "privatePresenter.resizeRight"
        case .topLeft: "privatePresenter.resizeTopLeft"
        case .topRight: "privatePresenter.resizeTopRight"
        case .bottomLeft: "privatePresenter.resizeBottomLeft"
        case .bottomRight: "privatePresenter.resizeBottomRight"
        }
    }
}
