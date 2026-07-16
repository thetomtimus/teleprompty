import AppKit
import XCTest
@testable import PrivatePresenter
import TeleprompterCore

@MainActor
final class CarbonHotKeyServiceTests: XCTestCase {
    func testRegistersEveryActionOnce() {
        let harness = makeHarness()

        XCTAssertEqual(harness.service.register(defaults()), .committed(defaults()))
        XCTAssertEqual(harness.registrar.registeredActions, ShortcutAction.stableOrder)
        XCTAssertEqual(harness.service.activeActionCount, 7)
    }

    func testReconfigurationUnregistersOldChordTransactionally() {
        let harness = makeRegisteredHarness()
        let oldToken = harness.registrar.latestToken(for: .toggleVisibility)!
        let proposed = changing(.toggleVisibility, keyCode: 5)

        XCTAssertEqual(harness.service.reconfigure(proposed), .committed(proposed))
        XCTAssertLessThan(
            harness.registrar.operations.firstIndex(of: .unregister(oldToken))!,
            harness.registrar.operations.lastIndex(of: .register(.toggleVisibility))!
        )
    }

    func testPartialRegistrationRollsBack() {
        let harness = makeHarness()
        harness.registrar.registrationFailures[.decreaseSpeed] = [-987]

        let result = harness.service.register(defaults())

        XCTAssertConflict(result, action: .decreaseSpeed, status: -987)
        XCTAssertEqual(harness.service.state, .unregistered)
        XCTAssertEqual(harness.service.activeActionCount, 0)
        XCTAssertFalse(harness.service.handlerInstalled)
    }

    func testCollisionSurfacesWithoutFallback() {
        let harness = makeHarness()
        harness.registrar.registrationFailures[.toggleVisibility] = [-987]

        let result = harness.service.register(defaults())

        XCTAssertConflict(result, action: .toggleVisibility, status: -987)
        XCTAssertEqual(harness.registrar.installCount, 1)
        XCTAssertEqual(harness.registrar.registeredActions.count, 6)
        XCTAssertEqual(harness.service.activeActionCount, 0)
    }

    func testShutdownUnregistersAll() {
        let harness = makeRegisteredHarness()

        let report = harness.service.shutdown()

        XCTAssertTrue(report.succeeded)
        XCTAssertEqual(report.referenceStatuses.count, 7)
        XCTAssertEqual(harness.service.state, .unregistered)
    }

    func testHandlerDispatchesExpectedCommand() async {
        let harness = makeRegisteredHarness()

        XCTAssertEqual(
            harness.service.receiveForTesting(
                identifier: .init(signature: ProductHotKeyIdentifier.signature, id: 6)
            ),
            noErr
        )
        await Task.yield()
        XCTAssertEqual(harness.commands, [.toggleVisibility])
    }

    func testInitialFailureLeavesNoActiveHotKeysOrHandler() {
        let harness = makeHarness()
        harness.registrar.registrationFailures[.increaseSpeed] = [-1]

        _ = harness.service.register(defaults())

        XCTAssertEqual(harness.service.activeActionCount, 0)
        XCTAssertFalse(harness.service.handlerInstalled)
        XCTAssertEqual(harness.registrar.liveTokens.count, 0)
    }

    func testStableCarbonIDsMapAllSevenActionsExactlyOnce() {
        XCTAssertEqual(
            ShortcutAction.stableOrder.map(ProductHotKeyIdentifier.init(action:)),
            (1...7).map {
                ProductHotKeyIdentifier(signature: ProductHotKeyIdentifier.signature, id: UInt32($0))
            }
        )
    }

    func testUnknownSignatureOrIdentifierIsNotHandled() {
        let harness = makeRegisteredHarness()

        XCTAssertEqual(
            harness.service.receiveForTesting(identifier: .init(signature: 0, id: 1)),
            eventNotHandledErr
        )
        XCTAssertEqual(
            harness.service.receiveForTesting(
                identifier: .init(signature: ProductHotKeyIdentifier.signature, id: 99)
            ),
            eventNotHandledErr
        )
        XCTAssertTrue(harness.commands.isEmpty)
    }

    func testReconfigurationKeepsUnchangedReferencesRegistered() {
        let harness = makeRegisteredHarness()
        let unchanged = Dictionary(uniqueKeysWithValues: ShortcutAction.stableOrder.map {
            ($0, harness.registrar.latestToken(for: $0)!)
        })

        _ = harness.service.reconfigure(changing(.toggleLock, keyCode: 38))

        for action in ShortcutAction.stableOrder where action != .toggleLock {
            XCTAssertFalse(harness.registrar.operations.contains(.unregister(unchanged[action]!)))
        }
    }

    func testChangedOldReferencesUnregisterBeforeProposedRegistration() {
        let harness = makeRegisteredHarness()
        let old = harness.registrar.latestToken(for: .toggleLock)!

        _ = harness.service.reconfigure(changing(.toggleLock, keyCode: 38))

        XCTAssertLessThan(
            harness.registrar.operations.firstIndex(of: .unregister(old))!,
            harness.registrar.operations.lastIndex(of: .register(.toggleLock))!
        )
    }

    func testOldUnregistrationFailureDoesNotStageProposalAndReportsUnknownState() {
        let harness = makeRegisteredHarness()
        let old = harness.registrar.latestToken(for: .toggleLock)!
        harness.registrar.unregistrationFailures[old] = -55
        let registrationCount = harness.registrar.registeredActions.count

        let result = harness.service.reconfigure(changing(.toggleLock, keyCode: 38))

        XCTAssertCleanupUnknown(result)
        XCTAssertEqual(harness.registrar.registeredActions.count, registrationCount)
        XCTAssertEqual(harness.service.state.failureKind, .cleanupUnknown)
    }

    func testStagedCallbacksDoNotDispatchBeforeCommit() {
        let harness = makeHarness()
        harness.registrar.onRegister = { identifier in
            _ = harness.service.receiveForTesting(identifier: identifier)
        }

        _ = harness.service.register(defaults())

        XCTAssertTrue(harness.commands.isEmpty)
    }

    func testFailedProposalRestoresCompleteOldMap() {
        let harness = makeRegisteredHarness()
        harness.registrar.registrationFailures[.toggleLock] = [-987]

        let result = harness.service.reconfigure(changing(.toggleLock, keyCode: 38))

        XCTAssertConflict(result, action: .toggleLock, status: -987)
        XCTAssertEqual(harness.service.registeredBindings, defaults())
        XCTAssertEqual(harness.service.activeActionCount, 7)
    }

    func testRollbackFailureTearsDownAllRegistrationsAndReportsNoActiveHotKeys() {
        let harness = makeRegisteredHarness()
        harness.registrar.registrationFailures[.toggleLock] = [-987, -988]
        let proposed = changing(.toggleLock, keyCode: 38)

        let result = harness.service.reconfigure(proposed)

        guard case .degradedClean(let failure) = result else {
            return XCTFail("Expected degradedClean, got \(result)")
        }
        XCTAssertEqual(
            failure.attempts,
            [
                HotKeyAttemptStatus(
                    operation: .proposedRegistration,
                    action: .toggleLock,
                    shortcut: proposed.first { $0.action == .toggleLock }!.shortcut,
                    status: -987
                ),
                HotKeyAttemptStatus(
                    operation: .rollbackRegistration,
                    action: .toggleLock,
                    shortcut: defaults().first { $0.action == .toggleLock }!.shortcut,
                    status: -988
                ),
            ]
        )
        XCTAssertEqual(failure.cleanup.last?.operation, .removeHandler)
        XCTAssertEqual(harness.service.state.failureKind, .degradedClean)
        XCTAssertEqual(harness.service.activeActionCount, 0)
        XCTAssertEqual(harness.registrar.liveTokens.count, 0)
    }

    func testCleanupFailureNeverClaimsZeroActiveRegistrations() {
        let harness = makeHarness()
        harness.registrar.registrationFailures[.decreaseSpeed] = [-1]
        harness.registrar.failNextUnregistration = -2

        let result = harness.service.register(defaults())

        XCTAssertCleanupUnknown(result)
        XCTAssertNotEqual(harness.service.state, .unregistered)
        XCTAssertFalse(harness.service.claimsNoActiveHotKeys)
    }

    func testUnknownCleanupDisablesRetryUntilRelaunch() {
        let harness = makeHarness()
        harness.registrar.registrationFailures[.decreaseSpeed] = [-1]
        harness.registrar.failNextUnregistration = -2
        _ = harness.service.register(defaults())
        let installCount = harness.registrar.installCount

        let result = harness.service.retry()

        XCTAssertCleanupUnknown(result)
        XCTAssertFalse(harness.service.retryAllowed)
        XCTAssertEqual(harness.registrar.installCount, installCount)
    }

    func testCleanupUnknownMessageIsFixedAndContentNeutral() {
        XCTAssertEqual(
            CarbonHotKeyService.cleanupUnknownMessage,
            "Global shortcuts could not be cleaned up safely. Quit and reopen Private Presenter before retrying."
        )
        XCTAssertFalse(CarbonHotKeyService.cleanupUnknownMessage.contains("Synthetic private title"))
    }

    func testProposedBindingsPersistOnlyAfterRegistrationCommit() {
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effects.append($0) }
        )
        let proposed = changing(.toggleLock, keyCode: 38)
        let initialRevision = model.snapshotRevision

        model.send(.requestHotKeyReconfiguration(proposed))
        XCTAssertEqual(model.shortcutBindings, defaults())
        XCTAssertEqual(model.snapshotRevision, initialRevision)
        model.send(.hotKeyReconfigurationCompleted(.committed(proposed)))

        XCTAssertEqual(model.shortcutBindings, proposed)
        XCTAssertEqual(model.snapshotRevision, initialRevision + 1)
        XCTAssertTrue(effects.contains { if case .scheduleSnapshot = $0 { true } else { false } })
    }

    func testFailedProposalKeepsPersistedOldBindings() {
        let model = AppModel(overlayController: OverlayPanelController())
        let failure = HotKeyFailure(
            action: .toggleLock,
            shortcut: KeyboardShortcut(virtualKeyCode: 38, modifiers: [.control, .option]),
            status: -987,
            cleanup: []
        )

        model.send(.hotKeyReconfigurationCompleted(.conflict(failure)))

        XCTAssertEqual(model.shortcutBindings, defaults())
    }

    func testRetryFromDegradedStateRegistersCleanSevenActionSet() {
        let harness = makeRegisteredHarness()
        harness.registrar.registrationFailures[.toggleLock] = [-987, -988]
        _ = harness.service.reconfigure(changing(.toggleLock, keyCode: 38))

        XCTAssertEqual(harness.service.retry(), .committed(defaults()))
        XCTAssertEqual(harness.service.activeActionCount, 7)
    }

    func testDispatchRunsOnMainActorWithoutActivatingApplication() async {
        let harness = makeRegisteredHarness()
        _ = harness.service.receiveForTesting(identifier: .init(action: .togglePlayback))
        await Task.yield()

        XCTAssertEqual(harness.commands, [.togglePlayback])
        XCTAssertFalse(harness.registrar.operations.contains(.activateApplication))
    }

    func testHotKeyCommandsCannotBypassEmptyScriptOrPrivacyGuards() {
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effects.append($0) }
        )

        model.send(.performShortcut(.togglePlayback))
        XCTAssertTrue(model.isPaused)
        model.send(.replaceScript(text: "Synthetic script"))
        model.send(.performShortcut(.togglePlayback))

        XCTAssertTrue(model.isPaused)
        XCTAssertFalse(effects.contains { if case .startScrollSession = $0 { true } else { false } })
    }

    func testProductAndDiagnosticRegistrarsNeverRunTogether() {
        XCTAssertNil(HotKeyStartupMode.resolve(productEnabled: true, legacyProofEnabled: true))
        XCTAssertEqual(
            HotKeyStartupMode.resolve(productEnabled: true, legacyProofEnabled: false),
            .product
        )
        XCTAssertEqual(
            HotKeyStartupMode.resolve(productEnabled: false, legacyProofEnabled: true),
            .legacyDiagnostic
        )
    }

    func testShutdownRemovesHandlerAfterReferencesAndIsIdempotent() {
        let harness = makeRegisteredHarness()

        let first = harness.service.shutdown()
        let operationCount = harness.registrar.operations.count
        let second = harness.service.shutdown()

        XCTAssertEqual(first, second)
        XCTAssertEqual(harness.registrar.operations.count, operationCount)
        XCTAssertEqual(harness.registrar.operations.last, .removeHandler)
    }

    func testShutdownClosesAlreadyQueuedDispatch() async {
        let harness = makeRegisteredHarness()
        _ = harness.service.receiveForTesting(identifier: .init(action: .togglePlayback))

        _ = harness.service.shutdown()
        await Task.yield()

        XCTAssertTrue(harness.commands.isEmpty)
    }

    func testShutdownReportsUnregistrationAndHandlerRemovalFailures() {
        let harness = makeRegisteredHarness()
        harness.registrar.failNextUnregistration = -44
        harness.registrar.removeStatus = -45

        let report = harness.service.shutdown()

        XCTAssertFalse(report.succeeded)
        XCTAssertTrue(report.referenceStatuses.contains(-44))
        XCTAssertEqual(report.handlerStatus, -45)
    }

    private func makeHarness() -> Harness {
        let registrar = FakeHotKeyRegistrar()
        let harness = Harness(registrar: registrar)
        harness.service = CarbonHotKeyService(registrar: registrar) {
            harness.commands.append($0)
        }
        return harness
    }

    private func makeRegisteredHarness() -> Harness {
        let harness = makeHarness()
        XCTAssertEqual(harness.service.register(defaults()), .committed(defaults()))
        return harness
    }

    private func defaults() -> [ShortcutBinding] { ShortcutValidator.defaultBindings }

    private func changing(_ action: ShortcutAction, keyCode: UInt16) -> [ShortcutBinding] {
        var bindings = defaults()
        let index = bindings.firstIndex { $0.action == action }!
        bindings[index] = ShortcutBinding(
            action: action,
            shortcut: KeyboardShortcut(
                virtualKeyCode: keyCode,
                modifiers: [.control, .option]
            )
        )
        return bindings
    }

    private func XCTAssertConflict(
        _ result: HotKeyTransactionResult,
        action: ShortcutAction,
        status: Int32,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .conflict(let failure) = result else {
            return XCTFail("Expected conflict, got \(result)", file: file, line: line)
        }
        XCTAssertEqual(failure.action, action, file: file, line: line)
        XCTAssertEqual(failure.status, status, file: file, line: line)
    }

    private func XCTAssertCleanupUnknown(
        _ result: HotKeyTransactionResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .cleanupUnknown = result else {
            return XCTFail("Expected cleanupUnknown, got \(result)", file: file, line: line)
        }
    }

    private func XCTAssertDegradedClean(
        _ result: HotKeyTransactionResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .degradedClean = result else {
            return XCTFail("Expected degradedClean, got \(result)", file: file, line: line)
        }
    }
}

@MainActor
private final class Harness {
    let registrar: FakeHotKeyRegistrar
    var commands: [ShortcutAction] = []
    var service: CarbonHotKeyService!

    init(registrar: FakeHotKeyRegistrar) {
        self.registrar = registrar
    }
}

@MainActor
private final class FakeHotKeyRegistrar: HotKeyRegistering {
    enum Operation: Equatable {
        case installHandler
        case register(ShortcutAction)
        case unregister(HotKeyToken)
        case removeHandler
        case activateApplication
    }

    var operations: [Operation] = []
    var registeredActions: [ShortcutAction] = []
    var liveTokens: Set<HotKeyToken> = []
    var registrationFailures: [ShortcutAction: [Int32]] = [:]
    var unregistrationFailures: [HotKeyToken: Int32] = [:]
    var failNextUnregistration: Int32?
    var removeStatus: Int32 = noErr
    var onRegister: ((ProductHotKeyIdentifier) -> Void)?
    private var nextToken: UInt64 = 1
    private var tokensByAction: [ShortcutAction: [HotKeyToken]] = [:]
    private(set) var installCount = 0

    func installHandler(
        callback: @escaping @MainActor (ProductHotKeyIdentifier) -> Int32
    ) -> HotKeyCallResult<HotKeyHandlerToken> {
        operations.append(.installHandler)
        installCount += 1
        return .success(HotKeyHandlerToken(rawValue: 1))
    }

    func register(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        identifier: ProductHotKeyIdentifier
    ) -> HotKeyCallResult<HotKeyToken> {
        let action = identifier.action!
        operations.append(.register(action))
        registeredActions.append(action)
        onRegister?(identifier)
        if var statuses = registrationFailures[action], !statuses.isEmpty {
            let status = statuses.removeFirst()
            registrationFailures[action] = statuses
            return .failure(status)
        }
        let token = HotKeyToken(rawValue: nextToken)
        nextToken += 1
        liveTokens.insert(token)
        tokensByAction[action, default: []].append(token)
        return .success(token)
    }

    func unregister(_ token: HotKeyToken) -> Int32 {
        operations.append(.unregister(token))
        if let status = unregistrationFailures[token] { return status }
        if let status = failNextUnregistration {
            failNextUnregistration = nil
            return status
        }
        liveTokens.remove(token)
        return noErr
    }

    func removeHandler(_ token: HotKeyHandlerToken) -> Int32 {
        operations.append(.removeHandler)
        return removeStatus
    }

    func latestToken(for action: ShortcutAction) -> HotKeyToken? {
        tokensByAction[action]?.last
    }
}
