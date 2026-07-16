import AppKit
import SwiftUI

/// The sole production source for M6 visual values. Test oracles repeat literals.
@MainActor
enum OverlayVisualTokens {
    struct NamedSRGBColor {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let opacity: CGFloat

        var swiftUIColor: Color {
            Color(
                .sRGB,
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                opacity: Double(opacity)
            )
        }

        var appKitColor: NSColor {
            NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)
        }
    }

    struct CardGradientStop {
        let location: CGFloat
        let color: NamedSRGBColor
    }

    static let cardGradientStops = [
        CardGradientStop(
            location: 0.00,
            color: NamedSRGBColor(
                red: 52.0 / 255, green: 70.0 / 255, blue: 111.0 / 255, opacity: 1
            )
        ),
        CardGradientStop(
            location: 0.42,
            color: NamedSRGBColor(
                red: 44.0 / 255, green: 61.0 / 255, blue: 99.0 / 255, opacity: 1
            )
        ),
        CardGradientStop(
            location: 1.00,
            color: NamedSRGBColor(
                red: 32.0 / 255, green: 43.0 / 255, blue: 75.0 / 255, opacity: 1
            )
        ),
    ]

    static let readingText = NamedSRGBColor(
        red: 247.0 / 255, green: 248.0 / 255, blue: 252.0 / 255, opacity: 1
    )
    static let cardBorder = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.24)
    static let headerDivider = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.08)
    static let activeBandLeading = NamedSRGBColor(
        red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.28
    )
    static let activeBandMiddle = NamedSRGBColor(
        red: 113.0 / 255, green: 145.0 / 255, blue: 202.0 / 255, opacity: 0.35
    )
    static let activeBandTrailing = NamedSRGBColor(
        red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.20
    )
    static let activeBandAccent = NamedSRGBColor(
        red: 190.0 / 255, green: 211.0 / 255, blue: 248.0 / 255, opacity: 0.62
    )
    static let toolbarTop = NamedSRGBColor(
        red: 90.0 / 255, green: 113.0 / 255, blue: 165.0 / 255, opacity: 0.98
    )
    static let toolbarBottom = NamedSRGBColor(
        red: 70.0 / 255, green: 92.0 / 255, blue: 145.0 / 255, opacity: 0.98
    )
    static let toolbarBorder = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.13)
    static let toolbarDivider = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.18)
    static let toolbarShadow = NamedSRGBColor(
        red: 7.0 / 255, green: 12.0 / 255, blue: 30.0 / 255, opacity: 0.34
    )
    static let controlHover = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.09)
    static let controlPressed = NamedSRGBColor(red: 1, green: 1, blue: 1, opacity: 0.14)
    static let primaryControlFill = readingText
    static let primaryControlForeground = NamedSRGBColor(
        red: 38.0 / 255, green: 54.0 / 255, blue: 84.0 / 255, opacity: 1
    )
    static let controlFocus = NamedSRGBColor(
        red: 190.0 / 255, green: 211.0 / 255, blue: 248.0 / 255, opacity: 0.88
    )
    static let cardRadius: CGFloat = 30
    static let cardBorderWidth: CGFloat = 1
    static let activeBandRadius: CGFloat = 8
    static let activeBandAccentWidth: CGFloat = 3
}

struct OverlayLayoutMetrics: Equatable {
    enum Tier: Equatable {
        case compact
        case standard
        case spacious
    }

    let size: CGSize
    let tier: Tier
    let headerHeight: CGFloat
    let readingSideInset: CGFloat
    let readingTopReserve: CGFloat
    let readingBottomReserve: CGFloat
    let toolbarHeight: CGFloat
    let toolbarBottomInset: CGFloat
    let toolbarWidth: CGFloat
    let headerHorizontalPadding: CGFloat
    let headerActionSpacing: CGFloat
    let headerDocumentSymbolSize: CGFloat
    let headerTitleSize: CGFloat
    let controlIconSize: CGFloat
    let controlDiameter: CGFloat
    let toolbarActionSpacing: CGFloat
    let toolbarHorizontalPadding: CGFloat
    let toolbarHasDividers: Bool
    let toolbarHasShadow: Bool

    init(size: CGSize) {
        self.size = size
        if size.width >= 800, size.height >= 400 {
            tier = .spacious
            headerHeight = 92
            readingSideInset = 52
            readingTopReserve = 124
            readingBottomReserve = 114
            toolbarHeight = 65
            toolbarBottomInset = 24
            toolbarWidth = 387
            headerHorizontalPadding = 46
            headerActionSpacing = 4
            headerDocumentSymbolSize = 23
            headerTitleSize = 23
            controlIconSize = 20
            controlDiameter = 49
            toolbarActionSpacing = 4
            toolbarHorizontalPadding = 10
            toolbarHasDividers = true
            toolbarHasShadow = true
        } else if size.width >= 520, size.height >= 280 {
            tier = .standard
            headerHeight = 72
            readingSideInset = 48
            readingTopReserve = 96
            readingBottomReserve = 90
            toolbarHeight = 56
            toolbarBottomInset = 18
            toolbarWidth = 348
            headerHorizontalPadding = 32
            headerActionSpacing = 4
            headerDocumentSymbolSize = 20
            headerTitleSize = 18
            controlIconSize = 18
            controlDiameter = 44
            toolbarActionSpacing = 4
            toolbarHorizontalPadding = 8
            toolbarHasDividers = true
            toolbarHasShadow = true
        } else {
            tier = .compact
            headerHeight = 52
            readingSideInset = 20
            readingTopReserve = 58
            readingBottomReserve = 88
            toolbarHeight = 52
            toolbarBottomInset = 30
            toolbarWidth = 316
            headerHorizontalPadding = 20
            headerActionSpacing = 4
            headerDocumentSymbolSize = 18
            headerTitleSize = 16
            controlIconSize = 16
            controlDiameter = 44
            toolbarActionSpacing = 0
            toolbarHorizontalPadding = 4
            toolbarHasDividers = false
            toolbarHasShadow = false
        }
    }

    var effectiveReadingSideInset: CGFloat {
        max(readingSideInset, (size.width - 1_050) / 2)
    }

    var readableLineWidth: CGFloat {
        min(1_050, max(0, size.width - 2 * effectiveReadingSideInset))
    }

    var maximumActiveBandHeight: CGFloat {
        let reservedHeight = size.height - readingTopReserve - readingBottomReserve
        let compactFloor: CGFloat = tier == .compact ? 34 : 0
        return min(size.height, max(compactFloor, reservedHeight))
    }
}
