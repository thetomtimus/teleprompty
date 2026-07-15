import XCTest
@testable import TeleprompterCore

final class FocusChromeStateMachineTests: XCTestCase {
    func testEveryFocusTransition() {
        var machine = FocusChromeStateMachine()
        XCTAssertEqual(machine.state, .unlocked)

        _ = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: false, pointerPresent: false)
        XCTAssertEqual(machine.state, .lockedChromeVisible)
        _ = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: true)
        XCTAssertEqual(machine.state, .lockedFocusChromeVisible)
        let effects = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false)
        let token = try! XCTUnwrap(effects.scheduledToken)
        _ = machine.deadlineFired(token)
        XCTAssertEqual(machine.state, .lockedFocusChromeHidden)
        _ = machine.update(isVisible: true, isLocked: false, isFocusModeEnabled: true, pointerPresent: false)
        XCTAssertEqual(machine.state, .unlocked)
    }

    func testLockedFocusHidesAfterTwoSeconds() {
        var machine = FocusChromeStateMachine()
        let effects = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false)
        let token = try! XCTUnwrap(effects.scheduledToken)

        XCTAssertTrue(effects.contains(.scheduleHide(after: 2, token: token)))
        XCTAssertTrue(machine.deadlineFired(token).contains(.setChromeVisible(false)))
        XCTAssertEqual(machine.state, .lockedFocusChromeHidden)
    }

    func testUnlockedAndFocusOffStatesNeverArmHideDeadline() {
        var machine = FocusChromeStateMachine()
        XCTAssertNil(machine.update(isVisible: true, isLocked: false, isFocusModeEnabled: true, pointerPresent: false).scheduledToken)
        XCTAssertNil(machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: false, pointerPresent: false).scheduledToken)
    }

    func testLockedFocusArmsExactlyTwoSecondDeadline() {
        var machine = FocusChromeStateMachine()
        let effects = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false)

        XCTAssertEqual(effects.scheduleDelays, [2])
    }

    func testStaleHideDeadlineIsIgnored() {
        var machine = FocusChromeStateMachine()
        let first = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false).scheduledToken!
        _ = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: true)
        let second = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false).scheduledToken!

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(machine.deadlineFired(first).isEmpty)
        XCTAssertEqual(machine.state, .lockedFocusChromeVisible)
    }

    func testPointerExitRearmsFullDeadline() {
        var machine = FocusChromeStateMachine()
        let first = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false).scheduledToken!
        _ = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: true)
        let effects = machine.update(isVisible: true, isLocked: true, isFocusModeEnabled: true, pointerPresent: false)

        XCTAssertNotEqual(effects.scheduledToken, first)
        XCTAssertEqual(effects.scheduleDelays, [2])
    }
}

private extension Array where Element == FocusChromeEffect {
    var scheduledToken: FocusDeadlineToken? {
        compactMap { if case .scheduleHide(_, let token) = $0 { token } else { nil } }.last
    }

    var scheduleDelays: [TimeInterval] {
        compactMap { if case .scheduleHide(let delay, _) = $0 { delay } else { nil } }
    }
}
