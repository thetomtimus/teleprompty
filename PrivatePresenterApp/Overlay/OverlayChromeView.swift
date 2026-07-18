import AppKit
import SwiftUI

/// The private overlay header. Only its title/empty region owns the custom drag
/// gesture; controls remain above that region and dispatch existing commands.
@MainActor
struct OverlayChromeView: View {
    static let actionIdentifiers = [
        "privatePresenter.headerPlayback",
        "privatePresenter.headerLock",
        "privatePresenter.headerSettings",
    ]

    @Bindable var model: AppModel
    let metrics: OverlayLayoutMetrics
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onResizeChanged: (ClampedPanelInteractionController.ResizeEdge, CGSize) -> Void
    let onResizeEnded: () -> Void
    @State private var dragStartScreenLocation: NSPoint?

    init(
        model: AppModel,
        metrics: OverlayLayoutMetrics = OverlayLayoutMetrics(
            size: CGSize(width: 640, height: 80)
        ),
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
        self.metrics = metrics
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onResizeChanged = onResizeChanged
        self.onResizeEnded = onResizeEnded
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            titleDragRegion
                .frame(
                    width: metrics.titleDragFrame.width,
                    height: metrics.titleDragFrame.height
                )
                .position(
                    x: metrics.titleDragFrame.midX,
                    y: metrics.size.height - metrics.titleDragFrame.midY
                )
                .zIndex(0)

            OverlayResizeInteractionLayer(
                metrics: metrics,
                showsCornerGrips: OverlayResizeInteractionLayer.cornerGripsAreVisible(
                    isLocked: model.isLocked
                ),
                onResizeChanged: onResizeChanged,
                onResizeEnded: onResizeEnded
            )
            .frame(width: metrics.size.width, height: metrics.size.height)
            .zIndex(1)

            headerActions
                .frame(width: headerActionFrame.width, height: metrics.headerHeight)
                .position(x: headerActionFrame.midX, y: metrics.headerHeight / 2)
                .zIndex(2)

            Rectangle()
                .fill(OverlayVisualTokens.headerDivider.swiftUIColor)
                .frame(width: metrics.size.width, height: 1)
                .position(x: metrics.size.width / 2, y: metrics.headerHeight - 0.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .foregroundStyle(OverlayVisualTokens.readingText.swiftUIColor)
    }

    private var headerActions: some View {
        HStack(spacing: metrics.headerActionSpacing) {
            iconButton(index: 0) {
                model.send(.togglePlayback)
            }
            iconButton(index: 1) {
                model.send(.toggleLock)
            }
            iconButton(index: 2) {
                model.send(.showController)
            }
        }
    }

    private var headerActionFrame: CGRect {
        let frames = metrics.headerControlRegions.map(\.frame)
        guard let first = frames.first, let last = frames.last else { return .zero }
        return first.union(last)
    }

    static func title(model: AppModel) -> String {
        model.document.title
    }

    static func symbols(isPlaying: Bool, isLocked: Bool) -> [String] {
        [
            isPlaying ? "pause.fill" : "play.fill",
            isLocked ? "lock.fill" : "lock.open.fill",
            "gearshape",
        ]
    }

    static func iconSize(for tier: OverlayLayoutMetrics.Tier) -> CGFloat {
        switch tier {
        case .compact: 16
        case .standard: 18
        case .spacious: 20
        }
    }

    private var titleDragRegion: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: metrics.headerDocumentSymbolSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(
                    width: metrics.headerDocumentSymbolSize,
                    height: metrics.headerDocumentSymbolSize
                )
            Text(Self.title(model: model))
                .font(.system(size: metrics.headerTitleSize, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("privatePresenter.headerDragRegion")
        .accessibilityHidden(true)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let current = NSEvent.mouseLocation
                    let start =
                        dragStartScreenLocation
                        ?? OverlayScreenDragTranslation.inferredStartLocation(
                            currentScreenLocation: current,
                            initialSwiftUITranslation: value.translation
                        )
                    dragStartScreenLocation = start
                    onDragChanged(
                        OverlayScreenDragTranslation.swiftUITranslation(
                            from: start,
                            to: current
                        )
                    )
                }
                .onEnded { _ in
                    dragStartScreenLocation = nil
                    onDragEnded()
                }
        )
    }

    private var symbols: [String] {
        Self.symbols(isPlaying: !model.isPaused, isLocked: model.isLocked)
    }

    private var state: PresenterAccessibility.State {
        PresenterAccessibility.state(model: model)
    }

    private func iconButton(
        index: Int,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        OverlayIconButton(
            symbol: symbols[index],
            iconSize: Self.iconSize(for: metrics.tier),
            diameter: metrics.headerControlDiameter,
            isPrimary: false,
            isSelected: false,
            accessibility: PresenterAccessibility.entry(
                Self.actionIdentifiers[index], state: state
            ),
            toolTipPlacement: .belowTrailing,
            action: action
        )
    }
}
