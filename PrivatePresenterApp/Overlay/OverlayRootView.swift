import AppKit
import SwiftUI
import TeleprompterCore

enum OverlayScreenDragTranslation {
    static func inferredStartLocation(
        currentScreenLocation: NSPoint,
        initialSwiftUITranslation: CGSize
    ) -> NSPoint {
        NSPoint(
            x: currentScreenLocation.x - initialSwiftUITranslation.width,
            y: currentScreenLocation.y + initialSwiftUITranslation.height
        )
    }

    static func swiftUITranslation(
        from startScreenLocation: NSPoint,
        to currentScreenLocation: NSPoint
    ) -> CGSize {
        CGSize(
            width: currentScreenLocation.x - startScreenLocation.x,
            height: startScreenLocation.y - currentScreenLocation.y
        )
    }
}

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
    enum CursorStyle: Equatable {
        case horizontal
        case vertical
        case diagonalNorthwestSoutheast
        case diagonalNortheastSouthwest
    }

    static let visibleGripEdges: [ClampedPanelInteractionController.ResizeEdge] = [
        .bottomLeft, .bottomRight,
    ]

    let metrics: OverlayLayoutMetrics
    let showsCornerGrips: Bool
    let onResizeChanged: (ClampedPanelInteractionController.ResizeEdge, CGSize) -> Void
    let onResizeEnded: () -> Void
    @State private var hoveredEdge: ClampedPanelInteractionController.ResizeEdge?
    @State private var activeEdge: ClampedPanelInteractionController.ResizeEdge?
    @State private var dragStartScreenLocation: NSPoint?

    var body: some View {
        ZStack {
            if showsCornerGrips {
                ForEach(Self.visibleGripEdges, id: \.self) { edge in
                    OverlayCornerResizeGrip(
                        edge: edge,
                        isHighlighted: hoveredEdge == edge || activeEdge == edge
                    )
                    .position(gripCenter(for: edge))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }

            ForEach(metrics.resizeRegions, id: \.edge) { region in
                interactionZone(edge: region.edge)
                    .frame(width: region.frame.width, height: region.frame.height)
                    .position(swiftUICenter(for: region.frame))
                    .zIndex(isCorner(region.edge) ? 1 : 0)
            }
        }
        .onChange(of: showsCornerGrips) { _, isVisible in
            if !isVisible {
                hoveredEdge = nil
                activeEdge = nil
                dragStartScreenLocation = nil
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            dragStartScreenLocation = nil
            NSCursor.arrow.set()
        }
    }

    static func cursorStyle(
        for edge: ClampedPanelInteractionController.ResizeEdge
    ) -> CursorStyle {
        switch edge {
        case .left, .right:
            .horizontal
        case .top, .bottom:
            .vertical
        case .topLeft, .bottomRight:
            .diagonalNorthwestSoutheast
        case .topRight, .bottomLeft:
            .diagonalNortheastSouthwest
        }
    }

    static func cornerGripsAreVisible(isLocked: Bool) -> Bool {
        !isLocked
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
                        activeEdge = edge
                        let current = NSEvent.mouseLocation
                        let start =
                            dragStartScreenLocation
                            ?? OverlayScreenDragTranslation.inferredStartLocation(
                                currentScreenLocation: current,
                                initialSwiftUITranslation: value.translation
                            )
                        dragStartScreenLocation = start
                        onResizeChanged(
                            edge,
                            OverlayScreenDragTranslation.swiftUITranslation(
                                from: start,
                                to: current
                            )
                        )
                    }
                    .onEnded { _ in
                        activeEdge = nil
                        dragStartScreenLocation = nil
                        if hoveredEdge == nil {
                            NSCursor.arrow.set()
                        }
                        onResizeEnded()
                    }
            )
            .onHover { isHovering in
                if isHovering {
                    hoveredEdge = edge
                    resizeCursor(for: edge).set()
                } else if hoveredEdge == edge {
                    hoveredEdge = nil
                    if activeEdge == nil {
                        NSCursor.arrow.set()
                    }
                }
            }
    }

    private func gripCenter(
        for edge: ClampedPanelInteractionController.ResizeEdge
    ) -> CGPoint {
        let inset: CGFloat = 18
        return CGPoint(
            x: edge == .bottomLeft ? inset : metrics.size.width - inset,
            y: metrics.size.height - inset
        )
    }

    private func resizeCursor(
        for edge: ClampedPanelInteractionController.ResizeEdge
    ) -> NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(
                position: frameResizePosition(for: edge),
                directions: .all
            )
        }

        switch Self.cursorStyle(for: edge) {
        case .horizontal:
            return .resizeLeftRight
        case .vertical:
            return .resizeUpDown
        case .diagonalNorthwestSoutheast:
            return diagonalCursor(symbolName: "arrow.up.left.and.arrow.down.right")
        case .diagonalNortheastSouthwest:
            return diagonalCursor(symbolName: "arrow.up.right.and.arrow.down.left")
        }
    }

    @available(macOS 15.0, *)
    private func frameResizePosition(
        for edge: ClampedPanelInteractionController.ResizeEdge
    ) -> NSCursor.FrameResizePosition {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .left: .left
        case .right: .right
        case .topLeft: .topLeft
        case .topRight: .topRight
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        }
    }

    private func diagonalCursor(symbolName: String) -> NSCursor {
        guard
            let symbol = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            )
        else {
            return .crosshair
        }
        return NSCursor(
            image: symbol,
            hotSpot: NSPoint(x: symbol.size.width / 2, y: symbol.size.height / 2)
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

private struct OverlayCornerResizeGrip: View {
    let edge: ClampedPanelInteractionController.ResizeEdge
    let isHighlighted: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for length in [CGFloat(4), 8, 12] {
                switch edge {
                case .bottomLeft:
                    path.move(to: CGPoint(x: length, y: size.height - 1))
                    path.addLine(to: CGPoint(x: 1, y: size.height - length))
                case .bottomRight:
                    path.move(
                        to: CGPoint(x: size.width - length, y: size.height - 1)
                    )
                    path.addLine(
                        to: CGPoint(x: size.width - 1, y: size.height - length)
                    )
                default:
                    break
                }
            }
            context.stroke(
                path,
                with: .color(
                    isHighlighted
                        ? OverlayVisualTokens.resizeGripActive.swiftUIColor
                        : OverlayVisualTokens.resizeGrip.swiftUIColor
                ),
                style: StrokeStyle(
                    lineWidth: OverlayVisualTokens.resizeGripLineWidth,
                    lineCap: .round
                )
            )
        }
        .frame(width: 14, height: 14)
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

    static func lockedUnlockTargetFrame(in metrics: OverlayLayoutMetrics) -> CGRect {
        metrics.headerControlRegions.first(where: {
            $0.identifier == "privatePresenter.headerLock"
        })?.frame ?? .zero
    }

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

                    if model.isLocked {
                        lockedInteractionBlocker
                        lockedUnlockTarget(model: model, metrics: metrics)
                    }
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

    private var lockedInteractionBlocker: some View {
        Color.clear
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private func lockedUnlockTarget(
        model: AppModel,
        metrics: OverlayLayoutMetrics
    ) -> some View {
        let frame = Self.lockedUnlockTargetFrame(in: metrics)
        return Button {
            model.send(.toggleLock)
        } label: {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: frame.width, height: frame.height)
        .position(
            x: frame.midX,
            y: metrics.size.height - frame.midY
        )
        .presenterAccessibility(
            PresenterAccessibility.entry(
                "privatePresenter.headerLock",
                state: PresenterAccessibility.state(model: model)
            )
        )
    }

    private func chromeAnimation(duration: TimeInterval) -> Animation? {
        duration > 0 ? .easeInOut(duration: duration) : nil
    }

}
