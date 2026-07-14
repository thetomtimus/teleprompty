import AppKit
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class AppModelTests: XCTestCase {
    func testShieldPrecedesWarningAndReposition() {
        var observedSafeState = false
        var model: AppModel!
        model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                if case .hidePanel = effect {
                    observedSafeState = model.isPaused
                        && model.overlaySession.visibility == .hidden
                        && model.isShielded
                }
            }
        )
        model.send(.replaceScript(text: "Generated script"))
        model.send(.start)

        model.topologyWillChange()

        XCTAssertTrue(observedSafeState)
        XCTAssertTrue(model.isShielded)
    }

    func testRecoveryNeverResumesAutomatically() {
        let model = AppModel(overlayController: OverlayPanelController())
        model.send(.replaceScript(text: "Generated script"))
        model.send(.start)
        model.topologyWillChange()
        model.refreshDisplays(.success([display(id: 1, builtIn: true, x: 0)]))

        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertFalse(model.isSelectionConfirmed)
    }

    func testAmbiguousWeakDisplayFrameIsNotAutoRestoredOrPersisted() {
        let model = AppModel(overlayController: OverlayPanelController())
        let first = duplicateDisplay(id: 10, x: 0)
        let second = duplicateDisplay(id: 11, x: 1_440)
        model.refreshDisplays(.success([first, second]))
        model.selectDisplay(second.id)
        model.confirmSelectedDisplay()
        model.send(
            .panelFrameChanged(
                displayID: second.id,
                frame: NSRect(x: 1_500, y: 100, width: 700, height: 350)
            ))

        XCTAssertTrue(model.panelFrames.isEmpty)
        XCTAssertNil(model.preferences.selectedDisplayFingerprint)
    }

    func testFrameCallbackPersistsOnlyCurrentConfirmedDisplayFingerprint() {
        let model = AppModel(overlayController: OverlayPanelController())
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let audience = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.send(
            .panelFrameChanged(
                displayID: privateDisplay.id,
                frame: NSRect(x: 100, y: 100, width: 700, height: 350)
            ))
        XCTAssertTrue(model.panelFrames.isEmpty)

        model.confirmSelectedDisplay()
        model.send(
            .panelFrameChanged(
                displayID: audience.id,
                frame: NSRect(x: 1_500, y: 100, width: 700, height: 350)
            ))
        XCTAssertTrue(model.panelFrames.isEmpty)

        model.send(
            .panelFrameChanged(
                displayID: privateDisplay.id,
                frame: NSRect(x: 100, y: 100, width: 700, height: 350)
            ))
        XCTAssertEqual(model.panelFrames.count, 1)
        XCTAssertEqual(
            model.panelFrames.first?.displayFingerprint.persistentIdentityKey,
            model.preferences.selectedDisplayFingerprint?.persistentIdentityKey
        )
    }

    func testSameUUIDHardwareConflictNeverRestoresPersistedFrame() {
        let savedFingerprint = DisplayFingerprint(
            uuid: "shared-uuid",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: true,
            lastLocalizedName: "Saved Private Display",
            confidence: .strong
        )
        let savedFrame = PersistedPanelFrame(
            displayFingerprint: savedFingerprint,
            frame: NormalizedPanelFrame(x: 0.1, y: 0.1, width: 0.5, height: 0.4)
        )
        let persisted = PersistedSnapshot(
            revision: 8,
            document: ScriptDocument(text: "Generated script", revision: 4),
            readingAnchor: ReadingAnchor(),
            preferences: TeleprompterPreferences(),
            panelFrames: [savedFrame]
        )
        let current = RuntimeDisplay(
            id: 1,
            localizedName: "Current Private Display",
            isBuiltIn: true,
            isMain: true,
            isOnline: true,
            frame: NSRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "shared-uuid",
            mirrorSourceID: nil,
            isInMirrorSet: false,
            vendorID: 1,
            modelID: 999,
            serialNumber: 3
        )
        let audience = display(id: 2, builtIn: false, x: 1_440)
        var proposedFrames: [CGRect?] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                if case .stagePanelHidden(_, let proposedFrame) = effect {
                    proposedFrames.append(proposedFrame)
                }
            }
        )
        model.send(.restore(persisted))
        model.refreshDisplays(.success([current, audience]))
        model.selectDisplay(current.id)
        proposedFrames.removeAll()

        model.confirmSelectedDisplay()

        XCTAssertEqual(proposedFrames.count, 1)
        XCTAssertNil(proposedFrames[0])
    }

    func testOneSidedUUIDHardwareMatchRestoresPersistedFrame() {
        let savedFingerprint = DisplayFingerprint(
            uuid: "saved-uuid",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: true,
            lastLocalizedName: "Saved Private Display",
            confidence: .strong
        )
        let current = RuntimeDisplay(
            id: 1,
            localizedName: "Current Private Display",
            isBuiltIn: true,
            isMain: true,
            isOnline: true,
            frame: NSRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: nil,
            mirrorSourceID: nil,
            isInMirrorSet: false,
            vendorID: 1,
            modelID: 2,
            serialNumber: 3
        )
        let savedFrame = PersistedPanelFrame(
            displayFingerprint: savedFingerprint,
            frame: NormalizedPanelFrame(x: 0.1, y: 0.1, width: 0.5, height: 0.4)
        )
        let persisted = PersistedSnapshot(
            revision: 8,
            document: ScriptDocument(text: "Generated script", revision: 4),
            readingAnchor: ReadingAnchor(),
            preferences: TeleprompterPreferences(),
            panelFrames: [savedFrame]
        )
        var proposedFrames: [CGRect?] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                if case .stagePanelHidden(_, let proposedFrame) = effect {
                    proposedFrames.append(proposedFrame)
                }
            }
        )
        model.send(.restore(persisted))
        model.refreshDisplays(.success([current, display(id: 2, builtIn: false, x: 1_440)]))
        model.selectDisplay(current.id)
        proposedFrames.removeAll()

        model.confirmSelectedDisplay()

        XCTAssertEqual(proposedFrames.count, 1)
        XCTAssertNotNil(proposedFrames[0])
    }

    func testDisplayLossPausesHidesShieldsBeforeFallbackPlacement() {
        let model = AppModel(overlayController: OverlayPanelController())
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let audience = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: privateDisplay.id))
        model.showOverlay()

        model.topologyWillChange()
        model.refreshDisplays(.success([audience]))

        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertTrue(model.isShielded)
    }

    func testReconnectRemainsHiddenPausedUntilExplicitConfirmation() {
        let model = AppModel(overlayController: OverlayPanelController())
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let audience = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.confirmSelectedDisplay()
        model.topologyWillChange()
        model.refreshDisplays(.success([audience]))
        model.refreshDisplays(.success([privateDisplay, audience]))

        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
    }

    func testM2PreservesOnePanelAndOneAppModel() {
        let runtime = AppRuntime(proofLevel: .statusBar)

        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
        XCTAssertEqual(runtime.overlayController.configurationSnapshot.panelCount, 1)
        XCTAssertEqual(
            ObjectIdentifier(runtime.model),
            runtime.controllerWindowController.modelIdentity
        )
    }

    func testTitleTrimsDefaultsAndCapsWithoutSplittingCharacter() {
        let model = AppModel(overlayController: OverlayPanelController())
        model.send(.setScriptTitle("   "))
        XCTAssertEqual(model.document.title, "Lecture Teleprompter")

        let longTitle = String(repeating: "a", count: 119) + "👨‍👩‍👧‍👦"
        model.send(.setScriptTitle(longTitle))

        XCTAssertEqual(model.document.title, String(repeating: "a", count: 119))
        XCTAssertFalse(model.document.title.unicodeScalars.contains("\u{FFFD}"))
    }

    func testFontSizeAlignmentAndActiveBandPersistThroughV1Snapshot() {
        var snapshots: [PersistedSnapshot] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                if case .scheduleSnapshot(let snapshot) = effect { snapshots.append(snapshot) }
            }
        )

        model.send(.setFontSize(72))
        model.send(.setTextAlignment(.center))
        model.send(.setActiveBandEnabled(false))

        XCTAssertEqual(snapshots.last?.schemaVersion, 1)
        XCTAssertEqual(snapshots.last?.preferences.fontSizePoints, 72)
        XCTAssertEqual(snapshots.last?.preferences.textAlignment, .center)
        XCTAssertEqual(snapshots.last?.preferences.isActiveBandEnabled, false)
    }

    func testAcceptedEditSchedulesAutosaveAfterAuthoritativeMutation() throws {
        var observedText: String?
        var model: AppModel!
        model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                if case .scheduleSnapshot = effect { observedText = model.document.text }
            }
        )
        let edit = try ScriptTextEdit.replacing(
            in: "",
            range: .init(location: 0, length: 0),
            with: "Generated text",
            baseRevision: 0
        )

        model.send(.applyScriptEdit(edit))

        XCTAssertEqual(observedText, "Generated text")
    }

    func testAutosaveDoesNotBlockMainActorEffectDispatch() throws {
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effects.append($0) }
        )
        let edit = try ScriptTextEdit.replacing(
            in: "",
            range: .init(location: 0, length: 0),
            with: "Generated text",
            baseRevision: 0
        )

        model.send(.applyScriptEdit(edit))

        XCTAssertEqual(effects.count, 2)
        if case .applyReaderEdit = effects[0] {} else { XCTFail("reader dispatch must remain synchronous") }
        if case .scheduleSnapshot = effects[1] {} else { XCTFail("autosave must be queued after reader dispatch") }
    }

    func testAutosaveDiagnosticsExcludeScriptTitleAndReplacementText() {
        let sentinel = "SENTINEL_PRIVATE_CONTENT"
        let diagnostics = [
            AppLocalError.snapshotLoadFailed.rawValue,
            AppLocalError.snapshotSaveFailed.rawValue,
            AppLocalError.preClearFlushFailed.rawValue,
            AppLocalError.clearRequestInvalidated.rawValue,
        ].joined(separator: " ")

        XCTAssertFalse(diagnostics.contains(sentinel))
    }

    func testStaleOrOutOfOrderEditCannotOverwriteAuthority() throws {
        let model = modelWithScript()
        let stale = try ScriptTextEdit.replacing(
            in: "",
            range: UTF16TextRange(location: 0, length: 0),
            with: "stale",
            baseRevision: 0
        )

        model.send(.applyScriptEdit(stale))

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertEqual(model.document.revision, 1)
    }

    func testAcceptedEditMutatesStateBeforeReaderAndSnapshotEffects() throws {
        var model: AppModel!
        var observed: [(AppEffect, String, UInt64)] = []
        model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                observed.append((effect, model.document.text, model.document.revision))
            }
        )
        let edit = try ScriptTextEdit.replacing(
            in: "",
            range: UTF16TextRange(location: 0, length: 0),
            with: "A",
            baseRevision: 0
        )

        model.send(.applyScriptEdit(edit))

        XCTAssertEqual(observed.count, 2)
        if case .applyReaderEdit = observed[0].0 {} else { XCTFail("reader edit must be first") }
        if case .scheduleSnapshot = observed[1].0 {} else { XCTFail("snapshot must follow reader") }
        XCTAssertTrue(observed.allSatisfy { $0.1 == "A" && $0.2 == 1 })
    }

    func testCommandsChangeStateBeforeEffects() {
        var model: AppModel!
        var stateObservedByEffect = false
        model = AppModel(
            overlayController: OverlayPanelController(),
            now: { Date(timeIntervalSince1970: 20) },
            effectHandler: { effect in
                if case .scheduleSnapshot = effect {
                    stateObservedByEffect =
                        model.document.text == "New lecture"
                        && model.document.revision == 1
                        && model.snapshotRevision == 1
                }
            }
        )

        model.send(.replaceScript(text: "New lecture"))

        XCTAssertTrue(stateObservedByEffect)
    }

    func testEmptyScriptCannotStart() {
        let model = AppModel(overlayController: OverlayPanelController())

        model.send(.start)

        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
    }

    func testWhitespaceOnlyScriptCannotStart() {
        let model = AppModel(overlayController: OverlayPanelController())
        model.send(.replaceScript(text: " \n\t "))

        model.send(.start)

        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
    }

    func testRestartPausesAtBeginning() {
        let model = AppModel(overlayController: OverlayPanelController())
        model.send(.replaceScript(text: "Lecture"))
        model.send(.start)
        model.setReadingPositionForTesting(utf16Offset: 4, pixelOffset: 120)

        model.send(.restart)

        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(model.overlaySession.readingAnchor.utf16Offset, 0)
        XCTAssertEqual(model.overlaySession.pixelOffset, 0)
    }

    func testRelaunchReassessesPrivacyBeforeShow() {
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effects.append($0) }
        )
        model.send(.restore(snapshot(text: "Lecture")))

        model.send(.showOverlay)

        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertEqual(effects.first, .reassessPrivacy)
        XCTAssertFalse(effects.contains(where: { if case .showPanel = $0 { true } else { false } }))
    }

    func testAppRuntimeRestoreAndPrivacyOrderingBlocksEarlyShow() async {
        var startupEvents: [AppRuntimeStartupEvent] = []
        let restored = snapshot(text: "Lecture")
        let runtime = AppRuntime(
            proofLevel: .floating,
            startupSeams: AppRuntimeStartupSeams(
                load: {
                    return .loaded(RestoredState(snapshot: restored))
                },
                observeAndQuery: {
                    return .success(RuntimeDisplayInventory(displays: []))
                },
                registerDiagnosticHotKey: {
                    return 0
                },
                record: { startupEvents.append($0) }
            )
        )

        await runtime.startForTesting(afterRestore: { runtime.model.send(.showOverlay) })

        XCTAssertEqual(
            startupEvents,
            [
                .shieldController,
                .load,
                .restore,
                .observeAndQuery,
                .evaluatePrivacy,
                .registerDiagnosticHotKey,
            ]
        )
        XCTAssertEqual(runtime.model.overlaySession.visibility, .hidden)
    }

    func testRestoreClearsCurrentSessionDisplayIdentity() {
        let model = AppModel(overlayController: OverlayPanelController())
        model.setCurrentSessionDisplayIdentityForTesting(42, confirmed: true)

        model.send(.restore(snapshot(text: "Lecture")))

        XCTAssertNil(model.overlaySession.currentSessionDisplayID)
        XCTAssertEqual(model.overlaySession.recoveryConfirmationState, .required)
        XCTAssertFalse(model.isSelectionConfirmed)
    }

    func testRestoreAppliesPersistedLockAfterStateMutation() {
        let controller = OverlayPanelController()
        var model: AppModel!
        var observedLockedState = false
        model = AppModel(
            overlayController: controller,
            effectHandler: { effect in
                guard case .setPanelLocked(true) = effect else { return }
                observedLockedState = model.isLocked && model.preferences.isLocked
                controller.setLocked(true)
            }
        )

        model.send(
            .restore(
                snapshot(
                    text: "Lecture",
                    preferences: TeleprompterPreferences(isLocked: true)
                )))

        XCTAssertTrue(observedLockedState)
        XCTAssertTrue(model.configurationSnapshot.isLocked)
    }

    func testClearRequiresConfirmedCommand() {
        let model = modelWithScript()

        model.send(.requestClear)

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertNotNil(model.pendingClearToken)
        XCTAssertFalse(model.isAwaitingPreClearFlush)
    }

    func testClearWaitsForSuccessfulPreClearFlush() {
        var effects: [AppEffect] = []
        let model = modelWithScript(effectHandler: { effects.append($0) })
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)

        model.send(.confirmClear(token: token))

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertTrue(model.isAwaitingPreClearFlush)
        XCTAssertTrue(
            effects.contains(
                .flushSnapshot(
                    token: token,
                    requiredRevision: model.snapshotRevision
                )))
    }

    func testFailedPreClearFlushPreservesScript() {
        let model = modelWithScript()
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))

        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: model.snapshotRevision,
                succeeded: false
            ))

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertEqual(model.localError, .preClearFlushFailed)
    }

    func testInterveningEditInvalidatesPendingClear() {
        let model = modelWithScript()
        model.send(.requestClear)

        model.send(.replaceScript(text: "Revised lecture"))

        XCTAssertNil(model.pendingClearToken)
        XCTAssertEqual(model.document.text, "Revised lecture")
    }

    func testStaleClearCompletionCannotEraseScript() {
        let model = modelWithScript()
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))
        let capturedRevision = model.snapshotRevision
        model.send(.replaceScript(text: "Revised lecture"))

        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: capturedRevision,
                succeeded: true
            ))

        XCTAssertEqual(model.document.text, "Revised lecture")
    }

    func testLockChangeInvalidatesAwaitingClearAndStaleCompletionPreservesScript() {
        assertDurableChangeInvalidatesAwaitingClear { model in
            model.send(.setLocked(true))
        }
    }

    func testRestartInvalidatesAwaitingClearAndStaleCompletionPreservesScript() {
        assertDurableChangeInvalidatesAwaitingClear { model in
            model.send(.restart)
        }
    }

    func testFingerprintChangeInvalidatesAwaitingClearAndStaleCompletionPreservesScript() {
        let model = modelWithScript()
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([builtIn, projector]))
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))
        let capturedRevision = model.snapshotRevision

        model.send(.confirmSelectedDisplay)
        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: capturedRevision,
                succeeded: true
            ))

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertNil(model.pendingClearToken)
        XCTAssertEqual(model.localError, .clearRequestInvalidated)
    }

    func testPostClearSnapshotPersistsImmediatelyWithoutDebounce() {
        var effects: [AppEffect] = []
        let model = modelWithScript(effectHandler: { effects.append($0) })
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))
        let requiredRevision = model.snapshotRevision

        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: requiredRevision,
                succeeded: true
            ))

        guard case .saveSnapshotImmediately(let saved)? = effects.last else {
            return XCTFail("Expected immediate post-clear save")
        }
        XCTAssertEqual(saved.document.text, "")
    }

    func testConfirmedClearIncrementsRevisionsAndPersistsEmptySnapshot() {
        var effects: [AppEffect] = []
        let model = modelWithScript(effectHandler: { effects.append($0) })
        let originalDocumentRevision = model.document.revision
        let originalSnapshotRevision = model.snapshotRevision
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))

        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: originalSnapshotRevision,
                succeeded: true
            ))

        XCTAssertEqual(model.document.text, "")
        XCTAssertEqual(model.document.revision, originalDocumentRevision + 1)
        XCTAssertEqual(model.snapshotRevision, originalSnapshotRevision + 1)
        XCTAssertEqual(model.overlaySession.readingAnchor.utf16Offset, 0)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        guard case .saveSnapshotImmediately(let saved)? = effects.last else {
            return XCTFail("Expected immediate empty snapshot")
        }
        XCTAssertEqual(saved.revision, originalSnapshotRevision + 1)
        XCTAssertEqual(saved.document.text, "")
    }

    func testRuntimeAndControllerShareOneAuthoritativeModel() {
        let runtime = AppRuntime(proofLevel: .floating)

        XCTAssertEqual(
            runtime.controllerWindowController.modelIdentity,
            ObjectIdentifier(runtime.model)
        )
    }

    func testAppRuntimeConstructsExactlyOneAppModel() {
        let runtime = AppRuntime(proofLevel: .floating)

        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
    }

    func testStabilizationRestoreRemainsHiddenPausedUntilPrivacyConfirmation() {
        let model = AppModel(overlayController: OverlayPanelController())

        model.send(.restore(snapshot(text: "Generated stabilization fixture")))
        model.send(.showOverlay)

        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
    }

    func testStabilizationStartupRestoresBeforeTopologyAndRegistersControlsLast() async {
        var events: [AppRuntimeStartupEvent] = []
        let restored = snapshot(text: "Generated stabilization fixture")
        let runtime = AppRuntime(
            proofLevel: .floating,
            startupSeams: AppRuntimeStartupSeams(
                load: { .loaded(RestoredState(snapshot: restored)) },
                observeAndQuery: { .success(RuntimeDisplayInventory(displays: [])) },
                registerDiagnosticHotKey: { 0 },
                record: { events.append($0) }
            )
        )

        await runtime.startForTesting()

        let restore = try? XCTUnwrap(events.firstIndex(of: .restore))
        let topology = try? XCTUnwrap(events.firstIndex(of: .observeAndQuery))
        let privacy = try? XCTUnwrap(events.firstIndex(of: .evaluatePrivacy))
        let controls = try? XCTUnwrap(events.firstIndex(of: .registerDiagnosticHotKey))
        XCTAssertNotNil(restore)
        XCTAssertNotNil(topology)
        XCTAssertNotNil(privacy)
        XCTAssertNotNil(controls)
        if let restore, let topology, let privacy, let controls {
            XCTAssertLessThan(restore, topology)
            XCTAssertLessThan(topology, privacy)
            XCTAssertLessThan(privacy, controls)
            XCTAssertEqual(controls, events.count - 1)
        }
    }

    func testStabilizationRuntimeStillConstructsExactlyOneAppModel() {
        let runtime = AppRuntime(proofLevel: .floating)

        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
    }

    #if DEBUG
    func testStabilizationServicesShareTheRuntimeModelIdentity() {
        let runtime = AppRuntime(proofLevel: .floating)
        let dispatchesBefore = runtime.model.commandDispatchCount

        runtime.diagnosticHotKeyService.invokeForTesting()

        XCTAssertEqual(
            runtime.controllerWindowController.modelIdentity,
            ObjectIdentifier(runtime.model)
        )
        XCTAssertEqual(runtime.model.commandDispatchCount, dispatchesBefore + 1)
        XCTAssertEqual(runtime.dependencies.appModelConstructionCount, 1)
    }
    #endif

    func testAllLoadFailuresRemainFailClosedAfterTopologyConfirmation() async {
        let failures: [SnapshotLoadResult] = [
            .recoveredMalformed(quarantineURL: URL(fileURLWithPath: "/tmp/generated-fixture.json")),
            .unsupportedFutureSchema(found: 2, supported: 1),
            .recoveryFailed(.readFailed),
        ]
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)

        for failure in failures {
            let runtime = AppRuntime(
                proofLevel: .floating,
                startupSeams: AppRuntimeStartupSeams(
                    load: { failure },
                    observeAndQuery: {
                        .success(RuntimeDisplayInventory(displays: [builtIn, projector]))
                    },
                    registerDiagnosticHotKey: { 0 }
                )
            )

            await runtime.startForTesting()
            runtime.model.send(.confirmSelectedDisplay)
            runtime.model.send(.showOverlay)

            XCTAssertTrue(runtime.model.restorationCompleted)
            XCTAssertFalse(runtime.model.isPersistenceLoadSafe)
            XCTAssertTrue(runtime.model.isShielded)
            XCTAssertFalse(runtime.model.isSelectionConfirmed)
            XCTAssertEqual(runtime.model.overlaySession.visibility, .hidden)
        }
    }

    func testExplicitSuccessfulRestoreReleasesLoadFailureLatchOnlyAfterShieldedMove() {
        let model = AppModel(
            overlayController: OverlayPanelController(),
            restorationRequired: true
        )
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model.send(.restoreFailed)
        model.send(.restore(nil))
        model.refreshDisplays(.success([builtIn, projector]))
        model.send(.confirmSelectedDisplay)

        XCTAssertTrue(model.isPersistenceLoadSafe)
        XCTAssertTrue(model.isShielded)
        model.send(.completeShieldedMove(screenID: builtIn.id))
        model.send(.showOverlay)

        XCTAssertFalse(model.isShielded)
        XCTAssertEqual(model.overlaySession.visibility, .visible)
    }

    func testPrivacyEffectsObserveFullyCommittedShieldedState() {
        var model: AppModel!
        var observedCommittedState = false
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model = AppModel(
            overlayController: OverlayPanelController(),
            effectHandler: { effect in
                guard case .moveControllerWhileShielded = effect else { return }
                observedCommittedState =
                    model.isShielded
                    && model.isSelectionConfirmed
                    && model.overlaySession.currentSessionDisplayID == builtIn.id
                    && model.preferences.selectedDisplayFingerprint != nil
            }
        )
        model.refreshDisplays(.success([builtIn, projector]))
        observedCommittedState = false

        model.send(.confirmSelectedDisplay)

        XCTAssertTrue(observedCommittedState)
        XCTAssertTrue(model.isShielded)
    }

    func testTerminationAwaitsFlushBeforeStoppingServices() async {
        let gate = TerminationFlushGate()
        var events: [AppRuntimeStartupEvent] = []
        let dependencies = DependencyContainer(
            proofLevel: .floating,
            terminationFlushOverride: {
                await gate.wait()
                return true
            }
        )
        let runtime = AppRuntime(
            proofLevel: .floating,
            dependencies: dependencies,
            startupSeams: AppRuntimeStartupSeams(record: { events.append($0) })
        )

        let stopTask = Task { await runtime.stopAndFlush() }
        await gate.waitUntilEntered()

        XCTAssertEqual(events, [.flushPersistence])
        await gate.release()
        let didFlush = await stopTask.value
        XCTAssertTrue(didFlush)
        XCTAssertEqual(events, [.flushPersistence, .stopServices])
    }

    func testTerminationBarrierPersistsSuccessorImmediateSaveBeforeStoppingServices() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-generated-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SnapshotStore(
            rootURL: root,
            sleeper: TerminationNeverSleeper()
        )
        let dependencies = DependencyContainer(
            proofLevel: .floating,
            snapshotStore: store
        )
        var events: [AppRuntimeStartupEvent] = []
        let runtime = AppRuntime(
            proofLevel: .floating,
            dependencies: dependencies,
            startupSeams: AppRuntimeStartupSeams(record: { events.append($0) })
        )
        runtime.model.send(.restore(nil))
        runtime.model.send(.replaceScript(text: "Lecture"))
        runtime.model.send(.requestClear)
        let token = try XCTUnwrap(runtime.model.pendingClearToken)
        runtime.model.send(.confirmClear(token: token))

        let didFlush = await runtime.stopAndFlush()

        XCTAssertTrue(didFlush)
        XCTAssertTrue(runtime.model.isTerminationQuiescing)
        XCTAssertEqual(runtime.model.document.text, "")
        let status = await store.status()
        XCTAssertEqual(status.persistedRevision, 2)
        let data = try Data(contentsOf: store.snapshotURL)
        let persisted = try SnapshotMigrator().migrate(data)
        XCTAssertEqual(persisted.revision, 2)
        XCTAssertEqual(persisted.document.text, "")
        XCTAssertEqual(events, [.flushPersistence, .stopServices])
        runtime.model.send(.replaceScript(text: "late mutation"))
        XCTAssertEqual(runtime.model.document.text, "")
        XCTAssertEqual(runtime.model.snapshotRevision, 2)
    }

    func testControllerStartsShielded() {
        let model = AppModel(overlayController: OverlayPanelController())
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertTrue(model.isPaused)
    }

    func testControllerNeverReopensUnredactedOnExternalScreen() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let projector = display(id: 2, builtIn: false, x: 1_440)

        model.refreshDisplays(.success([projector]))

        XCTAssertNil(model.selectedDisplayID)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testRecoveryRequiresConfirmationAndNeverAutoResumes() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([builtIn, projector]))
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: builtIn.id))
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
        let privateExternal = display(id: 3, builtIn: false, x: -1_440)
        var wasShieldedDuringMove = false
        var movedDisplayID: UInt32?
        var model: AppModel!
        model = AppModel(
            overlayController: controller,
            effectHandler: { effect in
                guard case .moveControllerWhileShielded(let display) = effect else { return }
                wasShieldedDuringMove = model.isShielded
                movedDisplayID = display.id
            }
        )

        model.refreshDisplays(.success([privateExternal]))
        model.selectDisplay(privateExternal.id)
        model.confirmSelectedDisplay()

        XCTAssertTrue(wasShieldedDuringMove)
        XCTAssertEqual(movedDisplayID, privateExternal.id)
        XCTAssertTrue(model.isShielded)
        model.send(.completeShieldedMove(screenID: privateExternal.id))
        XCTAssertFalse(model.isShielded)
        XCTAssertTrue(model.isSelectionConfirmed)
    }

    func testMirroringFailsClosedWithRequiredWarning() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
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

        XCTAssertEqual(model.warning, AppModel.mirroringWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testAnyMirroredPairBlocksNonmirroredSelection() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let mirrorSource = mirroredDisplay(id: 2, name: "Mirror Source", sourceID: nil)
        let mirror = mirroredDisplay(id: 3, name: "Projector", sourceID: 2)

        model.refreshDisplays(.success([privateDisplay, mirrorSource, mirror]))
        model.selectDisplay(privateDisplay.id)
        model.confirmSelectedDisplay()
        model.showOverlay()

        XCTAssertEqual(model.warning, AppModel.mirroringWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testQueryFailureFailsClosed() {
        struct QueryFailure: Error {}
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)

        model.refreshDisplays(.failure(QueryFailure()))

        XCTAssertEqual(model.warning, AppModel.queryFailureWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertNil(model.selectedDisplayID)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testAmbiguousWeakDisplaysRequireExplicitSessionSelection() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let first = duplicateDisplay(id: 10, x: 0)
        let second = duplicateDisplay(id: 11, x: 1_440)

        model.refreshDisplays(.success([first, second]))
        model.selectDisplay(second.id)

        XCTAssertEqual(model.warning, AppModel.ambiguityWarning)
        XCTAssertTrue(model.isShielded)

        model.confirmSelectedDisplay()

        XCTAssertEqual(model.selectedDisplayID, second.id)
        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertTrue(model.isShielded)
        model.send(.completeShieldedMove(screenID: second.id))
        XCTAssertFalse(model.isShielded)
    }

    func testWeakBuiltInRemainsShieldedUntilCurrentSessionConfirmation() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let builtIn = display(id: 1, builtIn: true, x: 0)

        model.refreshDisplays(.success([builtIn]))

        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)

        model.confirmSelectedDisplay()

        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertTrue(model.isShielded)
        model.send(.completeShieldedMove(screenID: builtIn.id))
        XCTAssertFalse(model.isShielded)
        XCTAssertEqual(model.warning, AppModel.noSeparationWarning)
    }

    func testOfflineSelectionCannotBeConfirmedOrShown() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
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
        let model = AppModel(
            overlayController: controller,
            privacyCoordinator: coordinator
        )
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)

        model.refreshDisplays(.success([builtIn, projector]))
        model.confirmSelectedDisplay()

        XCTAssertEqual(
            Array(coordinator.lastDirectives.suffix(2)),
            [.moveWindowsWhileShielded(screenID: builtIn.id), .publishSafeState]
        )
        XCTAssertTrue(model.isSelectionConfirmed)
        XCTAssertTrue(model.isShielded)
        model.send(.completeShieldedMove(screenID: builtIn.id))
        XCTAssertFalse(model.isShielded)
    }

    func testStaleProjectorFrameIsIgnoredWhileControllerRemainsShielded() {
        let overlay = OverlayPanelController()
        let model = AppModel(overlayController: overlay)
        let staleProjectorFrame = NSRect(x: 1_700, y: 100, width: 620, height: 360)
        let controller = ControllerWindowController(
            model: model,
            untrustedInitialFrame: staleProjectorFrame
        )
        let builtIn = display(id: 1, builtIn: true, x: 0)

        XCTAssertEqual(controller.window?.frame, staleProjectorFrame)
        controller.presentShieldedControllerAtStartup(on: builtIn)

        XCTAssertTrue(model.isShielded)
        XCTAssertTrue(
            builtIn.visibleFrame.contains(controller.window?.frame ?? .zero)
        )
    }

    func testMirroringWhileVisibleHidesAndShieldsBeforeRecovery() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([builtIn, projector]))
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: builtIn.id))
        model.showOverlay()
        XCTAssertTrue(controller.teleprompterPanel.isVisible)

        model.topologyWillChange()
        let mirroredSink = mirroredDisplay(id: 2, name: "Projector", sourceID: 1)
        let mirroredSource = RuntimeDisplay(
            id: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            isMain: true,
            isOnline: true,
            frame: builtIn.frame,
            visibleFrame: builtIn.visibleFrame,
            scale: builtIn.scale,
            persistentUUID: builtIn.persistentUUID,
            mirrorSourceID: nil,
            isInMirrorSet: true
        )
        model.refreshDisplays(.success([mirroredSource, mirroredSink]))

        XCTAssertFalse(controller.teleprompterPanel.isVisible)
        XCTAssertTrue(model.isShielded)
        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.warning, AppModel.mirroringWarning)
        XCTAssertFalse(model.isSelectionConfirmed)
    }

    func testSelectedPrivateDisplayDisconnectHidesBeforeRecovery() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let audience = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: privateDisplay.id))
        model.showOverlay()

        model.topologyWillChange()
        model.refreshDisplays(.success([audience]))

        XCTAssertFalse(controller.teleprompterPanel.isVisible)
        XCTAssertTrue(model.isShielded)
        XCTAssertTrue(model.isPaused)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertNil(model.selectedDisplayID)
    }

    func testControllerRemainsShieldedAfterReconnectUntilConfirmation() {
        let controller = OverlayPanelController()
        let model = AppModel(overlayController: controller)
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let audience = display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: privateDisplay.id))
        model.showOverlay()
        model.topologyWillChange()
        model.refreshDisplays(.success([audience]))

        model.refreshDisplays(.success([privateDisplay, audience]))
        model.showOverlay()

        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertTrue(model.isPaused)
        XCTAssertFalse(controller.teleprompterPanel.isVisible)
    }

    func testPendingShowCannotSurviveTopologyChange() {
        let model = AppModel(overlayController: OverlayPanelController())
        let before = model.pendingShowGeneration

        model.topologyWillChange()

        XCTAssertGreaterThan(model.pendingShowGeneration, before)
        XCTAssertEqual(model.overlaySession.visibility, .hidden)
        XCTAssertTrue(model.isShielded)
    }

    func testNonDrawableOnlineMirrorStillUsesExactWarningAndCannotBeBypassed() throws {
        let privateDisplay = display(id: 1, builtIn: true, x: 0)
        let inventory = try SystemDisplayService.makeInventory(
            drawableDisplays: [privateDisplay],
            onlineIDs: [1, 2],
            factsByID: [
                1: DisplayHardwareFacts(
                    isBuiltIn: true,
                    mirrorSourceID: nil,
                    isInMirrorSet: true,
                    persistentUUID: "display-1",
                    vendorID: 1,
                    modelID: 1,
                    serialNumber: 1
                ),
                2: DisplayHardwareFacts(
                    isBuiltIn: false,
                    mirrorSourceID: 1,
                    isInMirrorSet: true,
                    persistentUUID: "display-2",
                    vendorID: 2,
                    modelID: 2,
                    serialNumber: 2
                ),
            ]
        )
        let model = AppModel(overlayController: OverlayPanelController())

        model.refreshDisplayInventory(.success(inventory))
        model.selectDisplay(privateDisplay.id)
        model.confirmSelectedDisplay()
        model.showOverlay()

        XCTAssertEqual(model.warning, AppModel.mirroringWarning)
        XCTAssertTrue(model.isShielded)
        XCTAssertFalse(model.isSelectionConfirmed)
        XCTAssertEqual(inventory.displays.map(\.id), [privateDisplay.id])
        XCTAssertEqual(inventory.topology.displays.count, 2)
    }

    #if DEBUG
    func testTopologyPlacementNeverPresentsNormalController() async {
        let runtime = AppRuntime(proofLevel: .floating)
        runtime.controllerWindowController.close()
        runtime.model.send(.restore(nil))
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        let presentationCount = runtime.controllerWindowController.presentationCount

        runtime.model.refreshDisplays(.success([builtIn, projector]))
        runtime.model.confirmSelectedDisplay()
        await Task.yield()
        runtime.model.topologyWillChange()
        runtime.model.refreshDisplays(.success([builtIn, projector]))
        await Task.yield()

        XCTAssertEqual(runtime.controllerWindowController.presentationCount, presentationCount)
        XCTAssertFalse(runtime.controllerWindowController.window?.isVisible ?? false)
    }

    func testHLockTopologyDragAndResizeNeverOrderControllerOnScreen() async {
        let runtime = AppRuntime(proofLevel: .floating)
        runtime.controllerWindowController.close()
        runtime.model.send(.restore(nil))
        let builtIn = display(id: 1, builtIn: true, x: 0)
        let projector = display(id: 2, builtIn: false, x: 1_440)
        runtime.model.refreshDisplays(.success([builtIn, projector]))
        runtime.model.confirmSelectedDisplay()
        await Task.yield()
        let presentationCount = runtime.controllerWindowController.presentationCount

        runtime.diagnosticHotKeyService.invokeForTesting(.visibility)
        runtime.diagnosticHotKeyService.invokeForTesting(.lock)
        runtime.model.topologyWillChange()
        runtime.model.refreshDisplays(.success([builtIn, projector]))
        runtime.overlayController.updateDrag(translation: CGSize(width: 20, height: 20))
        runtime.overlayController.endInteraction()
        runtime.overlayController.updateResize(
            edge: .bottomRight,
            translation: CGSize(width: 20, height: 20)
        )
        await Task.yield()

        XCTAssertEqual(runtime.controllerWindowController.presentationCount, presentationCount)
        XCTAssertFalse(runtime.controllerWindowController.window?.isVisible ?? false)
    }
    #endif

    private func modelWithScript(
        effectHandler: @escaping @MainActor (AppEffect) -> Void = { _ in }
    ) -> AppModel {
        let model = AppModel(
            overlayController: OverlayPanelController(),
            now: { Date(timeIntervalSince1970: 10) },
            effectHandler: effectHandler
        )
        model.send(.replaceScript(text: "Lecture"))
        return model
    }

    private func snapshot(
        text: String,
        preferences: TeleprompterPreferences = TeleprompterPreferences()
    ) -> PersistedSnapshot {
        PersistedSnapshot(
            revision: 8,
            document: ScriptDocument(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                text: text,
                revision: 4,
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            readingAnchor: ReadingAnchor(),
            preferences: preferences,
            shortcutBindings: KeyboardShortcut.defaultMap.map {
                ShortcutBinding(action: $0.key, shortcut: $0.value)
            }
        )
    }

    private func assertDurableChangeInvalidatesAwaitingClear(
        _ durableChange: (AppModel) -> Void
    ) {
        let model = modelWithScript()
        model.send(.requestClear)
        let token = try! XCTUnwrap(model.pendingClearToken)
        model.send(.confirmClear(token: token))
        let capturedRevision = model.snapshotRevision

        durableChange(model)
        model.send(
            .completePreClearFlush(
                token: token,
                persistedRevision: capturedRevision,
                succeeded: true
            ))

        XCTAssertEqual(model.document.text, "Lecture")
        XCTAssertNil(model.pendingClearToken)
        XCTAssertEqual(model.localError, .clearRequestInvalidated)
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

private actor TerminationFlushGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var hasEntered = false
    private var isReleased = false

    func wait() async {
        hasEntered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}

private struct TerminationNeverSleeper: SnapshotSleeper {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: .seconds(3_600))
    }
}
