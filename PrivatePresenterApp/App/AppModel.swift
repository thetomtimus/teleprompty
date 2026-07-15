import AppKit
import Observation
import QuartzCore
import TeleprompterCore

struct ScrollSessionGeneration: Equatable, Hashable, Sendable {
    fileprivate let value: UUID

    fileprivate init() {
        value = UUID()
    }
}

@MainActor
@Observable
final class AppModel {
    static let mirroringWarning =
        "Display mirroring is on. Students may see the teleprompter. Use Extended Display mode."
    static let queryFailureWarning =
        "Display safety could not be verified. Your script is hidden and the teleprompter is closed."
    static let ambiguityWarning =
        "Private Presenter cannot reliably distinguish these displays. Select and confirm the display only you can see."
    static let noSeparationWarning =
        "No separate audience display protection."

    private(set) var document: ScriptDocument
    private(set) var preferences: TeleprompterPreferences
    private(set) var overlaySession: OverlaySession
    private(set) var panelFrames: [PersistedPanelFrame]
    private(set) var shortcutBindings: [ShortcutBinding]
    private(set) var snapshotRevision: UInt64

    private(set) var displays: [RuntimeDisplay] = []
    private(set) var selectedDisplayID: UInt32?
    private(set) var isSelectionConfirmed = false
    private(set) var isShielded = true
    private(set) var warning: String?
    private(set) var localError: AppLocalError?
    private(set) var pendingShowGeneration = 0
    private(set) var commandDispatchCount = 0
    private(set) var restorationCompleted: Bool
    private(set) var isPersistenceLoadSafe: Bool
    private(set) var isTerminationQuiescing = false
    let proofConfigurationSnapshot: OverlayConfigurationSnapshot

    #if DEBUG
    private(set) var focusEvidence: [LabeledFocusSnapshot] = []
    private(set) var diagnosticHotKeyStatus = "Control-Option-H/L not registered"
    @ObservationIgnored private let diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder?
    @ObservationIgnored private(set) var diagnosticCorrelationID: UUID?
    #endif

    @ObservationIgnored private let overlayController: OverlayPanelController
    @ObservationIgnored private let privacyCoordinator: PrivacyCoordinator
    @ObservationIgnored private let topologyEvaluator = DisplayTopologyEvaluator()
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let effectHandler: @MainActor (AppEffect) -> Void
    @ObservationIgnored private var latestTopology: DisplayTopologySnapshot?
    @ObservationIgnored private var candidateFingerprint: DisplayFingerprint?
    @ObservationIgnored private var pendingClear: PendingClear?
    @ObservationIgnored private var pendingShieldedMoveDisplayID: UInt32?
    @ObservationIgnored private var pendingCommands: [AppCommand] = []
    @ObservationIgnored private var isDrainingCommands = false
    @ObservationIgnored private(set) var currentScrollGeneration = ScrollSessionGeneration()
    @ObservationIgnored private var isReaderAttached = false
    @ObservationIgnored private var pendingScrollRetirement: PendingScrollRetirement?
    @ObservationIgnored private var lastAcceptedScrollCheckpointUptime: TimeInterval?

    private struct PendingScrollRetirement {
        let retiring: ScrollSessionGeneration
        let replacement: ScrollSessionGeneration
        let reason: ScrollRetirementReason
    }

    private struct PendingClear {
        enum Phase: Equatable {
            case confirmationRequired
            case awaitingPreClearFlush
        }

        let token: ClearToken
        let documentRevision: UInt64
        let snapshotRevision: UInt64
        var phase: Phase
    }

    #if DEBUG
    convenience init(
        overlayController: OverlayPanelController,
        privacyCoordinator: PrivacyCoordinator = PrivacyCoordinator(),
        document: ScriptDocument? = nil,
        now: @escaping @MainActor () -> Date = { Date() },
        restorationRequired: Bool = false,
        diagnosticEvidenceRecorder: DiagnosticEvidenceRecorder? = nil,
        effectHandler: (@MainActor (AppEffect) -> Void)? = nil
    ) {
        self.init(
            overlayController: overlayController,
            privacyCoordinator: privacyCoordinator,
            document: document,
            now: now,
            restorationRequired: restorationRequired,
            diagnosticEvidenceRecorderObject: diagnosticEvidenceRecorder,
            effectHandler: effectHandler
        )
    }
    #else
    convenience init(
        overlayController: OverlayPanelController,
        privacyCoordinator: PrivacyCoordinator = PrivacyCoordinator(),
        document: ScriptDocument? = nil,
        now: @escaping @MainActor () -> Date = { Date() },
        restorationRequired: Bool = false,
        effectHandler: (@MainActor (AppEffect) -> Void)? = nil
    ) {
        self.init(
            overlayController: overlayController,
            privacyCoordinator: privacyCoordinator,
            document: document,
            now: now,
            restorationRequired: restorationRequired,
            diagnosticEvidenceRecorderObject: nil,
            effectHandler: effectHandler
        )
    }
    #endif

    private init(
        overlayController: OverlayPanelController,
        privacyCoordinator: PrivacyCoordinator,
        document: ScriptDocument?,
        now: @escaping @MainActor () -> Date,
        restorationRequired: Bool,
        diagnosticEvidenceRecorderObject: AnyObject?,
        effectHandler: (@MainActor (AppEffect) -> Void)?
    ) {
        self.overlayController = overlayController
        self.privacyCoordinator = privacyCoordinator
        self.now = now
        self.document = document ?? ScriptDocument(updatedAt: now())
        preferences = TeleprompterPreferences()
        overlaySession = OverlaySession()
        panelFrames = []
        shortcutBindings = Self.defaultShortcutBindings
        snapshotRevision = 0
        restorationCompleted = !restorationRequired
        isPersistenceLoadSafe = !restorationRequired
        proofConfigurationSnapshot = overlayController.configurationSnapshot
        #if DEBUG
        diagnosticEvidenceRecorder =
            diagnosticEvidenceRecorderObject
            as? DiagnosticEvidenceRecorder
        #endif
        self.effectHandler =
            effectHandler ?? { effect in
                Self.applyDefault(effect, overlayController: overlayController)
            }
    }

    var isPaused: Bool {
        overlaySession.playbackPhase == .paused
    }

    var isLocked: Bool {
        preferences.isLocked
    }

    var pendingClearToken: ClearToken? {
        pendingClear?.token
    }

    var isAwaitingPreClearFlush: Bool {
        pendingClear?.phase == .awaitingPreClearFlush
    }

    var selectedDisplayName: String {
        guard isSelectionConfirmed,
            overlaySession.recoveryConfirmationState == .confirmed
        else { return "No display selected" }
        return displays.first(where: { $0.id == selectedDisplayID })?.localizedName
            ?? "No display selected"
    }

    var topologyStatus: ControllerTopologyStatus {
        guard latestTopology?.querySucceeded == true else { return .queryFailure }
        if warning == Self.mirroringWarning { return .mirrored }
        if warning == Self.ambiguityWarning { return .ambiguous }
        if warning?.contains("missing") == true { return .missing }
        if latestTopology?.displays.filter(\.isOnline).count == 1 { return .single }
        return .extended
    }

    var configurationSnapshot: OverlayConfigurationSnapshot {
        overlayController.configurationSnapshot
    }

    func send(_ command: AppCommand) {
        guard acceptsDuringTermination(command) else { return }
        pendingCommands.append(command)
        guard !isDrainingCommands else { return }

        isDrainingCommands = true
        defer { isDrainingCommands = false }
        while !pendingCommands.isEmpty {
            let next = pendingCommands.removeFirst()
            guard acceptsDuringTermination(next) else { continue }
            commandDispatchCount += 1
            reduce(next)
        }
    }

    private func reduce(_ command: AppCommand) {
        switch command {
        case .replaceScript(let text):
            replaceScript(text)
        case .applyScriptEdit(let edit):
            applyScriptEdit(edit)
        case .readerResyncRequested:
            let generation = retireScrollSession(reason: .resync)
            effectHandler(
                .replaceReader(
                    text: document.text,
                    revision: document.revision,
                    reason: .resync,
                    generation: generation,
                    anchor: nil
                ))
        case .scrollCheckpoint(let checkpoint):
            accept(checkpoint)
        case .scrollTerminal(let terminal):
            accept(terminal)
        case .scrollTerminalCapture(let capture):
            accept(capture)
        case .scrollMutationCompleted(let result):
            accept(result)
        case .readerAttachmentChanged(let isAttached):
            let wasAttached = isReaderAttached
            isReaderAttached = isAttached
            if wasAttached || overlaySession.playbackPhase == .playing {
                _ = retireScrollSession(reason: .attachment)
            }
            effectHandler(
                .readerAttachmentChanged(
                    isAttached: isAttached,
                    binding: currentScrollBinding
                ))
        case .readerScreenChanged:
            _ = retireScrollSession(reason: .screenMove)
            effectHandler(.readerScreenChanged(currentScrollBinding))
        case .readerBoundsWillChange:
            _ = retireScrollSession(reason: .resize)
        case .readerBoundsChanged:
            effectHandler(.restoreScrollLayout(currentScrollBinding))
        case .teardownScrollSession:
            let generation = retireScrollSession(reason: .teardown)
            effectHandler(.teardownScrollSession(generation))
        case .setScriptTitle(let title):
            setScriptTitle(title)
        case .setFontSize(let size):
            setFontSize(size)
        case .setTextAlignment(let alignment):
            setTextAlignment(alignment)
        case .setActiveBandEnabled(let enabled):
            setActiveBandEnabled(enabled)
        case .panelFrameChanged(let displayID, let frame):
            panelFrameChanged(displayID: displayID, frame: frame)
        case .requestClear:
            requestClear()
        case .confirmClear(let token):
            confirmClear(token)
        case .cancelClear:
            pendingClear = nil
        case .completePreClearFlush(let token, let persistedRevision, let succeeded):
            completePreClearFlush(
                token: token,
                persistedRevision: persistedRevision,
                succeeded: succeeded
            )
        case .start:
            startPlayback()
        case .pause:
            pausePlayback()
        case .togglePlayback:
            if overlaySession.playbackPhase == .playing {
                pausePlayback()
            } else {
                startPlayback()
            }
        case .restart:
            restart()
        case .setSpeed(let speed):
            setSpeed(speed)
        case .moveBackward:
            moveReader(.backward)
        case .moveForward:
            moveReader(.forward)
        case .showOverlay:
            showOverlayCommand()
        case .hideOverlay:
            hideOverlayCommand()
        case .setLocked(let locked):
            setLockedCommand(locked)
        case .restore(let snapshot):
            restore(snapshot)
        case .restoreFailed:
            restoreFailed()
        case .flushPersistence:
            effectHandler(.flushPersistence)
        case .topologyWillChange:
            pendingShieldedMoveDisplayID = nil
            let stop = retireScrollSessionEffect(reason: .topology)
            emit([stop] + applyPrivacyDirectives(privacyCoordinator.topologyWillChange()))
        case .displayInventoryLoaded(let inventory):
            refreshDisplayInventory(inventory)
        case .displayInventoryFailed:
            refreshDisplayInventoryFailed()
        case .selectDisplay(let id):
            selectDisplayCommand(id)
        case .confirmSelectedDisplay:
            confirmSelectedDisplayCommand()
        case .completeShieldedMove(let screenID):
            completeShieldedMove(screenID: screenID)
        case .keepScriptHidden:
            keepScriptHiddenCommand()
        }
    }

    #if DEBUG
    func send(_ command: AppCommand, correlationID: UUID) {
        let previousCorrelationID = diagnosticCorrelationID
        diagnosticCorrelationID = correlationID
        send(command)
        diagnosticCorrelationID = previousCorrelationID
    }
    #endif

    func beginTerminationQuiescence() {
        isTerminationQuiescing = true
    }

    // MARK: - Milestone 0 mechanical compatibility

    func refreshDisplays(_ result: Result<[RuntimeDisplay], Error>) {
        switch result {
        case .success(let displays):
            send(.displayInventoryLoaded(RuntimeDisplayInventory(displays: displays)))
        case .failure:
            send(.displayInventoryFailed)
        }
    }

    func refreshDisplayInventory(_ result: Result<RuntimeDisplayInventory, Error>) {
        switch result {
        case .success(let inventory):
            send(.displayInventoryLoaded(inventory))
        case .failure:
            send(.displayInventoryFailed)
        }
    }

    func topologyWillChange() {
        send(.topologyWillChange)
    }

    func selectDisplay(_ id: UInt32?) {
        send(.selectDisplay(id))
    }

    func confirmSelectedDisplay() {
        send(.confirmSelectedDisplay)
    }

    func keepScriptHidden() {
        send(.keepScriptHidden)
    }

    func showOverlay() {
        send(.showOverlay)
    }

    func hideOverlay() {
        send(.hideOverlay)
        #if DEBUG
        captureFocus(label: "after hide")
        #endif
    }

    func setLocked(_ locked: Bool) {
        send(.setLocked(locked))
        #if DEBUG
        captureFocus(label: locked ? "after lock" : "after unlock")
        #endif
    }

    #if DEBUG
    func setDiagnosticHotKeyStatus(_ status: DiagnosticHotKeyRegistrationStatus) {
        diagnosticHotKeyStatus =
            status.allRegistered
            ? "Control-Option-H and Control-Option-L registered"
            : "Diagnostic hot-key registration failed (H=\(status.visibility), L=\(status.lock))"
    }

    func toggleOverlayFromDiagnosticHotKey(correlationID: UUID? = nil) {
        diagnosticCorrelationID = correlationID
        let command: DiagnosticCommandName =
            overlaySession.visibility == .visible
            ? .hideOverlay
            : .showOverlay
        diagnosticEvidenceRecorder?.record(
            kind: .commandBefore,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(command: command)
        )
        if overlaySession.visibility == .visible {
            send(.hideOverlay)
        } else {
            send(.showOverlay)
        }
        diagnosticEvidenceRecorder?.record(
            kind: .commandAfter,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(command: command)
        )
        diagnosticCorrelationID = nil
    }

    func toggleLockFromDiagnosticHotKey(correlationID: UUID? = nil) {
        diagnosticCorrelationID = correlationID
        diagnosticEvidenceRecorder?.record(
            kind: .commandBefore,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(command: .toggleLock)
        )
        send(.setLocked(!preferences.isLocked))
        diagnosticEvidenceRecorder?.record(
            kind: .commandAfter,
            correlationID: correlationID,
            payload: DiagnosticEventPayload(command: .toggleLock)
        )
        diagnosticCorrelationID = nil
    }

    func captureFocus(label: String) {
        focusEvidence.append(
            LabeledFocusSnapshot(
                label: label,
                snapshot: WorkspaceFocusProbe.capture(
                    panel: overlayController.teleprompterPanel
                )
            )
        )
    }

    var diagnosticSummary: String {
        let configuration = proofConfigurationSnapshot
        let configurationLine = [
            "level=\(configuration.level)",
            "panels=\(configuration.panelCount)",
            "borderless=\(configuration.isBorderless)",
            "nonactivating=\(configuration.isNonactivating)",
            "resizable=\(configuration.isNativelyResizable)",
            "allSpaces=\(configuration.joinsAllSpaces)",
            "fullScreenAuxiliary=\(configuration.isFullScreenAuxiliary)",
            "opaqueInterior=\(configuration.interiorIsFullyOpaque)",
        ].joined(separator: " | ")
        guard !focusEvidence.isEmpty else {
            return configurationLine + "\n" + diagnosticHotKeyStatus + "\nNo focus capture yet"
        }
        let focusLines = focusEvidence.suffix(8).map { record in
            let focus = record.snapshot
            return [
                record.label,
                "pid=\(focus.processIdentifier.map { String($0) } ?? "nil")",
                "bundle=\(focus.bundleIdentifier ?? "nil")",
                "panelKey=\(focus.panelIsKey)",
                "panelMain=\(focus.panelIsMain)",
            ].joined(separator: " | ")
        }
        return ([configurationLine, diagnosticHotKeyStatus] + focusLines)
            .joined(separator: "\n")
    }
    #endif

    // MARK: - Durable state reducer

    private func replaceScript(_ text: String) {
        guard text != document.text else { return }
        guard let edit = try? ScriptTextEdit.replacing(
            in: document.text,
            range: UTF16TextRange(location: 0, length: document.text.utf16.count),
            with: text,
            baseRevision: document.revision
        ) else { return }
        applyScriptEdit(edit)
    }

    private func applyScriptEdit(_ edit: ScriptTextEdit) {
        let preEditDocument = document.text
        let wasPlaying = overlaySession.playbackPhase == .playing
        let generation = retireScrollSession(reason: .readerEdit)
        guard let updatedText = try? edit.applying(
            to: preEditDocument,
            revision: document.revision
        ) else { return }
        localError = nil
        invalidatePendingClearForDurableChange()
        document.text = updatedText
        document.revision = edit.revision
        document.updatedAt = now()
        overlaySession.readingAnchor = overlaySession.readingAnchor.clamped(to: updatedText)
        snapshotRevision += 1
        let persistedSnapshot = snapshot()
        effectHandler(
            .applyReaderEdit(
                edit: edit,
                preEditDocument: preEditDocument,
                postEditDocument: updatedText,
                generation: generation,
                wasPlaying: wasPlaying
            ))
        effectHandler(.scheduleSnapshot(persistedSnapshot))
    }

    private func setScriptTitle(_ title: String) {
        let normalized = Self.normalizedTitle(title)
        guard normalized != document.title else { return }
        localError = nil
        invalidatePendingClearForDurableChange()
        document.title = normalized
        document.updatedAt = now()
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
    }

    private func setFontSize(_ size: Double) {
        let normalized = size.isFinite
            ? min(max(size, TeleprompterPreferences.fontSizeRange.lowerBound),
                TeleprompterPreferences.fontSizeRange.upperBound)
            : TeleprompterPreferences.defaultFontSizePoints
        guard normalized != preferences.fontSizePoints else { return }
        invalidatePendingClearForDurableChange()
        preferences.fontSizePoints = normalized
        commitReaderAppearanceChange()
    }

    private func setTextAlignment(_ alignment: TeleprompterTextAlignment) {
        guard alignment != preferences.textAlignment else { return }
        invalidatePendingClearForDurableChange()
        preferences.textAlignment = alignment
        commitReaderAppearanceChange()
    }

    private func setActiveBandEnabled(_ enabled: Bool) {
        guard enabled != preferences.isActiveBandEnabled else { return }
        invalidatePendingClearForDurableChange()
        preferences.isActiveBandEnabled = enabled
        commitReaderAppearanceChange()
    }

    private func commitReaderAppearanceChange() {
        let generation = retireScrollSession(reason: .readerAttributes)
        snapshotRevision += 1
        let persistedSnapshot = snapshot()
        effectHandler(
            .updateReaderAttributes(
                fontSize: preferences.fontSizePoints,
                alignment: preferences.textAlignment,
                activeBandEnabled: preferences.isActiveBandEnabled,
                generation: generation,
                anchor: nil
            ))
        effectHandler(.scheduleSnapshot(persistedSnapshot))
    }

    private func panelFrameChanged(displayID: UInt32, frame: CGRect) {
        guard isSelectionConfirmed,
            overlaySession.recoveryConfirmationState == .confirmed,
            overlaySession.currentSessionDisplayID == displayID,
            selectedDisplayID == displayID,
            let latestTopology,
            let display = displays.first(where: { $0.id == displayID }),
            let descriptor = latestTopology.displays.first(where: { $0.sessionID == displayID }),
            topologyEvaluator.isPersistenceEligible(
                descriptor.fingerprint,
                in: latestTopology.displays
            ),
            let key = descriptor.fingerprint.persistentIdentityKey
        else { return }

        let normalizedFrame = PanelFramePolicy().normalize(
            DisplayRect(frame),
            in: DisplayRect(display.visibleFrame)
        )
        let entry = PersistedPanelFrame(
            displayFingerprint: descriptor.fingerprint.normalized,
            frame: normalizedFrame
        )
        if panelFrames.first(where: {
            $0.displayFingerprint.persistentIdentityKey == key
        }) == entry {
            return
        }
        panelFrames.removeAll {
            $0.displayFingerprint.persistentIdentityKey == key
        }
        panelFrames.append(entry)
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
    }

    private static func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Lecture Teleprompter" }
        var result = ""
        var scalarCount = 0
        for character in trimmed {
            let characterScalars = character.unicodeScalars.count
            guard scalarCount + characterScalars <= 120 else { break }
            result.append(character)
            scalarCount += characterScalars
        }
        return result.isEmpty ? "Lecture Teleprompter" : result
    }

    private func requestClear() {
        guard !document.text.isEmpty else { return }
        pendingClear = PendingClear(
            token: .issue(),
            documentRevision: document.revision,
            snapshotRevision: snapshotRevision,
            phase: .confirmationRequired
        )
    }

    private func confirmClear(_ token: ClearToken) {
        guard
            var request = pendingClear,
            request.token == token,
            request.phase == .confirmationRequired,
            request.documentRevision == document.revision,
            request.snapshotRevision == snapshotRevision
        else { return }
        request.phase = .awaitingPreClearFlush
        pendingClear = request
        effectHandler(
            .flushSnapshot(
                token: token,
                requiredRevision: request.snapshotRevision
            ))
    }

    private func completePreClearFlush(
        token: ClearToken,
        persistedRevision: UInt64,
        succeeded: Bool
    ) {
        guard
            let request = pendingClear,
            request.token == token,
            request.phase == .awaitingPreClearFlush,
            request.documentRevision == document.revision,
            request.snapshotRevision == snapshotRevision
        else { return }

        guard succeeded, persistedRevision == request.snapshotRevision else {
            pendingClear = nil
            localError = .preClearFlushFailed
            return
        }

        let generation = retireScrollSession(reason: .clear)
        pendingClear = nil
        localError = nil
        document.text = ""
        document.revision += 1
        document.updatedAt = now()
        snapshotRevision += 1
        overlaySession.readingAnchor = ReadingAnchor()
        overlaySession.pixelOffset = 0
        overlaySession.playbackPhase = .paused
        let persistedSnapshot = snapshot()
        effectHandler(
            .replaceReader(
                text: document.text,
                revision: document.revision,
                reason: .clear,
                generation: generation,
                anchor: overlaySession.readingAnchor
            ))
        effectHandler(.saveSnapshotImmediately(persistedSnapshot))
    }

    private func startPlayback() {
        guard !document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            overlaySession.playbackPhase = .paused
            return
        }
        guard overlaySession.playbackPhase == .paused else { return }
        let generation = ScrollSessionGeneration()
        currentScrollGeneration = generation
        pendingScrollRetirement = nil
        overlaySession.playbackPhase = .playing
        let uptime = CACurrentMediaTime()
        lastAcceptedScrollCheckpointUptime = uptime
        effectHandler(
            .startScrollSession(
                binding: currentScrollBinding,
                uptime: uptime
            ))
    }

    private func pausePlayback() {
        guard overlaySession.playbackPhase == .playing else { return }
        _ = retireScrollSession(reason: .commandPause)
    }

    private func setSpeed(_ speed: Double) {
        let normalized = speed.isFinite
            ? min(max(speed, TeleprompterPreferences.speedRange.lowerBound),
                TeleprompterPreferences.speedRange.upperBound)
            : TeleprompterPreferences.defaultSpeedPointsPerSecond
        guard normalized != preferences.speedPointsPerSecond else { return }
        invalidatePendingClearForDurableChange()
        preferences.speedPointsPerSecond = normalized
        snapshotRevision += 1
        emit([
            .updateScrollSpeed(
                currentScrollGeneration,
                normalized,
                CACurrentMediaTime()
            ),
            .scheduleSnapshot(snapshot()),
        ])
    }

    private func moveReader(_ direction: ScrollManualDirection) {
        effectHandler(
            .moveScrollSession(
                binding: currentScrollBinding,
                direction: direction,
                uptime: CACurrentMediaTime()
            ))
    }

    private func restart() {
        localError = nil
        invalidatePendingClearForDurableChange()
        let generation = retireScrollSession(reason: .restart)
        overlaySession.readingAnchor = ReadingAnchor()
        overlaySession.pixelOffset = 0
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
        effectHandler(.resetViewport(generation))
    }

    private func restore(_ persistedSnapshot: PersistedSnapshot?) {
        let generation = retireScrollSession(reason: .restore)
        if let persistedSnapshot {
            let shortcutResolution = ShortcutRestorePolicy.resolve(persistedSnapshot)
            let restoredSnapshot = shortcutResolution.snapshot
            document = restoredSnapshot.document
            preferences = restoredSnapshot.preferences
            panelFrames = restoredSnapshot.panelFrames
            shortcutBindings = restoredSnapshot.shortcutBindings
            snapshotRevision = restoredSnapshot.revision
            overlaySession = RestoredState(snapshot: restoredSnapshot).overlaySession
            candidateFingerprint = preferences.selectedDisplayFingerprint
            localError = shortcutResolution.usedDefaultBindings
                ? .invalidShortcutConfiguration
                : nil
        } else {
            overlaySession = OverlaySession()
            candidateFingerprint = preferences.selectedDisplayFingerprint
            localError = nil
        }
        restorationCompleted = true
        isPersistenceLoadSafe = true
        displays = []
        latestTopology = nil
        selectedDisplayID = nil
        isSelectionConfirmed = false
        isShielded = true
        warning = nil
        pendingClear = nil
        pendingShieldedMoveDisplayID = nil
        emit([
            .reassessPrivacy,
            .setPanelLocked(preferences.isLocked),
            .replaceReader(
                text: document.text,
                revision: document.revision,
                reason: .restore,
                generation: generation,
                anchor: overlaySession.readingAnchor
            ),
            .updateReaderAttributes(
                fontSize: preferences.fontSizePoints,
                alignment: preferences.textAlignment,
                activeBandEnabled: preferences.isActiveBandEnabled,
                generation: generation,
                anchor: overlaySession.readingAnchor
            ),
        ])
    }

    private func restoreFailed() {
        _ = retireScrollSession(reason: .restore)
        restorationCompleted = true
        isPersistenceLoadSafe = false
        overlaySession = OverlaySession()
        displays = []
        latestTopology = nil
        selectedDisplayID = nil
        candidateFingerprint = preferences.selectedDisplayFingerprint
        isSelectionConfirmed = false
        isShielded = true
        warning = Self.queryFailureWarning
        localError = .snapshotLoadFailed
        pendingClear = nil
        pendingShieldedMoveDisplayID = nil
        emit([.reassessPrivacy, .setPanelLocked(preferences.isLocked)])
    }

    private func snapshot() -> PersistedSnapshot {
        PersistedSnapshot(
            revision: snapshotRevision,
            document: document,
            readingAnchor: overlaySession.readingAnchor,
            preferences: preferences,
            panelFrames: panelFrames,
            shortcutBindings: shortcutBindings
        )
    }

    // MARK: - Display/privacy reducer

    private func refreshDisplayInventory(_ inventory: RuntimeDisplayInventory) {
        let stop = retireScrollSessionEffect(reason: .privacy)
        isSelectionConfirmed = false
        displays = inventory.displays
        latestTopology = inventory.topology
        var effects = applyPrivacyDirectives(
            privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
        )

        let evaluation = topologyEvaluator.evaluate(
            snapshot: inventory.topology,
            selection: unconfirmedSelection()
        )
        warning = warningMessage(for: evaluation.assessment)
        if let candidate = evaluation.candidate,
            let runtimeDisplay = displays.first(where: { $0.id == candidate.sessionID })
        {
            selectedDisplayID = candidate.sessionID
            candidateFingerprint = candidate.fingerprint
            effects.append(.stagePanelHidden(runtimeDisplay, proposedFrame: nil))
            effects.append(.moveControllerWhileShielded(runtimeDisplay))
        } else {
            selectedDisplayID = nil
            candidateFingerprint = nil
        }
        emit([stop] + effects)
    }

    private func refreshDisplayInventoryFailed() {
        let stop = retireScrollSessionEffect(reason: .privacy)
        displays = []
        selectedDisplayID = nil
        candidateFingerprint = nil
        latestTopology = nil
        let effects = applyPrivacyDirectives(
            privacyCoordinator.topologyWasEvaluated(
                confirmedSafeScreenID: nil,
                isSafe: false
            )
        )
        warning = Self.queryFailureWarning
        emit([stop] + effects)
    }

    private func selectDisplayCommand(_ id: UInt32?) {
        let stop = retireScrollSessionEffect(reason: .screenMove)
        isSelectionConfirmed = false
        isShielded = true
        overlaySession.visibility = .hidden
        overlaySession.currentSessionDisplayID = nil
        overlaySession.recoveryConfirmationState = .required
        pendingShieldedMoveDisplayID = nil
        var effects: [AppEffect] = [stop, .hidePanel]
        selectedDisplayID = id
        guard
            let id,
            let display = displays.first(where: { $0.id == id }),
            let descriptor = latestTopology?.displays.first(where: { $0.sessionID == id })
        else {
            candidateFingerprint = nil
            emit(effects)
            return
        }
        candidateFingerprint = descriptor.fingerprint
        if let latestTopology {
            let evaluation = topologyEvaluator.evaluate(
                snapshot: latestTopology,
                selection: unconfirmedSelection()
            )
            warning = warningMessage(for: evaluation.assessment)
            if display.isOnline {
                effects.append(.stagePanelHidden(display, proposedFrame: nil))
            }
        }
        emit(effects)
    }

    private func confirmSelectedDisplayCommand() {
        guard
            isPersistenceLoadSafe,
            let latestTopology,
            let selection = confirmedSelection(),
            let selectedDisplayID,
            displays.contains(where: { $0.id == selectedDisplayID })
        else {
            isSelectionConfirmed = false
            isShielded = true
            return
        }
        let evaluation = topologyEvaluator.evaluate(
            snapshot: latestTopology,
            selection: selection
        )
        guard
            evaluation.canOpenOverlay,
            evaluation.candidate?.sessionID == selectedDisplayID
        else {
            isSelectionConfirmed = false
            isShielded = true
            warning = warningMessage(for: evaluation.assessment)
            return
        }

        overlaySession.currentSessionDisplayID = selectedDisplayID
        overlaySession.recoveryConfirmationState = .confirmed
        isSelectionConfirmed = true
        let directives = privacyCoordinator.topologyWasEvaluated(
            confirmedSafeScreenID: selectedDisplayID,
            isSafe: true
        )
        var effects = [retireScrollSessionEffect(reason: .privacy)]
            + applyPrivacyDirectives(directives)
        warning = warningMessage(for: evaluation.assessment)
        pendingShieldedMoveDisplayID = selectedDisplayID

        let persistableFingerprint = candidateFingerprint.flatMap { fingerprint in
            topologyEvaluator.isPersistenceEligible(
                fingerprint,
                in: latestTopology.displays
            ) ? fingerprint.normalized : nil
        }
        if preferences.selectedDisplayFingerprint != persistableFingerprint {
            invalidatePendingClearForDurableChange()
            preferences.selectedDisplayFingerprint = persistableFingerprint
            snapshotRevision += 1
            effects.append(.scheduleSnapshot(snapshot()))
        }
        emit(effects)
    }

    private func completeShieldedMove(screenID: UInt32) {
        guard
            isPersistenceLoadSafe,
            pendingShieldedMoveDisplayID == screenID,
            selectedDisplayID == screenID,
            isSelectionConfirmed,
            overlaySession.recoveryConfirmationState == .confirmed
        else { return }
        pendingShieldedMoveDisplayID = nil
        isShielded = false
    }

    private func keepScriptHiddenCommand() {
        let stop = retireScrollSessionEffect(reason: .privacy)
        isSelectionConfirmed = false
        isShielded = true
        overlaySession.visibility = .hidden
        overlaySession.playbackPhase = .paused
        overlaySession.currentSessionDisplayID = nil
        overlaySession.recoveryConfirmationState = .required
        pendingShieldedMoveDisplayID = nil
        emit([stop, .hidePanel])
    }

    private func showOverlayCommand() {
        guard
            restorationCompleted,
            isPersistenceLoadSafe,
            isSelectionConfirmed,
            !isShielded,
            pendingShieldedMoveDisplayID == nil,
            overlaySession.recoveryConfirmationState == .confirmed,
            let latestTopology,
            let selection = confirmedSelection(),
            let selectedDisplayID,
            let display = displays.first(where: { $0.id == selectedDisplayID })
        else { return }
        let evaluation = topologyEvaluator.evaluate(
            snapshot: latestTopology,
            selection: selection
        )
        guard evaluation.canOpenOverlay,
            evaluation.candidate?.sessionID == selectedDisplayID
        else { return }
        pendingShowGeneration += 1
        overlaySession.visibility = .visible
        #if DEBUG
        captureFocus(label: "before show")
        #endif
        effectHandler(
            .showPanel(
                display,
                proposedFrame: restoredFrame(for: display)
            ))
        #if DEBUG
        captureFocus(label: "after show")
        #endif
    }

    private func hideOverlayCommand() {
        let stop = retireScrollSessionEffect(reason: .hide)
        overlaySession.visibility = .hidden
        emit([stop, .hidePanel])
    }

    private func setLockedCommand(_ locked: Bool) {
        guard preferences.isLocked != locked else { return }
        invalidatePendingClearForDurableChange()
        preferences.isLocked = locked
        snapshotRevision += 1
        emit([.setPanelLocked(locked), .scheduleSnapshot(snapshot())])
    }

    private func restoredFrame(for display: RuntimeDisplay) -> CGRect? {
        guard let latestTopology,
            let descriptor = latestTopology.displays.first(where: {
                $0.sessionID == display.id
            }),
            topologyEvaluator.isPersistenceEligible(
                descriptor.fingerprint,
                in: latestTopology.displays
            )
        else { return nil }
        let matches = panelFrames.filter {
            $0.displayFingerprint.relationship(to: descriptor.fingerprint) == .match
        }
        guard matches.count == 1, let normalized = matches.first?.frame else { return nil }
        return CGRect(
            PanelFramePolicy().restore(
                normalized,
                in: DisplayRect(display.visibleFrame)
            )
        )
    }

    private func applyPrivacyDirectives(_ directives: [PrivacyDirective]) -> [AppEffect] {
        var externalEffects: [AppEffect] = []
        for directive in directives {
            #if DEBUG
            diagnosticEvidenceRecorder?.record(
                kind: .directiveBefore,
                correlationID: diagnosticCorrelationID,
                payload: DiagnosticEventPayload(privacyDirective: directive.diagnosticName)
            )
            #endif
            switch directive {
            case .pauseScrolling:
                overlaySession.playbackPhase = .paused
            case .hideOverlay:
                overlaySession.visibility = .hidden
                externalEffects.append(.hidePanel)
            case .shieldController:
                isShielded = true
            case .invalidatePendingShow:
                pendingShowGeneration += 1
            case .queryTopology:
                externalEffects.append(.queryTopology)
            case .evaluatePrivacy:
                externalEffects.append(.evaluatePrivacy)
            case .moveWindowsWhileShielded(let screenID):
                if let display = displays.first(where: { $0.id == screenID }) {
                    externalEffects.append(
                        .stagePanelHidden(
                            display,
                            proposedFrame: restoredFrame(for: display)
                        ))
                    externalEffects.append(.moveControllerWhileShielded(display))
                }
            case .requestConfirmation:
                isSelectionConfirmed = false
                pendingShieldedMoveDisplayID = nil
                overlaySession.currentSessionDisplayID = nil
                overlaySession.recoveryConfirmationState = .required
            case .publishSafeState:
                break
            }
            #if DEBUG
            diagnosticEvidenceRecorder?.record(
                kind: .directiveAfter,
                correlationID: diagnosticCorrelationID,
                payload: DiagnosticEventPayload(privacyDirective: directive.diagnosticName)
            )
            #endif
        }
        return externalEffects
    }

    private func unconfirmedSelection() -> DisplaySelection? {
        guard
            let fingerprint = candidateFingerprint
                ?? preferences.selectedDisplayFingerprint
        else { return nil }
        return DisplaySelection(
            fingerprint: fingerprint,
            isConfirmed: false,
            isConfirmedInCurrentSession: false,
            currentSessionID: selectedDisplayID
        )
    }

    private func confirmedSelection() -> DisplaySelection? {
        guard
            let fingerprint = candidateFingerprint
                ?? preferences.selectedDisplayFingerprint
        else { return nil }
        return DisplaySelection(
            fingerprint: fingerprint,
            isConfirmed: true,
            isConfirmedInCurrentSession: true,
            currentSessionID: selectedDisplayID
        )
    }

    private func warningMessage(for assessment: DisplayPrivacyAssessment) -> String? {
        switch assessment {
        case .blockedMirroring:
            Self.mirroringWarning
        case .ambiguousIdentity:
            Self.ambiguityWarning
        case .systemQueryFailed:
            Self.queryFailureWarning
        case .singleDisplayNoAudienceSeparation:
            Self.noSeparationWarning
        case .selectedDisplayMissing:
            "The selected private display is missing. Confirm a safe display before showing."
        case .selectionRequired:
            "Select and confirm the display only you can see."
        case .confirmationRequired, .safeCandidate:
            nil
        }
    }

    private static var defaultShortcutBindings: [ShortcutBinding] {
        ShortcutValidator.defaultBindings
    }

    private func retireScrollSessionEffect(
        reason: ScrollRetirementReason
    ) -> AppEffect {
        let retiring = currentScrollGeneration
        let replacement = ScrollSessionGeneration()
        currentScrollGeneration = replacement
        pendingScrollRetirement = PendingScrollRetirement(
            retiring: retiring,
            replacement: replacement,
            reason: reason
        )
        lastAcceptedScrollCheckpointUptime = nil
        overlaySession.playbackPhase = .paused
        return .stopScrollSession(
            retiring: retiring,
            replacement: replacement,
            reason: reason,
            fallbackAnchor: overlaySession.readingAnchor,
            fallbackOffset: overlaySession.pixelOffset
        )
    }

    @discardableResult
    private func retireScrollSession(
        reason: ScrollRetirementReason
    ) -> ScrollSessionGeneration {
        effectHandler(retireScrollSessionEffect(reason: reason))
        return currentScrollGeneration
    }

    private func accept(_ checkpoint: ScrollCheckpoint) {
        let respectsCheckpointRate = lastAcceptedScrollCheckpointUptime.map({
            checkpoint.uptime >= $0 && checkpoint.uptime - $0 >= 1
        }) ?? true
        guard
            checkpoint.generation == currentScrollGeneration,
            checkpoint.uptime.isFinite,
            respectsCheckpointRate
        else { return }
        lastAcceptedScrollCheckpointUptime = checkpoint.uptime
        acceptPosition(anchor: checkpoint.anchor, offset: checkpoint.pixelOffset)
    }

    private var currentScrollBinding: ScrollSessionBinding {
        ScrollSessionBinding(
            generation: currentScrollGeneration,
            anchor: overlaySession.readingAnchor,
            offset: overlaySession.pixelOffset,
            speed: preferences.speedPointsPerSecond
        )
    }

    private func accept(_ terminal: ScrollTerminalResult) {
        guard
            terminal.generation == currentScrollGeneration,
            overlaySession.playbackPhase == .playing
        else { return }
        overlaySession.playbackPhase = .paused
        currentScrollGeneration = ScrollSessionGeneration()
        pendingScrollRetirement = nil
        lastAcceptedScrollCheckpointUptime = nil
        acceptPosition(anchor: terminal.anchor, offset: terminal.pixelOffset)
    }

    private func accept(_ capture: ScrollTerminalCapture) {
        guard
            let pending = pendingScrollRetirement,
            capture.retiringGeneration == pending.retiring,
            capture.replacementGeneration == pending.replacement,
            capture.reason == pending.reason
        else { return }
        pendingScrollRetirement = nil
        switch capture.reason {
        case .restart, .readerEdit, .clear, .restore, .readerReplacement, .resync:
            return
        case .commandPause, .hide, .topology, .privacy,
            .readerAttributes, .resize, .attachment, .screenMove, .teardown:
            acceptPosition(anchor: capture.anchor, offset: capture.pixelOffset)
        }
    }

    private func accept(_ result: ScrollMutationResult) {
        guard result.generation == currentScrollGeneration else { return }
        guard result.outcome != .failed else {
            overlaySession.playbackPhase = .paused
            return
        }
        acceptPosition(anchor: result.anchor, offset: result.pixelOffset)
        if result.mayResume {
            startPlayback()
        }
    }

    private func acceptPosition(anchor: ReadingAnchor, offset: Double) {
        let normalizedAnchor = anchor.clamped(to: document.text)
        let normalizedOffset = offset.isFinite ? max(offset, 0) : 0
        guard
            overlaySession.readingAnchor != normalizedAnchor
                || overlaySession.pixelOffset != normalizedOffset
        else { return }
        overlaySession.readingAnchor = normalizedAnchor
        overlaySession.pixelOffset = normalizedOffset
        snapshotRevision += 1
        effectHandler(.scheduleSnapshot(snapshot()))
    }

    private func acceptsDuringTermination(_ command: AppCommand) -> Bool {
        guard isTerminationQuiescing else { return true }
        switch command {
        case .completePreClearFlush, .pause, .hideOverlay, .flushPersistence,
            .topologyWillChange, .displayInventoryLoaded, .displayInventoryFailed,
            .keepScriptHidden, .completeShieldedMove, .readerResyncRequested,
            .scrollCheckpoint, .scrollTerminal, .scrollTerminalCapture,
            .scrollMutationCompleted, .teardownScrollSession:
            return true
        case .replaceScript, .applyScriptEdit, .setScriptTitle, .setFontSize,
            .setTextAlignment, .setActiveBandEnabled, .panelFrameChanged, .requestClear,
            .confirmClear, .cancelClear,
            .start, .togglePlayback, .restart, .setSpeed, .moveBackward, .moveForward,
            .showOverlay, .setLocked, .restore, .restoreFailed, .selectDisplay,
            .confirmSelectedDisplay, .readerAttachmentChanged, .readerScreenChanged,
            .readerBoundsWillChange, .readerBoundsChanged:
            return false
        }
    }

    private func invalidatePendingClearForDurableChange() {
        if pendingClear?.phase == .awaitingPreClearFlush {
            localError = .clearRequestInvalidated
        }
        pendingClear = nil
    }

    private func emit(_ effects: [AppEffect]) {
        for effect in effects {
            #if DEBUG
            diagnosticEvidenceRecorder?.record(
                kind: .effectEmitted,
                correlationID: diagnosticCorrelationID,
                payload: DiagnosticEventPayload(effect: effect.diagnosticName)
            )
            #endif
            effectHandler(effect)
        }
    }

    private static func applyDefault(
        _ effect: AppEffect,
        overlayController: OverlayPanelController
    ) {
        switch effect {
        case .stagePanelHidden(let display, let proposedFrame):
            overlayController.stageHidden(
                proposedFrame: proposedFrame
                    ?? overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame,
                fullFrame: display.frame,
                displayID: display.id
            )
        case .showPanel(let display, let proposedFrame):
            overlayController.show(
                proposedFrame: proposedFrame
                    ?? overlayController.defaultFrame(on: display.visibleFrame),
                on: display.visibleFrame,
                fullFrame: display.frame,
                displayID: display.id
            )
        case .hidePanel:
            overlayController.hide()
        case .setPanelLocked(let locked):
            overlayController.setLocked(locked)
        case .startScrollSession, .stopScrollSession, .updateScrollSpeed,
            .moveScrollSession, .readerAttachmentChanged, .readerScreenChanged,
            .restoreScrollLayout, .teardownScrollSession, .applyReaderEdit,
            .replaceReader, .updateReaderAttributes, .scheduleSnapshot,
            .flushSnapshot, .saveSnapshotImmediately, .flushPersistence,
            .moveControllerWhileShielded, .resetViewport, .reassessPrivacy,
            .queryTopology, .evaluatePrivacy:
            break
        }
    }

    // Explicit state setup seams used only to prove reducer invariants.
    func setReadingPositionForTesting(utf16Offset: Int, pixelOffset: Double) {
        overlaySession.readingAnchor = ReadingAnchor(
            utf16Offset: utf16Offset,
            document: document.text
        )
        overlaySession.pixelOffset = pixelOffset
    }

    func setCurrentSessionDisplayIdentityForTesting(_ id: UInt32, confirmed: Bool) {
        overlaySession.currentSessionDisplayID = id
        overlaySession.recoveryConfirmationState = confirmed ? .confirmed : .required
        isSelectionConfirmed = confirmed
    }
}

#if DEBUG
extension PrivacyDirective {
    fileprivate var diagnosticName: DiagnosticPrivacyDirectiveName {
        switch self {
        case .pauseScrolling: .pauseScrolling
        case .hideOverlay: .hideOverlay
        case .shieldController: .shieldController
        case .invalidatePendingShow: .invalidatePendingShow
        case .queryTopology: .queryTopology
        case .evaluatePrivacy: .evaluatePrivacy
        case .moveWindowsWhileShielded: .moveWindowsWhileShielded
        case .requestConfirmation: .requestConfirmation
        case .publishSafeState: .publishSafeState
        }
    }
}

extension AppEffect {
    var diagnosticName: DiagnosticEffectName {
        switch self {
        case .startScrollSession, .stopScrollSession, .updateScrollSpeed,
            .moveScrollSession, .readerAttachmentChanged, .readerScreenChanged,
            .restoreScrollLayout, .teardownScrollSession, .applyReaderEdit,
            .replaceReader, .updateReaderAttributes:
            .other
        case .stagePanelHidden: .stagePanelHidden
        case .showPanel: .showPanel
        case .hidePanel: .hidePanel
        case .setPanelLocked: .setPanelLocked
        case .moveControllerWhileShielded: .moveControllerWhileShielded
        case .scheduleSnapshot, .flushSnapshot, .saveSnapshotImmediately,
            .flushPersistence, .resetViewport, .reassessPrivacy,
            .queryTopology, .evaluatePrivacy:
            .other
        }
    }
}
#endif
