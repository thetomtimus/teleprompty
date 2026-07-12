import AppKit
import XCTest
@testable import PrivatePresenter

@MainActor
final class OverlayPanelControllerTests: XCTestCase {
    func testShowingNonactivatingPanelNeverActivatesOrMakesKeyOrMain() {
        var operations: [OverlayPanelOperation] = []
        let controller = OverlayPanelController(operationRecorder: { operations.append($0) })
        let selected = NSRect(x: 0, y: 0, width: 1_440, height: 900)

        controller.show(
            proposedFrame: NSRect(x: 100, y: 100, width: 700, height: 350),
            on: selected
        )

        XCTAssertTrue(operations.contains(.orderFrontRegardless))
        XCTAssertFalse(operations.contains(.activateApplication))
        XCTAssertFalse(operations.contains(.showWindow))
        XCTAssertFalse(operations.contains(.makeKey))
        XCTAssertFalse(operations.contains(.makeMain))
        XCTAssertFalse(controller.teleprompterPanel.isKeyWindow)
        XCTAssertFalse(controller.teleprompterPanel.isMainWindow)
    }

    func testLockingAndUnlockingNeverActivatesApplication() {
        var operations: [OverlayPanelOperation] = []
        let controller = OverlayPanelController(operationRecorder: { operations.append($0) })

        controller.setLocked(true)
        controller.setLocked(false)

        XCTAssertEqual(
            operations.filter {
                if case .setLocked = $0 { true } else { false }
            },
            [.setLocked(true), .setLocked(false)]
        )
        XCTAssertFalse(operations.contains(.activateApplication))
        XCTAssertFalse(operations.contains(.makeKey))
        XCTAssertFalse(operations.contains(.makeMain))
    }

    func testOverlayInteractionIsDisabledOnlyWhileLockedAndRestoredWhenUnlocked() {
        let controller = OverlayPanelController()

        controller.setLocked(true)
        XCTAssertTrue(controller.teleprompterPanel.ignoresMouseEvents)

        controller.setLocked(false)
        XCTAssertFalse(controller.teleprompterPanel.ignoresMouseEvents)
    }

#if DEBUG
    func testDiagnosticChordDispatchesDirectlyWithoutRaisingController() {
        let runtime = AppRuntime(proofLevel: .floating)
        let commandCount = runtime.model.commandDispatchCount
        let controllerShowCount = runtime.controllerWindowController.showCount

        runtime.diagnosticHotKeyService.invokeForTesting()

        XCTAssertEqual(runtime.model.commandDispatchCount, commandCount + 1)
        XCTAssertEqual(runtime.controllerWindowController.showCount, controllerShowCount)
    }
#endif

    func testControllerCreatesExactlyOnePanel() {
        let controller = OverlayPanelController()
        let identity = ObjectIdentifier(controller.teleprompterPanel)

        controller.hide()
        controller.stageHidden(
            proposedFrame: NSRect(x: 10, y: 10, width: 600, height: 300),
            on: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.show(
            proposedFrame: NSRect(x: 20, y: 20, width: 600, height: 300),
            on: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(ObjectIdentifier(controller.teleprompterPanel), identity)
        XCTAssertEqual(controller.configurationSnapshot.panelCount, 1)
    }

    func testNoIntermediateSetFrameIsUnsafe() {
        let controller = OverlayPanelController()
        let selected = NSRect(x: -1_920, y: -120, width: 1_920, height: 1_080)
        controller.stageHidden(
            proposedFrame: NSRect(x: 500, y: 500, width: 4_000, height: 2_000),
            on: selected
        )
        _ = controller.applyContainedFrame(
            NSRect(x: -4_000, y: -3_000, width: 20, height: 20)
        )

        XCTAssertFalse(controller.appliedFrames.isEmpty)
        XCTAssertTrue(controller.appliedFrames.allSatisfy(selected.contains))
    }

    func testPanelConstrainFrameIsASecondContainmentDefense() {
        let controller = OverlayPanelController()
        let selected = NSRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
        controller.stageHidden(
            proposedFrame: NSRect(x: -1_500, y: 200, width: 700, height: 350),
            on: selected
        )

        let constrained = controller.teleprompterPanel.constrainFrameRect(
            NSRect(x: 10_000, y: 10_000, width: 4_000, height: 4_000),
            to: nil
        )

        XCTAssertTrue(selected.contains(constrained))
    }

    func testTopologyEffectsPauseHideShieldBeforeQuery() {
        let coordinator = PrivacyCoordinator()

        let effects = coordinator.topologyWillChange()

        XCTAssertEqual(
            Array(effects.prefix(6)),
            [
                .pauseScrolling,
                .hideOverlay,
                .shieldController,
                .invalidatePendingShow,
                .queryTopology,
                .evaluatePrivacy,
            ]
        )
    }

    func testMissingDisplayStagesBuiltInHidden() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let external = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([external]))
        model.selectDisplay(external.id)
        model.confirmSelectedDisplay()

        let builtIn = display(id: 1, builtIn: true, x: 0)
        model.refreshDisplays(.success([builtIn]))

        XCTAssertEqual(model.selectedDisplayID, builtIn.id)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
        XCTAssertEqual(controller.selectedScreenFrame, builtIn.visibleFrame)
    }

    func testCustomResizeHandlesApplyOnlyContainedFrames() {
        let controller = OverlayPanelController()
        let selected = NSRect(x: 0, y: 0, width: 1_000, height: 700)
        controller.stageHidden(
            proposedFrame: NSRect(x: 100, y: 100, width: 500, height: 300),
            on: selected
        )

        let result = controller.interactionController.resize(
            frame: controller.teleprompterPanel.frame,
            edge: .bottomLeft,
            delta: NSSize(width: -2_000, height: -2_000),
            inside: selected
        )

        XCTAssertTrue(selected.contains(result))
        XCTAssertTrue(selected.contains(controller.teleprompterPanel.frame))
    }

    func testWiredDragAndResizeUpdatesRemainContained() {
        let controller = OverlayPanelController()
        let selected = NSRect(x: -1_000, y: -200, width: 1_000, height: 700)
        controller.stageHidden(
            proposedFrame: NSRect(x: -900, y: 0, width: 500, height: 300),
            on: selected
        )

        controller.updateDrag(translation: CGSize(width: 5_000, height: 5_000))
        controller.endInteraction()
        controller.updateResize(
            edge: .bottomLeft,
            translation: CGSize(width: -5_000, height: -5_000)
        )
        controller.endInteraction()

        XCTAssertTrue(controller.appliedFrames.allSatisfy(selected.contains))
        XCTAssertTrue(selected.contains(controller.teleprompterPanel.frame))
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
}
