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
    static let cardRadius: CGFloat = 30
    static let cardBorderWidth: CGFloat = 1
}
