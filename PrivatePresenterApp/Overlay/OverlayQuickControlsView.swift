import SwiftUI
import TeleprompterCore

enum OverlayControlToolTipPlacement {
    case above
    case belowTrailing

    var alignment: Alignment {
        switch self {
        case .above: .top
        case .belowTrailing: .bottomTrailing
        }
    }

    var verticalOffset: CGFloat {
        switch self {
        case .above: -36
        case .belowTrailing: 36
        }
    }
}

struct OverlayControlHoverLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(OverlayVisualTokens.readingText.swiftUIColor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(
                    cornerRadius: OverlayVisualTokens.toolTipRadius,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            OverlayVisualTokens.toolTipTop.swiftUIColor,
                            OverlayVisualTokens.toolTipBottom.swiftUIColor,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: OverlayVisualTokens.toolTipRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        OverlayVisualTokens.toolTipBorder.swiftUIColor,
                        lineWidth: 1
                    )
                }
                .shadow(
                    color: OverlayVisualTokens.toolTipShadow.swiftUIColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A visual button whose policy and semantics are supplied by the app model and
/// the centralized accessibility manifest. Hover and focus are transient render
/// state only; commands remain the sole owner of product state.
@MainActor
struct OverlayIconButton: View {
    let symbol: String
    let iconSize: CGFloat
    let diameter: CGFloat
    let isPrimary: Bool
    let isSelected: Bool
    let accessibility: PresenterAccessibility.Entry
    let toolTipPlacement: OverlayControlToolTipPlacement
    let action: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(
            OverlayIconButtonStyle(
                isHovered: isHovered,
                isPrimary: isPrimary,
                isSelected: isSelected
            )
        )
        .foregroundStyle(
            isPrimary
                ? OverlayVisualTokens.primaryControlForeground.swiftUIColor
                : OverlayVisualTokens.readingText.swiftUIColor
        )
        .frame(width: max(44, diameter), height: max(44, diameter))
        .contentShape(Rectangle())
        .overlay {
            Circle()
                .strokeBorder(
                    OverlayVisualTokens.controlFocus.swiftUIColor,
                    lineWidth: isFocused ? 2 : 0
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: toolTipPlacement.alignment) {
            if isHovered {
                OverlayControlHoverLabel(text: accessibility.label)
                    .offset(y: toolTipPlacement.verticalOffset)
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.96, anchor: .center)
                        )
                    )
            }
        }
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: isHovered
        )
        .opacity(accessibility.isEnabled ? 1 : 0.45)
        .presenterAccessibility(
            accessibility,
            showsSystemToolTip: false
        )
        .zIndex(isHovered ? 100 : 1)
    }
}

private struct OverlayIconButtonStyle: ButtonStyle {
    let isHovered: Bool
    let isPrimary: Bool
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Circle().fill(fill(configuration: configuration))
            }
    }

    private func fill(configuration: Configuration) -> Color {
        if isPrimary {
            return OverlayVisualTokens.primaryControlFill.swiftUIColor
        }
        if configuration.isPressed || isSelected {
            return OverlayVisualTokens.controlPressed.swiftUIColor
        }
        if isHovered {
            return OverlayVisualTokens.controlHover.swiftUIColor
        }
        return Color.clear
    }
}

/// The reference-faithful seven-action quick-control pill. It owns no
/// teleprompter state and dispatches only existing typed commands.
@MainActor
struct OverlayQuickControlsView: View {
    static let actionIdentifiers = [
        "privatePresenter.quickSmaller",
        "privatePresenter.quickLarger",
        "privatePresenter.quickAlignment",
        "privatePresenter.quickSlower",
        "privatePresenter.quickPlayback",
        "privatePresenter.quickFaster",
        "privatePresenter.quickFocus",
    ]

    @Bindable var model: AppModel
    let metrics: OverlayLayoutMetrics

    init(
        model: AppModel,
        metrics: OverlayLayoutMetrics = OverlayLayoutMetrics(
            size: CGSize(width: 700, height: 350)
        )
    ) {
        self.model = model
        self.metrics = metrics
    }

    var body: some View {
        HStack(spacing: metrics.toolbarActionSpacing) {
            iconButton(index: 0) {
                model.send(.decreaseFontSize)
            }
            iconButton(index: 1) {
                model.send(.increaseFontSize)
            }
            iconButton(index: 2) {
                model.send(
                    .setTextAlignment(
                        model.preferences.textAlignment == .left ? .center : .left
                    )
                )
            }
            iconButton(index: 3) {
                model.send(.setSpeed(model.preferences.speedPointsPerSecond - PresenterAccessibility.speedStep))
            }
            iconButton(index: 4, isPrimary: true) {
                model.send(.togglePlayback)
            }
            iconButton(index: 5) {
                model.send(.setSpeed(model.preferences.speedPointsPerSecond + PresenterAccessibility.speedStep))
            }
            iconButton(index: 6, isSelected: model.preferences.isFocusModeEnabled) {
                model.send(.setFocusModeEnabled(!model.preferences.isFocusModeEnabled))
            }
        }
        .padding(.horizontal, metrics.toolbarHorizontalPadding)
        .frame(width: metrics.toolbarWidth, height: metrics.toolbarHeight)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            OverlayVisualTokens.toolbarTop.swiftUIColor,
                            OverlayVisualTokens.toolbarBottom.swiftUIColor,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            OverlayVisualTokens.toolbarBorder.swiftUIColor,
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: metrics.toolbarHasShadow
                        ? OverlayVisualTokens.toolbarShadow.swiftUIColor : Color.clear,
                    radius: metrics.toolbarHasShadow ? 16 : 0,
                    x: 0,
                    y: metrics.toolbarHasShadow ? 8 : 0
                )
        }
        .overlay {
            toolbarDividers
        }
        .accessibilityElement(children: .contain)
    }

    static func symbols(
        isPlaying: Bool,
        alignment: TeleprompterTextAlignment,
        isFocusModeEnabled: Bool
    ) -> [String] {
        [
            "textformat.size.smaller",
            "textformat.size.larger",
            alignment == .left ? "text.alignleft" : "text.aligncenter",
            "minus",
            isPlaying ? "pause.fill" : "play.fill",
            "plus",
            isFocusModeEnabled ? "eye.slash" : "eye",
        ]
    }

    static func iconSize(for tier: OverlayLayoutMetrics.Tier) -> CGFloat {
        switch tier {
        case .compact: 16
        case .standard: 18
        case .spacious: 20
        }
    }

    private var symbols: [String] {
        Self.symbols(
            isPlaying: !model.isPaused,
            alignment: model.preferences.textAlignment,
            isFocusModeEnabled: model.preferences.isFocusModeEnabled
        )
    }

    private var state: PresenterAccessibility.State {
        PresenterAccessibility.state(model: model)
    }

    private func iconButton(
        index: Int,
        isPrimary: Bool = false,
        isSelected: Bool = false,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        OverlayIconButton(
            symbol: symbols[index],
            iconSize: Self.iconSize(for: metrics.tier),
            diameter: metrics.controlDiameter,
            isPrimary: isPrimary,
            isSelected: isSelected,
            accessibility: PresenterAccessibility.entry(
                Self.actionIdentifiers[index], state: state
            ),
            toolTipPlacement: .above,
            action: action
        )
    }

    @ViewBuilder
    private var toolbarDividers: some View {
        if metrics.toolbarHasDividers {
            GeometryReader { _ in
                Rectangle()
                    .fill(OverlayVisualTokens.toolbarDivider.swiftUIColor)
                    .frame(width: 1, height: 29)
                    .position(x: dividerX(afterControl: 2), y: metrics.toolbarHeight / 2)
                Rectangle()
                    .fill(OverlayVisualTokens.toolbarDivider.swiftUIColor)
                    .frame(width: 1, height: 29)
                    .position(x: dividerX(afterControl: 6), y: metrics.toolbarHeight / 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func dividerX(afterControl controlCount: CGFloat) -> CGFloat {
        metrics.toolbarHorizontalPadding
            + controlCount * metrics.controlDiameter
            + (controlCount - 0.5) * metrics.toolbarActionSpacing
    }
}
