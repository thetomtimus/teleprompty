import Foundation
import XCTest

@testable import TeleprompterCore

final class ScrollEngineTests: XCTestCase {
    func testElapsedTimeNotFrameCountControlsOffset() {
        var oneTick = makeEngine()
        var fiveTicks = makeEngine()

        _ = oneTick.apply(.start(at: 10))
        _ = oneTick.apply(.tick(at: 10.5))

        _ = fiveTicks.apply(.start(at: 10))
        for uptime in [10.1, 10.2, 10.3, 10.4, 10.5] {
            _ = fiveTicks.apply(.tick(at: uptime))
        }

        XCTAssertEqual(oneTick.offset, 30, accuracy: 1e-9)
        XCTAssertEqual(fiveTicks.offset, oneTick.offset, accuracy: 1e-9)
    }

    func testSixtyAndOneTwentyHertzMatch() {
        var sixtyHertz = makeEngine()
        var oneTwentyHertz = makeEngine()

        _ = sixtyHertz.apply(.start(at: 0))
        for frame in 1...30 {
            _ = sixtyHertz.apply(.tick(at: Double(frame) / 60))
        }

        _ = oneTwentyHertz.apply(.start(at: 0))
        for frame in 1...60 {
            _ = oneTwentyHertz.apply(.tick(at: Double(frame) / 120))
        }

        XCTAssertEqual(sixtyHertz.offset, 30, accuracy: 1e-9)
        XCTAssertEqual(oneTwentyHertz.offset, sixtyHertz.offset, accuracy: 1e-9)
    }

    func testPausePreservesExactOffset() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 4))
        _ = engine.apply(.tick(at: 4.25))

        let transition = engine.apply(.pause)

        XCTAssertEqual(engine.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(transition.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(transition.phase, .paused)
        XCTAssertEqual(transition.stopReason, .commandPause)
        XCTAssertTrue(transition.didChangePhase)
        XCTAssertFalse(transition.didChangeOffset)
        XCTAssertNil(engine.lastUptime)
    }

    func testSpeedChangeDoesNotJump() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 7))
        _ = engine.apply(.tick(at: 7.25))

        let transition = engine.apply(.setSpeed(pointsPerSecond: 120, at: 7.25))

        XCTAssertEqual(engine.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(engine.speedPointsPerSecond, 120)
        XCTAssertFalse(transition.didChangeOffset)
        XCTAssertEqual(transition.phase, .playing)

        var rejectedSpeed = makeEngine()
        _ = rejectedSpeed.apply(.start(at: 0))
        let rejected = rejectedSpeed.apply(.setSpeed(pointsPerSecond: 9, at: 0.25))

        XCTAssertEqual(rejected.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(rejectedSpeed.speedPointsPerSecond, 60)
        XCTAssertEqual(rejected.phase, .playing)
        XCTAssertNil(rejected.stopReason)
    }

    func testEndClampsAndPauses() {
        var engine = makeEngine(maximumOffset: 20)
        _ = engine.apply(.start(at: 1))

        let transition = engine.apply(.tick(at: 1.5))

        XCTAssertEqual(engine.offset, 20, accuracy: 1e-9)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertNil(engine.lastUptime)
        XCTAssertEqual(transition.stopReason, .reachedEnd)
        XCTAssertTrue(transition.didChangeOffset)
        XCTAssertTrue(transition.didChangePhase)
    }

    func testRestartReturnsZeroAndPauses() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 2))
        _ = engine.apply(.tick(at: 2.25))

        let transition = engine.apply(.restart)

        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertNil(engine.lastUptime)
        XCTAssertEqual(transition.stopReason, .restart)
        XCTAssertTrue(transition.didChangeOffset)
        XCTAssertTrue(transition.didChangePhase)
    }

    func testForwardBackwardClamp() {
        var engine = makeEngine(maximumOffset: 100)

        let forward = engine.apply(.moveBy(points: 140, at: 1))
        let backward = engine.apply(.moveBy(points: -160, at: 2))

        XCTAssertEqual(forward.offset, 100)
        XCTAssertEqual(backward.offset, 0)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertNil(forward.stopReason)
        XCTAssertNil(backward.stopReason)

        let ignoredNonfinite = engine.apply(.moveBy(points: .nan, at: .infinity))
        XCTAssertEqual(ignoredNonfinite.offset, 0)
        XCTAssertFalse(ignoredNonfinite.didChangeOffset)
        XCTAssertNil(ignoredNonfinite.stopReason)
    }

    func testSuspensionDoesNotJump() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 20))
        _ = engine.apply(.tick(at: 20.25))

        let suspended = engine.apply(.tick(at: 21))
        let inertTick = engine.apply(.tick(at: 30))

        XCTAssertEqual(suspended.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(suspended.phase, .paused)
        XCTAssertEqual(suspended.stopReason, .suspensionGap)
        XCTAssertEqual(inertTick.offset, 15, accuracy: 1e-9)
        XCTAssertNil(inertTick.stopReason)

        var explicit = makeEngine()
        _ = explicit.apply(.start(at: 1))
        let explicitStop = explicit.apply(.suspend(.explicitSuspension))
        let repeatedExplicitStop = explicit.apply(.suspend(.explicitSuspension))

        XCTAssertEqual(explicitStop.phase, .paused)
        XCTAssertEqual(explicitStop.stopReason, .explicitSuspension)
        XCTAssertNil(repeatedExplicitStop.stopReason)

        var unavailableClock = makeEngine()
        _ = unavailableClock.apply(.start(at: 2))
        let unavailableStop = unavailableClock.apply(.suspend(.clockUnavailable))
        let repeatedUnavailableStop = unavailableClock.apply(.suspend(.clockUnavailable))

        XCTAssertEqual(unavailableStop.phase, .paused)
        XCTAssertEqual(unavailableStop.stopReason, .clockUnavailable)
        XCTAssertNil(repeatedUnavailableStop.stopReason)
    }

    func testStartTimestampMakesFirstTickAdvance() {
        var engine = makeEngine()

        let rejectedStart = engine.apply(.start(at: .nan))
        XCTAssertEqual(rejectedStart.phase, .paused)
        XCTAssertFalse(rejectedStart.didChangePhase)
        XCTAssertNil(engine.lastUptime)

        let started = engine.apply(.start(at: 100))
        let ticked = engine.apply(.tick(at: 100.25))

        XCTAssertEqual(started.offset, 0)
        XCTAssertEqual(started.phase, .playing)
        XCTAssertEqual(engine.lastUptime, 100.25)
        XCTAssertEqual(ticked.offset, 15, accuracy: 1e-9)
    }

    func testSpeedChangeSettlesOldSpeedBeforeInstallingNewSpeed() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 50))

        let changed = engine.apply(.setSpeed(pointsPerSecond: 120, at: 50.25))
        let ticked = engine.apply(.tick(at: 50.5))

        XCTAssertEqual(changed.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(engine.speedPointsPerSecond, 120)
        XCTAssertEqual(ticked.offset, 45, accuracy: 1e-9)

        var invalidInputs = makeEngine()
        _ = invalidInputs.apply(.setSpeed(pointsPerSecond: .nan, at: 0))
        _ = invalidInputs.apply(.setSpeed(pointsPerSecond: .infinity, at: 0))
        _ = invalidInputs.apply(.setSpeed(pointsPerSecond: 9, at: 0))
        _ = invalidInputs.apply(.setSpeed(pointsPerSecond: 241, at: 0))

        XCTAssertEqual(invalidInputs.speedPointsPerSecond, 60)
        XCTAssertEqual(invalidInputs.phase, .paused)
        XCTAssertNil(invalidInputs.lastUptime)
    }

    func testInvalidTimestampPausesOnceWithoutMovement() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 5))

        let invalid = engine.apply(.tick(at: 4.9))
        let repeated = engine.apply(.tick(at: .nan))

        XCTAssertEqual(invalid.offset, 0)
        XCTAssertEqual(invalid.phase, .paused)
        XCTAssertEqual(invalid.stopReason, .invalidTimestamp)
        XCTAssertNil(repeated.stopReason)
        XCTAssertNil(engine.lastUptime)

        var nonfiniteTick = makeEngine()
        _ = nonfiniteTick.apply(.start(at: 10))
        let nonfinite = nonfiniteTick.apply(.tick(at: .infinity))

        XCTAssertEqual(nonfinite.offset, 0)
        XCTAssertEqual(nonfinite.phase, .paused)
        XCTAssertEqual(nonfinite.stopReason, .invalidTimestamp)
        XCTAssertNil(nonfiniteTick.lastUptime)

        var invalidSpeedTiming = makeEngine()
        _ = invalidSpeedTiming.apply(.start(at: 20))
        _ = invalidSpeedTiming.apply(.tick(at: 20.25))
        let rejectedSpeed = invalidSpeedTiming.apply(
            .setSpeed(pointsPerSecond: 120, at: .nan)
        )

        XCTAssertEqual(rejectedSpeed.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(invalidSpeedTiming.speedPointsPerSecond, 60)
        XCTAssertEqual(rejectedSpeed.phase, .paused)
        XCTAssertEqual(rejectedSpeed.stopReason, .invalidTimestamp)
        XCTAssertFalse(rejectedSpeed.didChangeOffset)

        var invalidMoveTiming = makeEngine()
        _ = invalidMoveTiming.apply(.start(at: 30))
        _ = invalidMoveTiming.apply(.tick(at: 30.25))
        let rejectedMove = invalidMoveTiming.apply(.moveBy(points: 10, at: 30.750_000_001))

        XCTAssertEqual(rejectedMove.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(rejectedMove.phase, .paused)
        XCTAssertEqual(rejectedMove.stopReason, .suspensionGap)
        XCTAssertFalse(rejectedMove.didChangeOffset)
    }

    func testSuspensionGapPausesOnceWithoutCatchUp() {
        var engine = makeEngine()
        _ = engine.apply(.start(at: 0))
        _ = engine.apply(.tick(at: 0.25))

        let gap = engine.apply(.tick(at: 0.750_000_001))
        let repeated = engine.apply(.tick(at: 1))

        XCTAssertEqual(gap.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(gap.stopReason, .suspensionGap)
        XCTAssertEqual(repeated.offset, 15, accuracy: 1e-9)
        XCTAssertNil(repeated.stopReason)
    }

    func testUptimeClockDomainIsUsedConsistently() {
        var nearZero = makeEngine()
        var shifted = makeEngine()

        _ = nearZero.apply(.start(at: 1))
        _ = nearZero.apply(.tick(at: 1.125))
        _ = nearZero.apply(.setSpeed(pointsPerSecond: 80, at: 1.25))
        _ = nearZero.apply(.moveBy(points: 10, at: 1.375))

        _ = shifted.apply(.start(at: 10_001))
        _ = shifted.apply(.tick(at: 10_001.125))
        _ = shifted.apply(.setSpeed(pointsPerSecond: 80, at: 10_001.25))
        _ = shifted.apply(.moveBy(points: 10, at: 10_001.375))

        XCTAssertEqual(nearZero.offset, 35, accuracy: 1e-9)
        XCTAssertEqual(shifted.offset, nearZero.offset, accuracy: 1e-9)
        XCTAssertEqual(shifted.phase, nearZero.phase)
    }

    func testMaximumOffsetChangeRequiresPause() {
        var engine = makeEngine(maximumOffset: 100)
        _ = engine.apply(.setMaximumOffset(-1))
        _ = engine.apply(.setMaximumOffset(.nan))
        _ = engine.apply(.setMaximumOffset(.infinity))
        XCTAssertEqual(engine.maximumOffset, 100)

        _ = engine.apply(.moveBy(points: 80, at: 0))
        _ = engine.apply(.start(at: 1))

        let rejected = engine.apply(.setMaximumOffset(50))
        XCTAssertEqual(engine.maximumOffset, 100)
        XCTAssertEqual(engine.offset, 80)

        _ = engine.apply(.pause)
        let accepted = engine.apply(.setMaximumOffset(50))

        XCTAssertEqual(rejected.offset, 80)
        XCTAssertEqual(engine.maximumOffset, 50)
        XCTAssertEqual(engine.offset, 50)
        XCTAssertEqual(accepted.offset, 50)
        XCTAssertTrue(accepted.didChangeOffset)
        XCTAssertNil(accepted.stopReason)
    }

    func testManualMoveSettlesElapsedTimeBeforeClamping() {
        var engine = makeEngine(maximumOffset: 100)
        _ = engine.apply(.start(at: 10))

        let transition = engine.apply(.moveBy(points: 10, at: 10.25))

        XCTAssertEqual(transition.offset, 25, accuracy: 1e-9)
        XCTAssertEqual(transition.phase, .playing)
        XCTAssertEqual(engine.lastUptime, 10.25)
        XCTAssertTrue(transition.didChangeOffset)
        XCTAssertNil(transition.stopReason)

        var backwardFromElapsedMaximum = makeEngine(maximumOffset: 20)
        _ = backwardFromElapsedMaximum.apply(.start(at: 0))
        let backward = backwardFromElapsedMaximum.apply(.moveBy(points: -5, at: 0.5))

        XCTAssertEqual(backward.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(backward.phase, .playing)
        XCTAssertEqual(backwardFromElapsedMaximum.lastUptime, 0.5)
        XCTAssertNil(backward.stopReason)

        var finalMaximum = makeEngine(maximumOffset: 20)
        _ = finalMaximum.apply(.start(at: 0))
        let reachedEnd = finalMaximum.apply(.moveBy(points: 10, at: 0.25))

        XCTAssertEqual(reachedEnd.offset, 20, accuracy: 1e-9)
        XCTAssertEqual(reachedEnd.phase, .paused)
        XCTAssertNil(finalMaximum.lastUptime)
        XCTAssertEqual(reachedEnd.stopReason, .reachedEnd)

        var nonfiniteManual = makeEngine(maximumOffset: 100)
        _ = nonfiniteManual.apply(.start(at: 0))
        let settledOnly = nonfiniteManual.apply(.moveBy(points: .nan, at: 0.25))

        XCTAssertEqual(settledOnly.offset, 15, accuracy: 1e-9)
        XCTAssertEqual(settledOnly.phase, .playing)
        XCTAssertEqual(nonfiniteManual.lastUptime, 0.25)
        XCTAssertNil(settledOnly.stopReason)
    }

    func testTerminalStopReasonIsEdgeTriggered() {
        var engine = makeEngine(maximumOffset: 10)
        _ = engine.apply(.start(at: 0))

        let terminal = engine.apply(.tick(at: 0.5))
        let inertTick = engine.apply(.tick(at: 1))
        let inertPause = engine.apply(.pause)
        let inertSuspension = engine.apply(.suspend(.explicitSuspension))

        XCTAssertEqual(terminal.stopReason, .reachedEnd)
        XCTAssertNil(inertTick.stopReason)
        XCTAssertNil(inertPause.stopReason)
        XCTAssertNil(inertSuspension.stopReason)
    }

    private func makeEngine(maximumOffset: Double = 10_000) -> ScrollEngine {
        ScrollEngine(speedPointsPerSecond: 60, maximumOffset: maximumOffset)
    }
}
