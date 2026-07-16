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

    init(
        model: AppModel,
        metrics: OverlayLayoutMetrics = OverlayLayoutMetrics(
            size: CGSize(width: 700, height: 350)
        ),
        onDragChanged: @escaping (CGSize) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {}
    ) {
        self.model = model
        self.metrics = metrics
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    var body: some View {
        HStack(spacing: metrics.headerActionSpacing) {
            titleDragRegion
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
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .foregroundStyle(OverlayVisualTokens.readingText.swiftUIColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OverlayVisualTokens.headerDivider.swiftUIColor)
                .frame(height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
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
                .onChanged { onDragChanged($0.translation) }
                .onEnded { _ in onDragEnded() }
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
            diameter: 44,
            isPrimary: false,
            isSelected: false,
            accessibility: PresenterAccessibility.entry(
                Self.actionIdentifiers[index], state: state
            ),
            action: action
        )
        .zIndex(1)
    }
}
