import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class AppModelTests: XCTestCase {
    func testControllerStartsShielded() {
        let model = DiagnosticHarnessModel(overlayController: OverlayPanelController())
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertTrue(model.isPaused)
    }

    func testControllerNeverReopensUnredactedOnExternalScreen() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let projector = display(id: 2, builtIn: false, x: 1_440)

        model.refreshDisplays(.success([projector]))

        XCTAssertNil(model.selectedDisplayID)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testRecoveryRequiresConfirmationAndNeverAutoResumes() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([builtIn, projector]))
        model.confirmSelectedDisplay()
        model.showOverlay()

        model.topologyWillChange()
        model.refreshDisplays(.success([builtIn, projector]))

        XCTAssertTrue(model.isPaused)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testExplicitExternalConfirmationMovesWhileShieldedBeforeReveal() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let privateExternal = display(id: 3, builtIn: false, x: -1_440)
        var wasShieldedDuringMove = false
        var movedDisplayID: UInt32?
        model.onConfirmedDisplay = { display in
            wasShieldedDuringMove = model.isShielded
            movedDisplayID = display.id
        }

        model.refreshDisplays(.success([privateExternal]))
        model.selectDisplay(privateExternal.id)
        model.confirmSelectedDisplay()

        XCTAssertTrue(wasShieldedDuringMove)
        XCTAssertEqual(movedDisplayID, privateExternal.id)
        XCTAssertFalse(model.isShielded)
        XCTAssertTrue(model.isSelectionConfirmed)
    }

    func testMirroringFailsClosedWithRequiredWarning() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let mirrored = RuntimeDisplay(
            id: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            isMain: true,
            isOnline: true,
            frame: NSRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "built-in",
            mirrorSourceID: 2,
            isInMirrorSet: true
        )

        model.refreshDisplays(.success([mirrored]))

        XCTAssertEqual(model.warning, DiagnosticHarnessModel.mirroringWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testAnyMirroredPairBlocksNonmirroredSelection() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let mirrorSource = mirroredDisplay(id: 2, name: "Mirror Source", sourceID: nil)
        let mirror = mirroredDisplay(id: 3, name: "Projector", sourceID: 2)

        model.refreshDisplays(.success([privateDisplay, mirrorSource, mirror]))
        model.selectDisplay(privateDisplay.id)
        model.confirmSelectedDisplay()
        model.showOverlay()

        XCTAssertEqual(model.warning, DiagnosticHarnessModel.mirroringWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testQueryFailureFailsClosed() {
        struct QueryFailure: Error {}
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)

        model.refreshDisplays(.failure(QueryFailure()))

        XCTAssertEqual(model.warning, DiagnosticHarnessModel.queryFailureWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertNil(model.selectedDisplayID)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testAmbiguousWeakDisplaysRequireExplicitSessionSelection() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let first = duplicateDisplay(id: 10, x: 0)
        let second = duplicateDisplay(id: 11, x: 1_440)

        model.refreshDisplays(.success([first, second]))
        model.selectDisplay(second.id)

        XCTAssertEqual(model.warning, DiagnosticHarnessModel.ambiguityWarning)
        XCTAssertTrue(model.isShielded)

        model.confirmSelectedDisplay()

        XCTAssertEqual(model.selectedDisplayID, second.id)
        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertFalse(model.isShielded)
    }

    func testWeakBuiltInRemainsShieldedUntilCurrentSessionConfirmation() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let builtIn = display(id: 1, builtIn: true, x: 0)

        model.refreshDisplays(.success([builtIn]))

        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)

        model.confirmSelectedDisplay()

        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertFalse(model.isShielded)
        XCTAssertEqual(model.warning, DiagnosticHarnessModel.noSeparationWarning)
    }

    func testOfflineSelectionCannotBeConfirmedOrShown() {
        let controller = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: controller)
        let offline = RuntimeDisplay(
            id: 9,
            localizedName: "Offline Display",
            isBuiltIn: true,
            isMain: true,
            isOnline: false,
            frame: NSRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "offline",
            mirrorSourceID: nil,
            isInMirrorSet: false
        )

        model.refreshDisplays(.success([offline]))
        model.selectDisplay(offline.id)
        model.confirmSelectedDisplay()
        model.showOverlay()

        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testSafeConfirmationPublishesOnlyAfterShieldedMove() {
        let controller = OverlayPanelController()
        let coordinator = PrivacyCoordinator()
        let model = DiagnosticHarnessModel(
            overlayController: controller,
            privacyCoordinator: coordinator
        )
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)

        model.refreshDisplays(.success([builtIn, projector]))
        model.confirmSelectedDisplay()

        XCTAssertEqual(
            Array(coordinator.lastEffects.suffix(2)),
            [.moveWindowsWhileShielded(screenID: builtIn.id), .publishSafeState]
        )
        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertFalse(model.isShielded)
    }

    func testStaleProjectorFrameIsIgnoredWhileControllerRemainsShielded() {
        let overlay = OverlayPanelController()
        let model = DiagnosticHarnessModel(overlayController: overlay)
        let staleProjectorFrame = NSRect(x: 1_700, y: 100, width: 620, height: 360)
        let controller = ControllerWindowController(
            model: model,
            untrustedInitialFrame: staleProjectorFrame
        )
        let builtIn = display(id: 1, builtIn: true, x: 0)

        XCTAssertEqual(controller.window?.frame, staleProjectorFrame)
        controller.showShielded(on: builtIn)

        XCTAssertTrue(model.isShielded)
        XCTAssertTrue(
            builtIn.visibleFrame.contains(controller.window?.frame ?? .zero)
        )
    }

    private func display(id: UInt32, builtIn: Bool, x: CGFloat) -> RuntimeDisplay {
        RuntimeDisplay(
            id: id,
            localizedName: builtIn ? "Built-in Display" : "Projector",
            isBuiltIn: builtIn,
            isMain: builtIn,
            isOnline: true,
            frame: NSRect(x: x, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: x, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "display-\(id)",
            mirrorSourceID: nil,
            isInMirrorSet: false
        )
    }

    private func mirroredDisplay(
        id: UInt32,
        name: String,
        sourceID: UInt32?
    ) -> RuntimeDisplay {
        RuntimeDisplay(
            id: id,
            localizedName: name,
            isBuiltIn: false,
            isMain: false,
            isOnline: true,
            frame: NSRect(x: CGFloat(id) * 1_440, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(
                x: CGFloat(id) * 1_440,
                y: 0,
                width: 1_440,
                height: 860
            ),
            scale: 2,
            persistentUUID: "display-\(id)",
            mirrorSourceID: sourceID,
            isInMirrorSet: true
        )
    }

    private func duplicateDisplay(id: UInt32, x: CGFloat) -> RuntimeDisplay {
        RuntimeDisplay(
            id: id,
            localizedName: "Identical Display",
            isBuiltIn: false,
            isMain: id == 10,
            isOnline: true,
            frame: NSRect(x: x, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: x, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "duplicate-uuid",
            mirrorSourceID: nil,
            isInMirrorSet: false
        )
    }
}
