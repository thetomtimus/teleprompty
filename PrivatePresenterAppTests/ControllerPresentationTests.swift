import XCTest

@testable import PrivatePresenter

@MainActor
final class ControllerPresentationTests: XCTestCase {
    func testEmptyInstructionAndDisabledStart() {
        let presentation = ControllerPresentation(
            scriptText: "",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertEqual(presentation.emptyInstruction, ControllerPresentation.emptyScriptInstruction)
        XCTAssertFalse(presentation.isEnabled(.start))
        XCTAssertFalse(presentation.isEnabled(.clear))
    }

    func testClearPresentsConfirmation() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: true
        )

        XCTAssertTrue(presentation.isClearConfirmationRequired)
        XCTAssertTrue(presentation.isEnabled(.clear))
    }

    func testWhitespaceOnlyScriptUsesEmptyInstruction() {
        let presentation = ControllerPresentation(
            scriptText: " \n\t ",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertEqual(presentation.emptyInstruction, ControllerPresentation.emptyScriptInstruction)
        XCTAssertFalse(presentation.isEnabled(.start))
    }

    func testNonemptyM2ScriptStillExplainsScrollingIsM3() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertEqual(presentation.explanation(for: .start), ControllerPresentation.m3Explanation)
        XCTAssertEqual(presentation.explanation(for: .speed), ControllerPresentation.m3Explanation)
        XCTAssertFalse(presentation.isEnabled(.start))
    }

    func testM2StartPauseRestartDoNotDispatchPlaybackCommands() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertNil(presentation.productCommand(for: .start))
        XCTAssertNil(presentation.productCommand(for: .pause))
        XCTAssertNil(presentation.productCommand(for: .restart))
        XCTAssertNil(presentation.productCommand(for: .speed))
    }

    func testM2FocusModeExplainsM4AndDoesNotChangeChrome() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertEqual(presentation.explanation(for: .focusMode), ControllerPresentation.m4Explanation)
        XCTAssertFalse(presentation.isEnabled(.focusMode))
        XCTAssertNil(presentation.productCommand(for: .focusMode))
    }

    func testProductControllerExposesOpenCloseAndHideShowThroughOnePanelState() {
        let hidden = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )
        let visible = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: true,
            isClearConfirmationRequired: false
        )

        if case .showOverlay? = hidden.productCommand(for: .openClose) {} else {
            XCTFail("Open must use the existing panel show command")
        }
        if case .showOverlay? = hidden.productCommand(for: .hideShow) {} else {
            XCTFail("Show must use the existing panel show command")
        }
        if case .hideOverlay? = visible.productCommand(for: .openClose) {} else {
            XCTFail("Close must use the existing panel hide command")
        }
        if case .hideOverlay? = visible.productCommand(for: .hideShow) {} else {
            XCTFail("Hide must use the existing panel hide command")
        }
    }
}
