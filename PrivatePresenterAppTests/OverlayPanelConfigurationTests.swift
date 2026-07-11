import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class OverlayPanelConfigurationTests: XCTestCase {
    func testPanelIsBorderlessNonactivatingAndNotNativelyResizable() {
        let controller = makeController()
        let mask = controller.teleprompterPanel.styleMask

        XCTAssertFalse(mask.contains(.titled))
        XCTAssertTrue(mask.contains(.nonactivatingPanel))
        XCTAssertFalse(mask.contains(.resizable))
    }

    func testCustomResizeHandlesApplyOnlyContainedFrames() {
        var applied: [NSRect] = []
        let interaction = ClampedPanelInteractionController { applied.append($0) }
        let screen = NSRect(x: -1_920, y: -200, width: 1_920, height: 1_080)

        interaction.resize(
            frame: NSRect(x: -1_500, y: 100, width: 700, height: 350),
            edge: .topRight,
            delta: NSSize(width: 5_000, height: 5_000),
            inside: screen
        )

        XCTAssertEqual(applied.count, 1)
        XCTAssertTrue(screen.contains(applied[0]))
    }

    func testPanelJoinsAllSpacesAsFullScreenAuxiliary() {
        let behavior = makeController().teleprompterPanel.collectionBehavior
        XCTAssertTrue(behavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
    }

    func testPanelUsesBoundedLevel() {
        for proofLevel in OverlayPanelLevel.allCases {
            let controller = OverlayPanelController(proofLevel: proofLevel)
            XCTAssertEqual(controller.teleprompterPanel.level, proofLevel.appKitLevel)
        }
        XCTAssertEqual(Set(OverlayPanelLevel.allCases.map(\.rawValue)), ["floating", "statusBar"])
    }

    func testLockedPanelIgnoresMouseAndCannotBecomeKeyOrMain() {
        let panel = makeController().teleprompterPanel
        panel.setLocked(true)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testUnlockedPanelRestoresInteraction() {
        let panel = makeController().teleprompterPanel
        panel.setLocked(true)
        panel.setLocked(false)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.canBecomeKey, NSApp.isActive)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testShowDoesNotActivateApplication() {
        let controller = makeController()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        controller.show(
            proposedFrame: NSRect(x: 100, y: 100, width: 700, height: 350),
            on: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        XCTAssertEqual(
            NSWorkspace.shared.frontmostApplication?.processIdentifier,
            frontmostPID
        )
        XCTAssertFalse(controller.teleprompterPanel.isKeyWindow)
        XCTAssertFalse(controller.teleprompterPanel.isMainWindow)
    }

    func testReadingSurfaceInteriorIsOpaque() {
        let snapshot = makeController().configurationSnapshot
        XCTAssertTrue(snapshot.interiorIsFullyOpaque)
        XCTAssertFalse(makeController().teleprompterPanel.isOpaque)
        XCTAssertGreaterThan(OverlayRootView.cornerRadius, 0)
    }

    func testConfigurationSnapshotIsImmutableValue() {
        let controller = makeController()
        let unlocked = controller.configurationSnapshot
        controller.setLocked(true)
        let locked = controller.configurationSnapshot

        XCTAssertFalse(unlocked.isLocked)
        XCTAssertTrue(locked.isLocked)
        XCTAssertFalse(unlocked.ignoresMouseEvents)
        XCTAssertTrue(locked.ignoresMouseEvents)
    }

    private func makeController() -> OverlayPanelController {
        _ = NSApplication.shared
        return OverlayPanelController()
    }
}
