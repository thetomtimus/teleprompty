import XCTest

@MainActor
final class ControllerAccessibilityUITests: XCTestCase {
    private var support: M5UITestSupport?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAllIconButtonsHaveLabelsAndHelp() throws {
        let app = try launchConfirmedApplicationWithScript()
        defer { cleanUp(app) }
        element("privatePresenter.openClose", in: app).click()

        let expectedActionIdentifiers = [
            "privatePresenter.openClose",
            "privatePresenter.hideShow",
            "privatePresenter.lock",
            "privatePresenter.clear",
            "privatePresenter.start",
            "privatePresenter.pause",
            "privatePresenter.restart",
            "privatePresenter.back",
            "privatePresenter.forward",
            "privatePresenter.focusMode",
            "privatePresenter.overlayPlayback",
            "privatePresenter.overlayVisibility",
            "privatePresenter.overlayLock",
        ]
        XCTAssertFalse(expectedActionIdentifiers.isEmpty)

        for identifier in expectedActionIdentifiers {
            let action = element(identifier, in: app)
            XCTAssertTrue(action.waitForExistence(timeout: 3), identifier)
            XCTAssertFalse(action.label.isEmpty, identifier)
            XCTAssertTrue(action.isEnabled, identifier)
        }

        let surfaced = Set(
            app.descendants(matching: .any).allElementsBoundByIndex
                .map(\.identifier)
                .filter { $0.hasPrefix("privatePresenter.") }
        )
        XCTAssertTrue(Set(expectedActionIdentifiers).isSubset(of: surfaced))

        // XCUIElementAttributes does not expose macOS AXHelp. The paired
        // PresenterAccessibilityTests contract asserts nonempty help and
        // tooltips for these exact identifiers; this physical-host test proves
        // the real AppKit bridge exposes the non-vacuous labeled action set.
    }

    func testWarningExposesTextNotColorOnly() throws {
        let app = try launchShieldedApplication()
        defer { cleanUp(app) }
        let status = element("privatePresenter.displaySafetyStatus", in: app)
        let icon = element("privatePresenter.displaySafetyIcon", in: app)

        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertFalse(status.label.isEmpty)
        XCTAssertTrue(status.label.hasPrefix("Display safety:"))
        XCTAssertTrue(icon.waitForExistence(timeout: 3))
        XCTAssertFalse(icon.label.isEmpty)
        XCTAssertTrue([.image, .staticText].contains(icon.elementType))
        XCTAssertFalse(status.label.contains("SENTINEL_PRIVATE_"))
    }

    func testControllerKeyboardTraversal() throws {
        let app = try launchConfirmedApplicationWithScript()
        defer { cleanUp(app) }
        var expected = [
            "privatePresenter.scriptTitle",
            "privatePresenter.scriptEditor",
            "privatePresenter.openClose",
            "privatePresenter.hideShow",
            "privatePresenter.lock",
            "privatePresenter.clear",
            "privatePresenter.fontSize",
            "privatePresenter.alignment",
            "privatePresenter.activeBand",
            "privatePresenter.start",
            "privatePresenter.pause",
            "privatePresenter.restart",
            "privatePresenter.back",
            "privatePresenter.forward",
            "privatePresenter.speed",
            "privatePresenter.focusMode",
        ]
        let retry = element("privatePresenter.retryShortcuts", in: app)
        if retry.exists {
            expected.append("privatePresenter.retryShortcuts")
        }
        XCTAssertFalse(expected.isEmpty)

        let first = element(expected[0], in: app)
        first.click()
        assertHasKeyboardFocus(expected[0], in: app)
        for identifier in expected.dropFirst() {
            app.typeKey(.tab, modifierFlags: [])
            assertHasKeyboardFocus(identifier, in: app)
        }

        for identifier in expected.dropLast().reversed() {
            app.typeKey(.tab, modifierFlags: [.shift])
            assertHasKeyboardFocus(identifier, in: app)
        }

        let band = element("privatePresenter.activeBand", in: app)
        band.click()
        let priorBandValue = String(describing: band.value)
        app.typeKey(.space, modifierFlags: [])
        XCTAssertNotEqual(String(describing: band.value), priorBandValue)

        let clear = element("privatePresenter.clear", in: app)
        clear.click()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2))
        XCTAssertFalse(
            String(describing: element("privatePresenter.scriptEditor", in: app).value)
                .isEmpty
        )
    }

    func testFontRangeControlsAreReachable() throws {
        let app = try launchConfirmedApplicationWithScript()
        defer { cleanUp(app) }
        let fontSize = element("privatePresenter.fontSize", in: app)
        XCTAssertTrue(fontSize.waitForExistence(timeout: 5))
        fontSize.click()
        assertHasKeyboardFocus("privatePresenter.fontSize", in: app)

        for _ in 0..<40 {
            app.typeKey(.leftArrow, modifierFlags: [])
        }
        XCTAssertEqual(fontSize.value as? String, "24 points")

        for _ in 0..<40 {
            app.typeKey(.rightArrow, modifierFlags: [])
        }
        XCTAssertEqual(fontSize.value as? String, "96 points")

        for _ in 0..<36 {
            app.typeKey(.leftArrow, modifierFlags: [])
        }
        XCTAssertEqual(fontSize.value as? String, "24 points")

        let speed = element("privatePresenter.speed", in: app)
        speed.click()
        assertHasKeyboardFocus("privatePresenter.speed", in: app)
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue((speed.value as? String)?.contains("points per second") == true)
    }

    private func launchShieldedApplication() throws -> XCUIApplication {
        let support = try requireSupport()
        do {
            return try support.launchShieldedApplication()
        } catch {
            support.cleanUp()
            self.support = nil
            throw error
        }
    }

    private func launchConfirmedApplicationWithScript() throws -> XCUIApplication {
        let support = try requireSupport()
        let app: XCUIApplication
        do {
            app = try support.launchConfirmedApplication()
        } catch {
            support.cleanUp()
            self.support = nil
            throw error
        }
        let editor = element("privatePresenter.scriptEditor", in: app)
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText("Synthetic accessibility script")
        return app
    }

    private func requireSupport() throws -> M5UITestSupport {
        if let support {
            return support
        }
        let created = try M5UITestSupport()
        support = created
        return created
    }

    private func cleanUp(_ app: XCUIApplication) {
        app.terminate()
        support?.cleanUp()
        support = nil
    }

    private func assertHasKeyboardFocus(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let focused = app.descendants(matching: .any)
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "hasKeyboardFocus == true"))
            .firstMatch
        XCTAssertTrue(
            focused.waitForExistence(timeout: 2),
            identifier,
            file: file,
            line: line
        )
    }

    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
