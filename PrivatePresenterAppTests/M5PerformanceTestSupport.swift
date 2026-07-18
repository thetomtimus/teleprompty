import AppKit
import CryptoKit
import Darwin
import Foundation
import TeleprompterCore

@testable import PrivatePresenter

enum M5FiftyThousandWordFixture {
    static let wordCount = 50_000
    static let byteCount = 499_999
    static let newlineCount = 2_499
    static let digest =
        "d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4"

    static func makeData(wordCount: Int, lineWidth: Int) throws -> Data {
        guard wordCount == Self.wordCount, lineWidth == 20 else {
            throw M5PerformanceHarnessError.fixtureArguments
        }
        var data = Data()
        data.reserveCapacity(byteCount)
        for index in 0..<wordCount {
            data.append(contentsOf: String(format: "word%05d", index).utf8)
            if index + 1 < wordCount {
                data.append((index + 1).isMultiple(of: lineWidth) ? 0x0A : 0x20)
            }
        }
        try verify(data)
        return data
    }

    static func verify(_ data: Data) throws {
        guard
            data.count == byteCount,
            data.last != 0x0A,
            data.filter({ $0 == 0x0A }).count == newlineCount,
            Data(data.prefix(9)) == Data("word00000".utf8),
            data.subdata(in: 250_000..<250_009) == Data("word25000".utf8),
            Data(data.suffix(9)) == Data("word49999".utf8),
            let text = String(data: data, encoding: .utf8),
            text.split(whereSeparator: { $0.isWhitespace }).count == wordCount,
            text.utf16.count == byteCount,
            sha256(data) == digest
        else {
            throw M5PerformanceHarnessError.fixtureDrift
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum M5PerformanceHarnessError: Error, CustomStringConvertible {
    case fixtureArguments
    case fixtureDrift
    case pristineSnapshotNotPrepared
    case pristineSnapshotLoadFailed
    case readerViewportUnavailable
    case syntheticEditRejected
    case persistenceFlushFailed
    case baselineRequiresRelease
    case baselineRequiresVisibleScreen
    case processFootprintUnavailable(kern_return_t)
    case invalidProcessFootprintSampleCount
    case sourceIdentityUnavailable

    var description: String {
        switch self {
        case .fixtureArguments:
            "The M5 fixture accepts only 50,000 words and 20 words per line."
        case .fixtureDrift:
            "The generated M5 fixture differs from its byte contract."
        case .pristineSnapshotNotPrepared:
            "The pristine M5 snapshot must be prepared before a load trial."
        case .pristineSnapshotLoadFailed:
            "The pristine M5 snapshot did not load through SnapshotStore."
        case .readerViewportUnavailable:
            "The real TextKit reader viewport was not constructed."
        case .syntheticEditRejected:
            "The synthetic edit did not traverse editor, model, and reader."
        case .persistenceFlushFailed:
            "The final synthetic revision did not flush."
        case .baselineRequiresRelease:
            "Absolute M5 timings require the Release test configuration."
        case .baselineRequiresVisibleScreen:
            "The actual display-link baseline requires a visible Mac screen."
        case .processFootprintUnavailable(let result):
            "The provisional processFootprintBytes diagnostic failed with \(result)."
        case .invalidProcessFootprintSampleCount:
            "The provisional process footprint diagnostic requires at least one sample."
        case .sourceIdentityUnavailable:
            "The exact Git source SHA could not be resolved for the external evidence gate."
        }
    }
}

@MainActor
final class M5PerformanceTestHarness: M5PerformanceHarnessing {
    let fixture: Data
    private let rootURL: URL
    private var pristineSnapshotBytes: Data?
    private var pristineSnapshotIdentity: String?

    private(set) var unrecordedWarmupCount = 0
    private(set) var recordedCleanLoadCount = 0
    private(set) var pristineResetCount = 0

    init(fixture: Data) throws {
        try M5FiftyThousandWordFixture.verify(fixture)
        self.fixture = fixture
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-m5-performance-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    func preparePristineSnapshot() async throws -> M5PristineSnapshotReceipt {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PRIVATE_PRESENTER_M5_BASELINE"] == "1" {
            throw M5PerformanceHarnessError.baselineRequiresRelease
        }
        #endif
        try? FileManager.default.removeItem(at: rootURL)
        let store = SnapshotStore(rootURL: rootURL)
        let snapshot = makeSnapshot(revision: 1, text: fixtureString)
        try await store.scheduleSave(snapshot)
        try await store.flush()
        let status = await store.status()
        guard status.persistedRevision == 1 else {
            throw M5PerformanceHarnessError.persistenceFlushFailed
        }

        let bytes = try Data(contentsOf: store.snapshotURL)
        pristineSnapshotBytes = bytes
        let identity = M5FiftyThousandWordFixture.sha256(bytes)
        pristineSnapshotIdentity = identity

        let verificationStore = SnapshotStore(rootURL: rootURL)
        guard case .loaded(let restored) = await verificationStore.load() else {
            throw M5PerformanceHarnessError.pristineSnapshotLoadFailed
        }
        let session = restored.overlaySession
        return M5PristineSnapshotReceipt(
            schemaVersion: restored.snapshot.schemaVersion,
            fixtureWordCount: fixtureString.split(whereSeparator: { $0.isWhitespace }).count,
            fixtureByteCount: fixture.count,
            fixtureUTF16Count: fixtureString.utf16.count,
            fixtureDigest: M5FiftyThousandWordFixture.sha256(fixture),
            isPaused: session.playbackPhase == .paused,
            isHidden: session.visibility == .hidden,
            runtimeDisplayWasCleared: session.currentSessionDisplayID == nil,
            requiresDisplayConfirmation: session.recoveryConfirmationState == .required,
            usedProductionSnapshotStoreImplementation: store.snapshotURL
                == rootURL.appendingPathComponent(SnapshotStore.snapshotFilename),
            seedAndFlushCount: status.persistedRevision == 1 ? 1 : 0,
            usedPasteOrImportPath: false,
            usedDebugUITestStoreOverride: false,
            evidenceScope: .inProcessSemanticOnly,
            usedDisposableBaselineAccount: false,
            normalApplicationSupportWasEmpty: false,
            sourceIdentity: try sourceIdentity(),
            snapshotIdentity: identity,
            executableIdentity: try executableIdentity()
        )
    }

    func resetToPristineSnapshot() async throws {
        guard let pristineSnapshotBytes else {
            throw M5PerformanceHarnessError.pristineSnapshotNotPrepared
        }
        try? FileManager.default.removeItem(at: rootURL)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try pristineSnapshotBytes.write(
            to: rootURL.appendingPathComponent(SnapshotStore.snapshotFilename),
            options: .atomic
        )
        pristineResetCount += 1
    }

    func runLoadTrial(measured: Bool) async throws -> M5LoadTrialResult {
        guard let snapshotIdentity = pristineSnapshotIdentity else {
            throw M5PerformanceHarnessError.pristineSnapshotNotPrepared
        }
        let recorder = M5HarnessSignposter()
        let store = SnapshotStore(rootURL: rootURL)
        let dependencies = DependencyContainer(
            proofLevel: .statusBar,
            performanceSignposter: recorder,
            snapshotStore: store
        )
        var endpointEvents: [M5LoadEndpointEvent] = []
        var loadStart: TimeInterval?
        let seams = AppRuntimeStartupSeams(
            observeAndQuery: { .failure(M5SyntheticTopologyError()) },
            registerDiagnosticHotKey: { 0 },
            presentsControllerAtStartup: false,
            record: { event in
                switch event {
                case .load:
                    loadStart = ProcessInfo.processInfo.systemUptime
                    endpointEvents.append(.snapshotLoadBegan)
                case .restore:
                    endpointEvents.append(.snapshotRestored)
                default:
                    break
                }
            }
        )
        let runtime = AppRuntime(
            proofLevel: .statusBar,
            dependencies: dependencies,
            hotKeyStartupMode: .legacyDiagnostic,
            restorePerformanceMode: .benchmark,
            startupSeams: seams
        )
        M5OffscreenReaderLayoutHost.prepare(runtime.overlayController)
        let layoutCountBeforeLoad = recorder.completedCount(for: .readerLayout)
        var editorHost: NSScrollView?
        var syntheticEditor: EditorTextSystem?
        var fixtureWasRestored = false
        var editorAttached = false
        var readerAttached = false
        var firstReaderLayoutCompleted = false
        var editAccepted = false
        var editReflected = false

        await runtime.startForTesting {
            fixtureWasRestored = runtime.model.document.text == self.fixtureString

            let editor = EditorTextSystem(
                text: runtime.model.document.text,
                revision: runtime.model.document.revision,
                performanceRegistry: dependencies.performanceRegistry,
                restorePerformanceGate: dependencies.restorePerformanceGate
            ) { edit in
                runtime.model.send(.applyScriptEdit(edit))
            }
            syntheticEditor = editor
            let scrollView = NSScrollView(
                frame: NSRect(x: 0, y: 0, width: 720, height: 300)
            )
            scrollView.documentView = editor.textView
            editorHost = scrollView
            editorAttached = scrollView.documentView === editor.textView
            if editorAttached { endpointEvents.append(.editorAttached) }

            if let viewport = runtime.overlayController.readerTextSystem.viewportAdapter {
                viewport.ensureLayout()
                readerAttached = viewport.attachmentView?.window != nil
                firstReaderLayoutCompleted = recorder.completedCount(for: .readerLayout)
                    > layoutCountBeforeLoad
            }
            if readerAttached { endpointEvents.append(.readerAttached) }
            if firstReaderLayoutCompleted {
                endpointEvents.append(.firstReaderLayoutCompleted)
            }

            let insertionOffset = editor.textStorage.length
            editor.replaceCharactersForTesting(
                in: NSRange(location: insertionOffset, length: 0),
                with: "x"
            )
            editAccepted = runtime.model.document.revision == 2
            editReflected = runtime.overlayController.readerTextSystem.textStorage.string
                == self.fixtureString + "x"
            if editAccepted { endpointEvents.append(.syntheticEditAccepted) }
            if editReflected {
                endpointEvents.append(.syntheticEditReflectedInReader)
            }
        }

        await dependencies.restorePerformanceGate.completeAfterMainActorSentinel()
        endpointEvents.append(.mainActorSentinelCompleted)
        for _ in 0..<4 where recorder.completedCount(for: .restoreToInteractive) == 0 {
            await Task.yield()
        }
        let restoreIntervalCompleted = recorder.completedCount(for: .restoreToInteractive) == 1
        endpointEvents.append(.measurementEnded)
        let end = ProcessInfo.processInfo.systemUptime
        let duration = end - (loadStart ?? end)
        let controllerInteractive = runtime.model.restorationCompleted
            && runtime.controllerWindowController.window != nil
        let syntheticEditCount = runtime.model.document.revision == 2 ? 1 : 0
        let didTerminate = await runtime.stopAndFlush()
        withExtendedLifetime(syntheticEditor) {
            editorHost?.documentView = nil
        }
        editorHost = nil
        syntheticEditor = nil

        if measured {
            recordedCleanLoadCount += 1
        } else {
            unrecordedWarmupCount += 1
        }
        return M5LoadTrialResult(
            duration: duration,
            wasMeasured: measured,
            endpointEvents: endpointEvents,
            fixtureRestored: fixtureWasRestored,
            editorAttached: editorAttached,
            readerAttached: readerAttached,
            firstReaderLayoutCompleted: firstReaderLayoutCompleted,
            syntheticEditAccepted: editAccepted,
            syntheticEditReflectedInReader: editReflected,
            mainActorSentinelCompleted: true,
            controllerInteractive: controllerInteractive,
            measurementEndedAfterSentinel: Array(endpointEvents.suffix(2))
                == [.mainActorSentinelCompleted, .measurementEnded],
            restoreIntervalCompletedBeforeMeasurementEnd: restoreIntervalCompleted,
            inProcessRuntimeStopped: didTerminate,
            syntheticEditCount: syntheticEditCount,
            openIntervalCount: dependencies.performanceRegistry.openIntervalCount,
            snapshotIdentity: snapshotIdentity,
            executableIdentity: try executableIdentity()
        )
    }

    func runEditSequence(
        actions: [M5EditAction],
        cadence: TimeInterval,
        measuresWallClock: Bool
    ) async throws -> M5EditRunResult {
        if measuresWallClock {
            #if DEBUG
            throw M5PerformanceHarnessError.baselineRequiresRelease
            #endif
        }
        let rig = try M5EditingRig(fixture: fixture)
        let initialRevision = rig.model.document.revision
        let initialIncremental = rig.overlay.readerTextSystem.incrementalMutationCount
        let initialFullReplacement = rig.overlay.readerTextSystem.fullReplacementCount
        let initialResync = rig.overlay.readerTextSystem.resyncRequestCount
        var restoredAfterEveryPair = true
        var actionStartTimes: [TimeInterval] = []
        actionStartTimes.reserveCapacity(actions.count)
        let clock = ContinuousClock()
        var nextDeadline = clock.now

        for (index, action) in actions.enumerated() {
            if measuresWallClock && index > 0 {
                nextDeadline += .milliseconds(Int64((cadence * 1_000).rounded()))
                try await clock.sleep(until: nextDeadline)
            }
            actionStartTimes.append(ProcessInfo.processInfo.systemUptime)
            try rig.apply(action)
            if index % 2 == 1 {
                restoredAfterEveryPair = restoredAfterEveryPair
                    && rig.model.document.text == fixtureString
                    && rig.overlay.readerTextSystem.textStorage.string == fixtureString
            }
        }
        guard await rig.adapter.flushForTermination() else {
            throw M5PerformanceHarnessError.persistenceFlushFailed
        }
        let finalData = Data(rig.model.document.text.utf8)
        let stallDurations = zip(actionStartTimes, actionStartTimes.dropFirst()).map { pair in
            max(0, pair.1 - pair.0 - cadence)
        }
        let editDurations = rig.recorder.durations(for: .editToVisible)
        let result = M5EditRunResult(
            actionCount: actions.count,
            acceptedEditCount: Int(rig.model.document.revision - initialRevision),
            editToVisibleIntervalCount: rig.recorder.completedCount(for: .editToVisible),
            incrementalReaderMutationCount:
                rig.overlay.readerTextSystem.incrementalMutationCount - initialIncremental,
            fullReplacementCountBefore: initialFullReplacement,
            fullReplacementCountAfter: rig.overlay.readerTextSystem.fullReplacementCount,
            resyncCount: rig.overlay.readerTextSystem.resyncRequestCount - initialResync,
            fixtureWasRestoredAfterEveryPair: restoredAfterEveryPair,
            finalFixture: finalData,
            scheduledCadence: cadence,
            editDurations: editDurations,
            mainThreadStallDurations: stallDurations,
            mainThreadStallProbeWasActive: measuresWallClock,
            reportedNearestRankP95: M5Statistics.nearestRankP95(editDurations.sorted()),
            openIntervalCount: rig.registry.openIntervalCount
        )
        rig.close()
        return result
    }

    func runDeterministicTickProbe() async throws -> M5TickProbeResult {
        let recorder = M5HarnessSignposter()
        let registry = PerformanceIntervalRegistry(signposter: recorder)
        let system = ReaderTextSystem(
            text: fixtureString,
            revision: 0,
            performanceRegistry: registry
        )
        let host = try M5ReaderHost(system: system, ordersWindowFront: false)
        let clockBox = M5ManualFrameClockBox()
        var events: [ScrollSessionEvent] = []
        var session: ScrollSessionController? = ScrollSessionController(
            viewport: host.viewport,
            clockFactory: { _, onTick in clockBox.make(onTick: onTick) },
            performanceRegistry: registry,
            onEvent: { events.append($0) }
        )
        weak let weakSession = session
        let generation = issuedScrollGeneration()
        let initialMutationCount = system.textMutationCount
        let initialReplacementCount = system.fullReplacementCount
        let start = ProcessInfo.processInfo.systemUptime
        _ = session?.start(
            binding: ScrollSessionBinding(
                generation: generation,
                anchor: ReadingAnchor(),
                offset: 0,
                speed: 60
            ),
            uptime: start
        )
        for index in 1...50 {
            clockBox.clock?.fire(at: start + Double(index) * 0.01)
        }
        session?.teardown(generation: generation)
        session = nil
        host.close()
        return M5TickProbeResult(
            tickCount: 50,
            tickIntervalCount: recorder.completedCount(for: .scrollTick),
            textMutationDelta: system.textMutationCount - initialMutationCount,
            persistenceEnqueueDelta: 0,
            attributedRebuildDelta: system.fullReplacementCount - initialReplacementCount,
            swiftUIPublishDelta: 0,
            subsecondCheckpointPublishDelta: events.count,
            openTickIntervalCount: registry.openIntervalCount,
            sessionLeaked: weakSession != nil
        )
    }

    func runSixMinuteScrollSession(
        warmupDuration: TimeInterval,
        measuredDuration: TimeInterval,
        totalSampleTimes: [TimeInterval]
    ) async throws -> M5ScrollMemoryResult {
        #if DEBUG
        throw M5PerformanceHarnessError.baselineRequiresRelease
        #else
        let recorder = M5HarnessSignposter()
        let registry = PerformanceIntervalRegistry(signposter: recorder)
        let system = ReaderTextSystem(
            text: fixtureString,
            revision: 0,
            performanceRegistry: registry
        )
        let host = try M5ReaderHost(system: system, ordersWindowFront: true)
        guard host.view.window?.screen != nil else {
            throw M5PerformanceHarnessError.baselineRequiresVisibleScreen
        }
        var session: ScrollSessionController? = ScrollSessionController(
            viewport: host.viewport,
            clockFactory: { view, onTick in
                DisplayLinkFrameClock.make(attachedTo: view, onTick: onTick)
            },
            performanceRegistry: registry,
            onEvent: { _ in }
        )
        weak let weakSession = session
        let generation = issuedScrollGeneration()
        let initialMutationCount = system.textMutationCount
        let initialReplacementCount = system.fullReplacementCount
        let start = ProcessInfo.processInfo.systemUptime
        _ = session?.start(
            binding: ScrollSessionBinding(
                generation: generation,
                anchor: ReadingAnchor(),
                offset: 0,
                speed: 1
            ),
            uptime: start
        )
        guard session?.isPlaying == true else {
            throw M5PerformanceHarnessError.baselineRequiresVisibleScreen
        }

        try await Task.sleep(for: .seconds(warmupDuration))
        let processFootprintBaselineTotalTime = ProcessInfo.processInfo.systemUptime - start
        let measuredTickStart = recorder.tickBeginTimes.count
        var processFootprintBytes: [UInt64] = []
        var previousTotal = warmupDuration
        for total in totalSampleTimes {
            try await Task.sleep(for: .seconds(total - previousTotal))
            processFootprintBytes.append(try M5ProcessFootprintSampler.sample())
            previousTotal = total
        }
        let totalDuration = ProcessInfo.processInfo.systemUptime - start
        let tickTimes = Array(recorder.tickBeginTimes.dropFirst(measuredTickStart))
        let stalls = zip(tickTimes, tickTimes.dropFirst()).map { pair in
            pair.1 - pair.0
        }
        let provisionalSlope = M5Statistics.ordinaryLeastSquaresSlope(
            x: [1, 2, 3, 4, 5],
            y: processFootprintBytes.map { Double($0) / 1_048_576 }
        )
        session?.teardown(generation: generation)
        session = nil
        host.close()
        return M5ScrollMemoryResult(
            totalDuration: totalDuration,
            warmupDuration: warmupDuration,
            measuredDuration: measuredDuration,
            totalSampleTimes: totalSampleTimes,
            measuredSampleTimes: totalSampleTimes.map { $0 - warmupDuration },
            processFootprintBytes: processFootprintBytes,
            provisionalProcessFootprintSlopeMiBPerMinute: provisionalSlope,
            mainThreadStallDurations: stalls,
            mainThreadStallProbeWasActive: true,
            sessionCount: 1,
            usedActualDisplayLink: true,
            processFootprintBaselineTotalTime: processFootprintBaselineTotalTime,
            tickCount: tickTimes.count,
            textMutationDelta: system.textMutationCount - initialMutationCount,
            persistenceEnqueueDelta: 0,
            attributedRebuildDelta: system.fullReplacementCount - initialReplacementCount,
            swiftUIPublishDelta: 0,
            openTickIntervalCount: registry.openIntervalCount,
            sessionLeaked: weakSession != nil
        )
        #endif
    }

    func runProcessFootprintSemanticProbe(
        sampleCount: Int
    ) async throws -> M5ProcessFootprintDiagnosticResult {
        guard sampleCount > 0 else {
            throw M5PerformanceHarnessError.invalidProcessFootprintSampleCount
        }
        var samples: [UInt64] = []
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            samples.append(try M5ProcessFootprintSampler.sample())
            await Task.yield()
        }
        return M5ProcessFootprintDiagnosticResult(processFootprintBytes: samples)
    }

    func runDelayedFilesystemEdit(
        delay: TimeInterval
    ) async throws -> M5DelayedFilesystemResult {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PRIVATE_PRESENTER_M5_BASELINE"] == "1" {
            throw M5PerformanceHarnessError.baselineRequiresRelease
        }
        #endif
        let delayedFileSystem = M5DelayedSnapshotFileSystem(delay: delay)
        let rig = try M5EditingRig(
            fixture: fixture,
            fileSystem: delayedFileSystem
        )
        let start = ProcessInfo.processInfo.systemUptime
        try rig.apply(.insertASCIIX(offset: 0))
        let editReturn = ProcessInfo.processInfo.systemUptime
        let filesystemHadCompletedAtEditReturn = delayedFileSystem.didComplete
        let readerReflected = rig.overlay.readerTextSystem.textStorage.string
            == "x" + fixtureString
        let flushTask = Task { @MainActor in
            await rig.adapter.flushForTermination()
        }
        await delayedFileSystem.waitUntilEntered()
        await Task.yield()
        let sentinelRanWhileDelayed = !delayedFileSystem.didComplete
        let flushCompleted = await flushTask.value
        let status = await rig.store.status()
        let editDurations = rig.recorder.durations(for: .editToVisible)
        let result = M5DelayedFilesystemResult(
            filesystemDelay: delayedFileSystem.delay,
            editReturnedBeforeFilesystemCompletion: !filesystemHadCompletedAtEditReturn,
            editAwaitedPersistence: filesystemHadCompletedAtEditReturn
                || editReturn - start >= delay,
            mainActorSentinelRanWhileFilesystemWasDelayed: sentinelRanWhileDelayed,
            readerReflectedEditBeforeFilesystemCompletion: readerReflected
                && !filesystemHadCompletedAtEditReturn,
            editToVisibleIntervalCount: rig.recorder.completedCount(for: .editToVisible),
            editToVisibleDuration: editDurations.first ?? .infinity,
            finalDocumentRevision: rig.model.document.revision,
            finalSnapshotRevision: rig.model.snapshotRevision,
            finalPersistedRevision: status.persistedRevision ?? 0,
            snapshotWriteCount: delayedFileSystem.atomicCommitCount,
            flushCompleted: flushCompleted,
            openIntervalCount: rig.registry.openIntervalCount
        )
        rig.close()
        return result
    }

    private var fixtureString: String {
        String(decoding: fixture, as: UTF8.self)
    }

    private func makeSnapshot(revision: UInt64, text: String) -> PersistedSnapshot {
        PersistedSnapshot(
            revision: revision,
            document: ScriptDocument(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                title: "Synthetic M5 Fixture",
                text: text,
                revision: revision,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_005)
            ),
            readingAnchor: ReadingAnchor(),
            preferences: TeleprompterPreferences()
        )
    }

    private func executableIdentity() throws -> String {
        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0])
        return M5FiftyThousandWordFixture.sha256(try Data(contentsOf: executableURL))
    }

    private func sourceIdentity() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let sha = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, sha.count == 40 else {
            throw M5PerformanceHarnessError.sourceIdentityUnavailable
        }
        return sha
    }

    private func issuedScrollGeneration() -> ScrollSessionGeneration {
        AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "Synthetic generation seed")
        ).currentScrollGeneration
    }

}

private struct M5SyntheticTopologyError: Error {}

@MainActor
private enum M5OffscreenReaderLayoutHost {
    static func prepare(_ overlay: OverlayPanelController) {
        guard let contentView = overlay.teleprompterPanel.contentViewController?.view else {
            return
        }
        contentView.frame = NSRect(x: 0, y: 0, width: 700, height: 350)
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
    }
}

@MainActor
private final class M5EditingRig {
    let rootURL: URL
    let store: SnapshotStore
    let recorder: M5HarnessSignposter
    let registry: PerformanceIntervalRegistry
    let overlay: OverlayPanelController
    let adapter: AppEffectAdapter
    let model: AppModel
    let controller: ControllerWindowController
    let editor: EditorTextSystem

    init(
        fixture: Data,
        fileSystem: any SnapshotFileSystem = LocalSnapshotFileSystem()
    ) throws {
        let resolvedRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-m5-edit-\(UUID().uuidString)",
            isDirectory: true
        )
        let resolvedStore = SnapshotStore(
            rootURL: resolvedRootURL,
            fileSystem: fileSystem
        )
        let resolvedRecorder = M5HarnessSignposter()
        let resolvedRegistry = PerformanceIntervalRegistry(signposter: resolvedRecorder)
        let resolvedOverlay = OverlayPanelController(performanceRegistry: resolvedRegistry)
        let resolvedAdapter = AppEffectAdapter(
            snapshotStore: resolvedStore,
            overlayController: resolvedOverlay,
            performanceSignposter: resolvedRecorder,
            performanceRegistry: resolvedRegistry
        )
        let text = String(decoding: fixture, as: UTF8.self)
        let resolvedModel = AppModel(
            overlayController: resolvedOverlay,
            document: ScriptDocument(text: text),
            restorationRequired: false,
            effectHandler: resolvedAdapter.handle
        )
        let resolvedController = ControllerWindowController(
            model: resolvedModel,
            performanceRegistry: resolvedRegistry
        )
        resolvedAdapter.connect(model: resolvedModel, controller: resolvedController)
        guard let viewport = resolvedOverlay.readerTextSystem.viewportAdapter else {
            throw M5PerformanceHarnessError.readerViewportUnavailable
        }
        viewport.ensureLayout()
        let resolvedEditor = EditorTextSystem(
            text: text,
            revision: resolvedModel.document.revision,
            performanceRegistry: resolvedRegistry,
            onEdit: { edit in resolvedModel.send(.applyScriptEdit(edit)) }
        )
        rootURL = resolvedRootURL
        store = resolvedStore
        recorder = resolvedRecorder
        registry = resolvedRegistry
        overlay = resolvedOverlay
        adapter = resolvedAdapter
        model = resolvedModel
        controller = resolvedController
        editor = resolvedEditor
    }

    func apply(_ action: M5EditAction) throws {
        let revision = model.document.revision
        switch action {
        case .insertASCIIX(let offset):
            editor.replaceCharactersForTesting(
                in: NSRange(location: offset, length: 0),
                with: "x"
            )
        case .deleteASCIIX(let offset):
            editor.replaceCharactersForTesting(
                in: NSRange(location: offset, length: 1),
                with: ""
            )
        }
        guard model.document.revision == revision + 1 else {
            throw M5PerformanceHarnessError.syntheticEditRejected
        }
    }

    func close() {
        controller.close()
        overlay.close()
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private final class M5HarnessSignposter: PerformanceSignposting, @unchecked Sendable {
    private struct Active {
        let operation: PerformanceSignpostOperation
        let start: TimeInterval
    }

    private let lock = NSLock()
    private var nextToken: UInt64 = 0
    private var active: [UInt64: Active] = [:]
    private var completedDurations: [PerformanceSignpostOperation: [TimeInterval]] = [:]
    private var recordedTickBeginTimes: [TimeInterval] = []
    let isEnabled = true

    func beginInterval(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceSignpostToken? {
        _ = reason
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        nextToken &+= 1
        active[nextToken] = Active(operation: operation, start: now)
        if operation == .scrollTick { recordedTickBeginTimes.append(now) }
        return PerformanceSignpostToken(rawValue: nextToken)
    }

    func endInterval(
        _ token: PerformanceSignpostToken,
        outcome: PerformanceSignpostOutcome
    ) {
        _ = outcome
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        guard let interval = active.removeValue(forKey: token.rawValue) else { return }
        completedDurations[interval.operation, default: []].append(now - interval.start)
    }

    func durations(for operation: PerformanceSignpostOperation) -> [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return completedDurations[operation] ?? []
    }

    func completedCount(for operation: PerformanceSignpostOperation) -> Int {
        durations(for: operation).count
    }

    var tickBeginTimes: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return recordedTickBeginTimes
    }
}

@MainActor
private final class M5ReaderHost {
    let view: ReaderViewportContainerView
    let window: NSWindow?
    let viewport: ReaderViewportAdapter

    init(system: ReaderTextSystem, ordersWindowFront: Bool) throws {
        let resolvedView = ReaderTextView.makeReaderView(system: system)
        resolvedView.frame = NSRect(x: 0, y: 0, width: 700, height: 350)
        let resolvedWindow: NSWindow?
        if ordersWindowFront {
            let window = NSWindow(
                contentRect: resolvedView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = resolvedView
            window.orderFront(nil)
            resolvedWindow = window
        } else {
            resolvedWindow = nil
        }
        resolvedView.needsLayout = true
        resolvedView.layoutSubtreeIfNeeded()
        let resolvedViewport = resolvedView.viewportAdapter!
        resolvedViewport.ensureLayout()
        view = resolvedView
        window = resolvedWindow
        viewport = resolvedViewport
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
    }
}

@MainActor
private final class M5ManualFrameClock: FrameClock {
    private var callback: (@MainActor (TimeInterval) -> Void)?

    init(callback: @escaping @MainActor (TimeInterval) -> Void) {
        self.callback = callback
    }

    func fire(at uptime: TimeInterval) {
        callback?(uptime)
    }

    func invalidate() {
        callback = nil
    }
}

@MainActor
private final class M5ManualFrameClockBox {
    private(set) var clock: M5ManualFrameClock?

    func make(
        onTick: @escaping @MainActor (TimeInterval) -> Void
    ) -> FrameClock {
        let clock = M5ManualFrameClock(callback: onTick)
        self.clock = clock
        return clock
    }
}

private final class M5DelayedSnapshotFileSystem: SnapshotFileSystem, @unchecked Sendable {
    let delay: TimeInterval
    private let base = LocalSnapshotFileSystem()
    private let lock = NSLock()
    private var entered = false
    private var completed = false
    private var commits = 0
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    init(delay: TimeInterval) {
        self.delay = delay
    }

    var didComplete: Bool { withLock { completed } }
    var atomicCommitCount: Int { withLock { commits } }

    func waitUntilEntered() async {
        if withLock({ entered }) { return }
        await withCheckedContinuation { continuation in
            if enqueueEnteredWaiter(continuation) {
                continuation.resume()
            }
        }
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func fileExists(at url: URL) -> Bool {
        base.fileExists(at: url)
    }

    func readFile(at url: URL) throws -> Data {
        try base.readFile(at: url)
    }

    func atomicCommit(
        _ data: Data,
        to destinationURL: URL,
        temporaryURL: URL
    ) throws {
        lock.lock()
        entered = true
        let waiters = enteredWaiters
        enteredWaiters.removeAll()
        lock.unlock()
        waiters.forEach { $0.resume() }
        Thread.sleep(forTimeInterval: delay)
        try base.atomicCommit(data, to: destinationURL, temporaryURL: temporaryURL)
        lock.lock()
        commits += 1
        completed = true
        lock.unlock()
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try base.moveItem(at: sourceURL, to: destinationURL)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func enqueueEnteredWaiter(
        _ continuation: CheckedContinuation<Void, Never>
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !entered else { return true }
        enteredWaiters.append(continuation)
        return false
    }
}

private enum M5ProcessFootprintSampler {
    static func sample() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            throw M5PerformanceHarnessError.processFootprintUnavailable(result)
        }
        return UInt64(info.phys_footprint)
    }
}

private enum M5Statistics {
    static func nearestRankP95(_ sortedSamples: [Double]) -> Double {
        precondition(!sortedSamples.isEmpty)
        let oneBasedRank = Int(ceil(0.95 * Double(sortedSamples.count)))
        return sortedSamples[oneBasedRank - 1]
    }

    static func ordinaryLeastSquaresSlope(x: [Double], y: [Double]) -> Double {
        precondition(x.count == y.count && !x.isEmpty)
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        let numerator = zip(x, y).reduce(0.0) { result, pair in
            result + (pair.0 - meanX) * (pair.1 - meanY)
        }
        let denominator = x.reduce(0.0) { result, value in
            result + (value - meanX) * (value - meanX)
        }
        return numerator / denominator
    }
}
