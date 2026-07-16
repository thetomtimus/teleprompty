import SwiftUI
import TeleprompterCore

/// Opaque, nonactivating reader surface. Reader and chrome are siblings so a
/// Focus fade never inserts, removes, or resizes the TextKit viewport.
@MainActor
struct OverlayRootView: View {
    struct ChromePresentation: Equatable {
        let opacity: Double
        let allowsInteraction: Bool
        let isAccessibilityHidden: Bool
        let transitionDuration: TimeInterval
        let readerGeometryIdentity: CGFloat
    }

    static let cornerRadius = OverlayVisualTokens.cardRadius
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
        GeometryReader { geometry in
            rootContent(size: geometry.size)
        }
    }

    static func chromePresentation(
        focusState: FocusChromeState,
        isLocked: Bool,
        transitionDuration: TimeInterval,
        readerGeometryIdentity: CGFloat = 0
    ) -> ChromePresentation {
        let hidden = isLocked && focusState == .lockedFocusChromeHidden
        return ChromePresentation(
            opacity: hidden ? 0 : 1,
            allowsInteraction: !isLocked,
            isAccessibilityHidden: isLocked,
            transitionDuration: max(transitionDuration, 0),
            readerGeometryIdentity: readerGeometryIdentity
        )
    }

    private func rootContent(size: CGSize) -> some View {
        let metrics = OverlayLayoutMetrics(size: size)
        return ZStack {
            LinearGradient(
                stops: OverlayVisualTokens.cardGradientStops.map {
                    Gradient.Stop(
                        color: $0.color.swiftUIColor,
                        location: $0.location
                    )
                },
                startPoint: .top,
                endPoint: .bottom
            )
            .accessibilityIdentifier("privatePresenter.readerBackground")
            .accessibilityHidden(true)

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
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(
                    OverlayVisualTokens.cardBorder.swiftUIColor,
                    lineWidth: OverlayVisualTokens.cardBorderWidth
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        .overlay {
            if let model {
                let presentation = Self.chromePresentation(
                    focusState: model.focusChromeState,
                    isLocked: model.isLocked,
                    transitionDuration: model.focusChromeTransitionDuration,
                    readerGeometryIdentity: metrics.readableLineWidth
                )
                ZStack {
                    OverlayChromeView(
                        model: model,
                        metrics: metrics,
                        onDragChanged: onDragChanged,
                        onDragEnded: onDragEnded
                    )
                    .frame(height: metrics.headerHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(presentation.opacity)
                    .allowsHitTesting(presentation.allowsInteraction)
                    .accessibilityHidden(presentation.isAccessibilityHidden)

                    OverlayQuickControlsView(model: model, metrics: metrics)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, metrics.toolbarBottomInset)
                        .opacity(presentation.opacity)
                        .allowsHitTesting(presentation.allowsInteraction)
                        .accessibilityHidden(presentation.isAccessibilityHidden)
                }
                .animation(
                    chromeAnimation(duration: presentation.transitionDuration),
                    value: presentation.opacity
                )
            }
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    private func chromeAnimation(duration: TimeInterval) -> Animation? {
        duration > 0 ? .easeInOut(duration: duration) : nil
    }

    private func interactionZone(
        edge: ClampedPanelInteractionController.ResizeEdge
    ) -> some View {
        Color.clear
            .accessibilityIdentifier(interactionIdentifier(edge))
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .allowsHitTesting(model?.isLocked == false)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        onResizeChanged(edge, value.translation)
                    }
                    .onEnded { _ in
                        onResizeEnded()
                    }
            )
    }

    private func interactionIdentifier(
        _ edge: ClampedPanelInteractionController.ResizeEdge
    ) -> String {
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
