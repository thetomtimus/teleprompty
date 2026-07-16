import AppKit
import XCTest

final class MenuLifecycleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["PRIVATE_PRESENTER_UI_TEST"] = "1"
        app.launch()
    }

    func testSingleModelIsSharedByBothWindowsAndStatusItem() {
        XCTAssertEqual(app.windows.matching(identifier: "privatePresenter.controller").count, 1)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        XCTAssertEqual(app.windows.matching(identifier: "privatePresenter.overlay").count, 1)
    }

    func testMenuContainsFiveRequiredActions() {
        openStatusMenu()
        XCTAssertEqual(requiredMenuItems.filter { menuItem($0).exists }.count, 5)
    }

    func testClosingControllerDoesNotQuit() {
        app.windows["Private Presenter"].buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(statusItem.waitForExistence(timeout: 2))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testShowControllerReusesInstance() {
        let controller = app.windows["Private Presenter"]
        controller.buttons[XCUIIdentifierCloseWindow].click()
        openStatusMenu()
        menuItem("Show Controller").click()
        XCTAssertTrue(controller.waitForExistence(timeout: 2))
        XCTAssertEqual(app.windows.matching(identifier: "privatePresenter.controller").count, 1)
    }

    func testQuitFlushesPausedStateBeforeUnregisterAndTerminate() {
        openStatusMenu()
        menuItem("Quit").click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    private var statusItem: XCUIElement {
        app.menuBars.statusItems["Private Presenter"]
    }

    private var requiredMenuItems: [String] {
        ["Show Controller", "Start", "Show Teleprompter", "Lock", "Quit"]
    }

    private func openStatusMenu() {
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        statusItem.click()
    }

    private func menuItem(_ title: String) -> XCUIElement {
        app.menuItems[title]
    }
}
