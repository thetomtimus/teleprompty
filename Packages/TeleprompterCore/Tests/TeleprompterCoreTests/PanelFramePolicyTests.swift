import XCTest

@testable import TeleprompterCore

final class PanelFramePolicyTests: XCTestCase {
    private let policy = PanelFramePolicy(safeTopInset: 24)

    func testDefaultFrameIsTopCenteredSeventyByThirtyFivePercent() {
        let screen = DisplayRect(x: 100, y: 50, width: 1_000, height: 800)

        let frame = policy.defaultFrame(in: screen)

        XCTAssertEqual(frame.width, 700, accuracy: 0.000_1)
        XCTAssertEqual(frame.height, 280, accuracy: 0.000_1)
        XCTAssertEqual(frame.x, 250, accuracy: 0.000_1)
        XCTAssertEqual(frame.maxY, screen.maxY - 24, accuracy: 0.000_1)
        XCTAssertTrue(screen.contains(frame))
    }

    func testNormalizedFrameRestoresOnSameFingerprint() {
        let screen = DisplayRect(x: -1_920, y: 180, width: 1_920, height: 1_040)
        let original = DisplayRect(x: -1_700, y: 500, width: 900, height: 420)

        let normalized = policy.normalize(original, in: screen)
        let restored = policy.restore(normalized, in: screen)

        XCTAssertEqual(restored.x, original.x, accuracy: 0.000_1)
        XCTAssertEqual(restored.y, original.y, accuracy: 0.000_1)
        XCTAssertEqual(restored.width, original.width, accuracy: 0.000_1)
        XCTAssertEqual(restored.height, original.height, accuracy: 0.000_1)
    }

    func testEveryIntermediateDragFrameStaysContained() {
        let screen = DisplayRect(x: 0, y: 0, width: 1_440, height: 900)
        var frame = DisplayRect(x: 400, y: 350, width: 700, height: 320)

        for _ in 0..<100 {
            frame = policy.translatedFrame(frame, deltaX: 50, deltaY: 35, in: screen)
            XCTAssertTrue(screen.contains(frame))
        }

        for _ in 0..<100 {
            frame = policy.translatedFrame(frame, deltaX: -60, deltaY: -45, in: screen)
            XCTAssertTrue(screen.contains(frame))
        }
    }

    func testResizeCannotCrossAdjacentScreen() {
        let selectedScreen = DisplayRect(x: 0, y: 0, width: 1_440, height: 900)
        let initial = DisplayRect(x: 900, y: 300, width: 500, height: 300)

        let resized = policy.resizedFrame(
            initial,
            edges: [.right, .top],
            deltaX: 800,
            deltaY: 600,
            in: selectedScreen
        )

        XCTAssertTrue(selectedScreen.contains(resized))
        XCTAssertEqual(resized.maxX, selectedScreen.maxX, accuracy: 0.000_1)
        XCTAssertEqual(resized.maxY, selectedScreen.maxY, accuracy: 0.000_1)
    }

    func testNegativeAndVerticalLayoutsStayContained() {
        let layouts = [
            DisplayRect(x: -2_560, y: -400, width: 2_560, height: 1_400),
            DisplayRect(x: 100, y: 1_080, width: 1_600, height: 900),
        ]
        let unsafe = DisplayRect(x: -10_000, y: 10_000, width: 4_000, height: 4_000)

        for screen in layouts {
            let clamped = policy.clamp(unsafe, to: screen)
            XCTAssertTrue(screen.contains(clamped))
        }
    }

    func testResolutionChangeReclamps() {
        let originalScreen = DisplayRect(x: 0, y: 0, width: 2_560, height: 1_440)
        let smallerScreen = DisplayRect(x: 0, y: 0, width: 1_280, height: 720)
        let original = DisplayRect(x: 1_200, y: 600, width: 1_100, height: 600)
        let normalized = policy.normalize(original, in: originalScreen)

        let restored = policy.restore(normalized, in: smallerScreen)

        XCTAssertTrue(smallerScreen.contains(restored))
        XCTAssertLessThanOrEqual(restored.width, smallerScreen.width)
        XCTAssertLessThanOrEqual(restored.height, smallerScreen.height)
    }
}
