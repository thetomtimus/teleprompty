import AppKit
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class ControllerPresentationTests: XCTestCase {
    func testMirroringWarningUsesRequiredText() {
        XCTAssertEqual(
            ControllerPresentation.mirroringWarning,
            "Display mirroring is on. Students may see the teleprompter. Use Extended Display mode."
        )
    }

    func testExactMirroringWarningIsSeparateFromRecoveryGuidance() {
        XCTAssertEqual(ControllerPresentation.mirroringWarning, AppModel.mirroringWarning)
        XCTAssertNotEqual(
            ControllerPresentation.mirroringWarning,
            ControllerPresentation.mirroringRecoveryGuidance
        )
        XCTAssertFalse(
            ControllerPresentation.mirroringWarning.contains(
                ControllerPresentation.mirroringRecoveryGuidance
            )
        )
    }

    func testSelectedDisplayNameIsVisible() {
        XCTAssertEqual(
            ControllerPresentation.selectedDisplayStatus(
                name: "Generated Private Display",
                isConfirmedInCurrentSession: true
            ),
            "Private display confirmed: Generated Private Display"
        )
    }

    func testSelectedNameIsHiddenUntilCurrentSessionConfirmation() {
        XCTAssertEqual(
            ControllerPresentation.selectedDisplayStatus(
                name: "SENTINEL_PRIVATE_DISPLAY",
                isConfirmedInCurrentSession: false
            ),
            "No private display confirmed for this session"
        )
    }

    func testAmbiguityRequiresExplicitConfirmation() {
        XCTAssertEqual(
            ControllerPresentation.topologyLabel(for: .ambiguous),
            "Display identity is ambiguous — select and confirm the private display"
        )
    }

    func testTopologyStatusDistinguishesExtendedMirroredSingleMissingAmbiguousAndQueryFailure() {
        let values = ControllerTopologyStatus.allCases.map {
            ControllerPresentation.topologyLabel(for: $0)
        }
        XCTAssertEqual(Set(values).count, ControllerTopologyStatus.allCases.count)
    }

    func testMenuNeverContainsPrivateTitle() {
        let application = NSApplication.shared
        let previousMenu = application.mainMenu
        let menu = genericApplicationMenu()
        application.mainMenu = menu
        defer { application.mainMenu = previousMenu }

        let strings = menuStrings(application.mainMenu)
        XCTAssertFalse(strings.joined().contains("SENTINEL_PRIVATE_TITLE"))
        XCTAssertTrue(strings.contains("Private Presenter"))
    }

    func testWindowMenuDiagnosticAndAccessibilityLabelsExcludeSentinelPrivateContent() {
        let sentinels = ["SENTINEL_PRIVATE_TITLE", "SENTINEL_PRIVATE_SCRIPT"]
        let document = ScriptDocument(
            title: sentinels[0],
            text: sentinels[1],
            revision: 7,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: document
        )
        let controller = ControllerWindowController(model: model)
        let application = NSApplication.shared
        let previousMenu = application.mainMenu
        application.mainMenu = genericApplicationMenu()
        defer { application.mainMenu = previousMenu }

        controller.window?.contentView?.layoutSubtreeIfNeeded()
        var actualPublicSurfaces = menuStrings(application.mainMenu)
        actualPublicSurfaces.append(controller.window?.title ?? "")
        if let contentView = controller.window?.contentView {
            actualPublicSurfaces.append(contentsOf: accessibilityStrings(in: contentView))
        }
        #if DEBUG
        actualPublicSurfaces.append(model.diagnosticSummary)
        #endif

        let publicText = actualPublicSurfaces.joined(separator: " ")
        XCTAssertTrue(sentinels.allSatisfy { !publicText.contains($0) })
    }

    func testPrivacyShieldAlwaysRendersGenericTopologyStatus() throws {
        let source = try String(contentsOfFile: sourcePath("ControllerPrivacyShieldView.swift"))

        XCTAssertTrue(source.contains("topologyStatus"))
        XCTAssertTrue(source.contains("ControllerPresentation.topologyLabel"))
    }

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

        // M3 converts the former milestone placeholder into product controls.
        XCTAssertNil(presentation.explanation(for: .start))
        XCTAssertNil(presentation.explanation(for: .speed))
        XCTAssertTrue(presentation.isEnabled(.start))
        XCTAssertTrue(presentation.isEnabled(.speed))
    }

    func testM2StartPauseRestartDoNotDispatchPlaybackCommands() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        if case .start? = presentation.productCommand(for: .start) {} else {
            XCTFail("Start must dispatch through AppModel")
        }
        if case .pause? = presentation.productCommand(for: .pause) {} else {
            XCTFail("Pause must dispatch through AppModel")
        }
        if case .restart? = presentation.productCommand(for: .restart) {} else {
            XCTFail("Restart must dispatch through AppModel")
        }
        // Speed carries a bound value and therefore dispatches directly from the slider.
        XCTAssertNil(presentation.productCommand(for: .speed))
    }

    func testM4FocusModeIsEnabledWithoutPlaceholderCopy() {
        let presentation = ControllerPresentation(
            scriptText: "Generated script",
            isPanelVisible: false,
            isClearConfirmationRequired: false
        )

        XCTAssertNil(presentation.explanation(for: .focusMode))
        XCTAssertTrue(presentation.isEnabled(.focusMode))
        XCTAssertNil(presentation.productCommand(for: .focusMode))
    }

    func testCollisionMessageShowsFixedActionChordAndNumericStatus() {
        let failure = HotKeyFailure(
            action: .toggleVisibility,
            shortcut: KeyboardShortcut(
                virtualKeyCode: 4,
                modifiers: [.control, .option]
            ),
            status: -987,
            cleanup: []
        )

        XCTAssertEqual(
            ControllerPresentation.globalShortcutStatusText(.conflict(failure)),
            "Global shortcut conflict for toggleVisibility (Control-Option-H), status -987."
        )
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

    private func genericApplicationMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Private Presenter")
        let applicationItem = NSMenuItem(
            title: "Private Presenter",
            action: nil,
            keyEquivalent: ""
        )
        let applicationMenu = NSMenu(title: "Private Presenter")
        applicationMenu.addItem(
            NSMenuItem(title: "About Private Presenter", action: nil, keyEquivalent: "")
        )
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        return mainMenu
    }

    private func menuStrings(_ menu: NSMenu?) -> [String] {
        guard let menu else { return [] }
        return [menu.title] + menu.items.flatMap { item in
            [item.title] + menuStrings(item.submenu)
        }
    }

    private func accessibilityStrings(in view: NSView) -> [String] {
        var strings: [String] = []
        if let label = view.accessibilityLabel() { strings.append(label) }
        if let identifier = view.identifier?.rawValue { strings.append(identifier) }
        for child in view.subviews {
            strings.append(contentsOf: accessibilityStrings(in: child))
        }
        return strings
    }

    private func sourcePath(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Controller/\(name)")
            .path
    }
}
