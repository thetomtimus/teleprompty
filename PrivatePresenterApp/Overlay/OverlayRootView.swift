import SwiftUI
import TeleprompterCore

/// Pure, bottom-origin half-open hit routing shared by geometry tests and the
/// rendered interaction layers. The ordering is the interaction contract.
struct OverlayHitRegionResolver {
    enum Route: Equatable {
        case control(String)
        case resize(ClampedPanelInteractionController.ResizeEdge)
        case titleDrag
        case none
    }

    struct ResizeProbe: Equatable {
        let edge: ClampedPanelInteractionController.ResizeEdge
        let point: CGPoint
    }

    let metrics: OverlayLayoutMetrics

    func resolve(point: CGPoint) -> Route {
        guard Self.contains(point, in: metrics.cardBounds) else { return .none }
        for region in metrics.controlRegions {
            if Self.contains(point, in: region.frame) {
                return .control(region.identifier)
            }
        }
        for region in metrics.cornerResizeRegions {
            if Self.contains(point, in: region.frame) {
                return .resize(region.edge)
            }
        }
        for region in metrics.edgeResizeRegions {
            if Self.contains(point, in: region.frame) {
                return .resize(region.edge)
            }
        }
        if Self.contains(point, in: metrics.titleDragFrame) {
            return .titleDrag
        }
        return .none
    }

    static func frozenResizeProbes(size: CGSize) -> [ResizeProbe] {
        let horizontal = max(110, min(size.width - 110, size.width / 3))
        let vertical = max(105, min(size.height - 75, size.height * 7 / 12))
        return [
            ResizeProbe(edge: .bottomLeft, point: CGPoint(x: 9, y: 9)),
            ResizeProbe(edge: .bottom, point: CGPoint(x: horizontal, y: 5)),
            ResizeProbe(
                edge: .bottomRight, point: CGPoint(x: size.width - 9, y: 9)
            ),
            ResizeProbe(edge: .left, point: CGPoint(x: 5, y: vertical)),
            ResizeProbe(
                edge: .right, point: CGPoint(x: size.width - 5, y: vertical)
            ),
            ResizeProbe(
                edge: .topLeft, point: CGPoint(x: 9, y: size.height - 9)
            ),
            ResizeProbe(
                edge: .top, point: CGPoint(x: horizontal, y: size.height - 5)
            ),
            ResizeProbe(
                edge: .topRight,
                point: CGPoint(x: size.width - 9, y: size.height - 9)
            ),
        ]
    }

    private static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX
            && point.y >= rect.minY && point.y < rect.maxY
    }
}

/// The resize layer is deliberately separate from header title drag and
/// controls so SwiftUI renders the same precedence as the pure resolver.
@MainActor
struct OverlayResizeInteractionLayer: View {
    let metrics: OverlayLayoutMetrics
    let onResizeChanged: (ClampedPanelInteractionController.ResizeEdge, CGSize) -> Void
    let onResizeEnded: () -> Void

    var body: some View {
        ZStack {
            ForEach(metrics.resizeRegions, id: \.edge) { region in
                interactionZone(edge: region.edge)
                    .frame(width: region.frame.width, height: region.frame.height)
                    .position(swiftUICenter(for: region.frame))
                    .zIndex(isCorner(region.edge) ? 1 : 0)
            }
        }
    }

    private func swiftUICenter(for bottomOriginFrame: CGRect) -> CGPoint {
        CGPoint(
            x: bottomOriginFrame.midX,
            y: metrics.size.height - bottomOriginFrame.midY
        )
    }

    private func interactionZone(
        edge: ClampedPanelInteractionController.ResizeEdge
    ) -> some View {
        Color.clear
            .accessibilityIdentifier(interactionIdentifier(edge))
            .accessibilityHidden(true)
            .contentShape(Rectangle())
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

    private func isCorner(
        _ edge: ClampedPanelInteractionController.ResizeEdge
    ) -> Bool {
        switch edge {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: true
        case .top, .bottom, .left, .right: false
        }
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
                        onDragEnded: onDragEnded,
                        onResizeChanged: onResizeChanged,
                        onResizeEnded: onResizeEnded
                    )
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

}
