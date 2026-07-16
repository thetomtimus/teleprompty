import AppKit
import SwiftUI
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class OverlayVisualSnapshotTests: XCTestCase {
    func testReferenceSurfaceUsesExactOpaqueNavyTokens() throws {
        let stops = OverlayVisualTokens.cardGradientStops
        XCTAssertEqual(stops.map(\.location), [0.00, 0.42, 1.00])
        try assertColor(stops[0].color.appKitColor, red: 52, green: 70, blue: 111, alpha: 1)
        try assertColor(stops[1].color.appKitColor, red: 44, green: 61, blue: 99, alpha: 1)
        try assertColor(stops[2].color.appKitColor, red: 32, green: 43, blue: 75, alpha: 1)
        try assertColor(OverlayVisualTokens.readingText.appKitColor, red: 247, green: 248, blue: 252, alpha: 1)
        try assertColor(OverlayVisualTokens.cardBorder.appKitColor, red: 255, green: 255, blue: 255, alpha: 0.24)
        XCTAssertEqual(OverlayVisualTokens.cardRadius, 30)
        XCTAssertEqual(OverlayVisualTokens.cardBorderWidth, 1)
    }

    func testRoundedInteriorIsOpaqueOverWhiteAndBlack() throws {
        let hosting = NSHostingView(
            rootView: OverlayRootView().frame(width: 320, height: 180)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(
            hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        )
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        let interiorSamples = [
            NSPoint(x: 40, y: 40), NSPoint(x: 160, y: 40),
            NSPoint(x: 280, y: 40), NSPoint(x: 40, y: 90),
            NSPoint(x: 160, y: 90), NSPoint(x: 280, y: 90),
            NSPoint(x: 40, y: 140), NSPoint(x: 160, y: 140),
            NSPoint(x: 280, y: 140),
        ]
        for point in interiorSamples {
            let rendered = try XCTUnwrap(
                bitmap.colorAt(x: Int(point.x), y: Int(point.y))?.usingColorSpace(.sRGB)
            )
            XCTAssertEqual(rendered.alphaComponent, 1, accuracy: 0.001)
            for backdrop in [NSColor.white, NSColor.black] {
                let composited = composite(rendered, over: backdrop)
                XCTAssertEqual(composited.red, rendered.redComponent, accuracy: 0.001)
                XCTAssertEqual(composited.green, rendered.greenComponent, accuracy: 0.001)
                XCTAssertEqual(composited.blue, rendered.blueComponent, accuracy: 0.001)
            }
        }
    }

    func testNoTitleBarScrollbarGlowOrCompetingReaderFill() {
        let panel = TeleprompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 350)
        )
        XCTAssertFalse(panel.styleMask.contains(.titled))
        XCTAssertFalse(panel.styleMask.contains(.resizable))
        XCTAssertFalse(panel.isOpaque)
        XCTAssertTrue(panel.hasShadow)

        let system = ReaderTextSystem(text: "Synthetic visual test copy", revision: 0)
        let reader = ReaderTextView.makeReaderView(system: system)
        XCTAssertEqual(reader.subviews.count, 3)
        XCTAssertTrue(reader.subviews[0] === reader.backgroundView)
        XCTAssertTrue(reader.subviews[1] === system.activeBandView)
        XCTAssertTrue(reader.subviews[2] === reader.scrollView)
        XCTAssertEqual(reader.backgroundView.identifier?.rawValue, "privatePresenter.readerBackground")
        XCTAssertEqual(reader.backgroundView.layer?.backgroundColor?.alpha, 0)
        XCTAssertFalse(reader.scrollView.drawsBackground)
        XCTAssertFalse(reader.scrollView.contentView.drawsBackground)
        XCTAssertFalse(system.textView.drawsBackground)
        XCTAssertFalse(reader.scrollView.hasVerticalScroller)
        XCTAssertFalse(reader.scrollView.hasHorizontalScroller)
    }

    func testReaderUsesSystemTypographyAndReferenceSpacing() throws {
        let system = ReaderTextSystem(text: "Reference typography", revision: 0)
        system.updateAttributes(fontSize: 42, fontWeight: .regular, alignment: .left)
        let attributes = system.textStorage.attributes(at: 0, effectiveRange: nil)
        let font = try XCTUnwrap(attributes[.font] as? NSFont)
        let paragraph = try XCTUnwrap(attributes[.paragraphStyle] as? NSParagraphStyle)
        let foreground = try XCTUnwrap(attributes[.foregroundColor] as? NSColor)

        XCTAssertEqual(font.pointSize, 42)
        XCTAssertEqual(ReaderTextSystem.appKitWeight(for: .regular), .regular)
        XCTAssertEqual(paragraph.lineHeightMultiple, 1.42, accuracy: 0.000_001)
        XCTAssertEqual(paragraph.paragraphSpacing, 0)
        XCTAssertEqual(paragraph.alignment, .left)
        XCTAssertEqual(paragraph.hyphenationFactor, 0)
        XCTAssertNil(attributes[.underlineStyle])
        XCTAssertNil(attributes[.link])
        try assertColor(foreground, red: 247, green: 248, blue: 252, alpha: 1)

        let compact = OverlayLayoutMetrics(size: CGSize(width: 320, height: 180))
        let standard = OverlayLayoutMetrics(size: CGSize(width: 700, height: 350))
        let spacious = OverlayLayoutMetrics(size: CGSize(width: 1_036, height: 460))
        let wide = OverlayLayoutMetrics(size: CGSize(width: 1_440, height: 460))
        XCTAssertEqual(compact.tier, .compact)
        XCTAssertEqual(standard.tier, .standard)
        XCTAssertEqual(spacious.tier, .spacious)
        XCTAssertEqual((compact.headerHeight, compact.readingSideInset), (52, 20))
        XCTAssertEqual((standard.headerHeight, standard.readingSideInset), (72, 48))
        XCTAssertEqual((spacious.headerHeight, spacious.readingSideInset), (92, 52))
        XCTAssertEqual(wide.effectiveReadingSideInset, 195)
        XCTAssertLessThanOrEqual(wide.readableLineWidth, 1_050)
    }

    func testPersistedWeightMapsWithoutReplacingText() {
        let system = ReaderTextSystem(text: "Persisted weight", revision: 0)
        let storage = system.textStorage
        let replacements = system.fullReplacementCount
        let expected: [(TeleprompterFontWeight, NSFont.Weight)] = [
            (.regular, .regular), (.medium, .medium), (.semibold, .semibold),
        ]

        for (weight, appKitWeight) in expected {
            system.updateAttributes(fontSize: 42, fontWeight: weight, alignment: .left)
            XCTAssertEqual(ReaderTextSystem.appKitWeight(for: weight), appKitWeight)
            XCTAssertTrue(system.textStorage === storage)
            XCTAssertEqual(system.textStorage.string, "Persisted weight")
            XCTAssertEqual(system.fullReplacementCount, replacements)
        }
    }

    func testActiveBandUsesTwoCachedTextKit2LineFragmentsForEveryWeightAtDefaultAndLargeSizes() {
        let text = (1...40).map { "Synthetic reference line \($0)" }.joined(separator: "\n")
        for weight in TeleprompterFontWeight.allCases {
            for (fontSize, size) in [
                (42.0, NSSize(width: 700, height: 350)),
                (96.0, NSSize(width: 1_036, height: 460)),
            ] {
                let viewport = makeReader(
                    text: text, size: size, fontSize: fontSize, fontWeight: weight
                )
                XCTAssertEqual(viewport.container.resolvedBandFragments.count, 2)
                let unconstrained = viewport.container.resolvedBandFragments
                    .reduce(12) { $0 + $1.frame.height }
                XCTAssertEqual(
                    viewport.container.resolvedActiveBandHeight,
                    min(unconstrained, viewport.container.maximumActiveBandHeight),
                    accuracy: 1
                )
            }
        }
    }

    func testBandLineSelectionUsesNearestThenAdjacentWithFollowingTieBreak() {
        let lines = [
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 0..<1, frame: NSRect(x: 0, y: 0, width: 100, height: 20)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 1..<2, frame: NSRect(x: 0, y: 30, width: 100, height: 20)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 2..<3, frame: NSRect(x: 0, y: 60, width: 100, height: 20)
            ),
        ]
        let selected = ReaderViewportAdapter.selectActiveBandLineFragments(
            from: lines, targetY: 40
        )
        XCTAssertEqual(selected.map(\.utf16Range), [1..<2, 2..<3])

        let nearestTie = ReaderViewportAdapter.selectActiveBandLineFragments(
            from: lines, targetY: 25
        )
        XCTAssertEqual(nearestTie.map(\.utf16Range), [1..<2, 2..<3])
    }

    func testActiveBandOneAndZeroFragmentFallbacksAndCompactClampDoNotClipGlyphs() {
        let line = ReaderViewportAdapter.LineFragmentEvidence(
            utf16Range: 0..<1, frame: NSRect(x: 0, y: 0, width: 100, height: 44)
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [line], fallbackLineHeight: 50, maximumHeight: 200
            ),
            100
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [], fallbackLineHeight: 50, maximumHeight: 200
            ),
            112
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [], fallbackLineHeight: 50, maximumHeight: 34
            ),
            34
        )
    }

    func testBandMetricsCreateNoSecondTextLayoutManagerOrCacheOwner() throws {
        let viewport = makeReader(
            text: "One\nTwo\nThree\nFour", size: NSSize(width: 700, height: 350)
        )
        let manager = try XCTUnwrap(viewport.system.textView.textLayoutManager)
        _ = viewport.adapter.cachedActiveBandLineFragments(viewportFraction: 0.5)
        XCTAssertTrue(viewport.system.textView.textLayoutManager === manager)
        let source = try String(
            contentsOf: sourceURL("ReaderViewportAdapter.swift"), encoding: .utf8
        )
        let queryStart = try XCTUnwrap(source.range(of: "func cachedActiveBandLineFragments"))
        let querySource = source[queryStart.lowerBound...]
        XCTAssertFalse(querySource.prefix(1_200).contains("ensureLayout("))
        XCTAssertFalse(querySource.prefix(1_200).contains("NSTextLayoutManager("))
    }

    func testLiteralTextAndBandContrastThresholds() {
        let text = (247.0 / 255, 248.0 / 255, 252.0 / 255)
        let cardStops = [
            (52.0 / 255, 70.0 / 255, 111.0 / 255),
            (44.0 / 255, 61.0 / 255, 99.0 / 255),
            (32.0 / 255, 43.0 / 255, 75.0 / 255),
        ]
        for card in cardStops {
            XCTAssertGreaterThanOrEqual(contrast(text, card), 7)
            for band in [
                (130.0 / 255, 160.0 / 255, 213.0 / 255, 0.28),
                (113.0 / 255, 145.0 / 255, 202.0 / 255, 0.35),
                (130.0 / 255, 160.0 / 255, 213.0 / 255, 0.20),
            ] {
                let composited = (
                    band.0 * band.3 + card.0 * (1 - band.3),
                    band.1 * band.3 + card.1 * (1 - band.3),
                    band.2 * band.3 + card.2 * (1 - band.3)
                )
                XCTAssertGreaterThanOrEqual(contrast(text, composited), 4.5)
            }
        }
    }

    private func assertColor(
        _ color: NSColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let converted = try XCTUnwrap(color.usingColorSpace(.sRGB), file: file, line: line)
        XCTAssertEqual(converted.redComponent, red / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.greenComponent, green / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.blueComponent, blue / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.alphaComponent, alpha, accuracy: 0.000_001, file: file, line: line)
    }

    private func composite(
        _ foreground: NSColor,
        over background: NSColor
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let alpha = foreground.alphaComponent
        return (
            foreground.redComponent * alpha + background.redComponent * (1 - alpha),
            foreground.greenComponent * alpha + background.greenComponent * (1 - alpha),
            foreground.blueComponent * alpha + background.blueComponent * (1 - alpha)
        )
    }

    private func makeReader(
        text: String,
        size: NSSize,
        fontSize: Double = 42,
        fontWeight: TeleprompterFontWeight = .regular
    ) -> (
        system: ReaderTextSystem,
        container: ReaderViewportContainerView,
        adapter: ReaderViewportAdapter
    ) {
        let system = ReaderTextSystem(text: text, revision: 0)
        system.updateAttributes(
            fontSize: fontSize, fontWeight: fontWeight, alignment: .left
        )
        let container = ReaderTextView.makeReaderView(system: system)
        container.frame = NSRect(origin: .zero, size: size)
        container.layoutSubtreeIfNeeded()
        return (system, container, container.viewportAdapter)
    }

    private func sourceURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Overlay")
            .appendingPathComponent(file)
    }

    private func contrast(
        _ lhs: (Double, Double, Double),
        _ rhs: (Double, Double, Double)
    ) -> Double {
        let first = luminance(lhs)
        let second = luminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func luminance(_ color: (Double, Double, Double)) -> Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.0) + 0.7152 * linear(color.1)
            + 0.0722 * linear(color.2)
    }
}
