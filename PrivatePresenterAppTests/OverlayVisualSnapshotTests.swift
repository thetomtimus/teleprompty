import AppKit
import SwiftUI
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
}
