import Foundation
import TeleprompterCore
@testable import PrivatePresenter
import XCTest

@MainActor
final class SnapshotStoreTests: XCTestCase {
    func testProductionURLUsesSandboxApplicationSupportSubdirectory() throws {
        let applicationSupport = URL(fileURLWithPath: "/generated/application-support")
        let url = try SnapshotStore.productionSnapshotURL(
            applicationSupportDirectory: applicationSupport
        )

        XCTAssertEqual(
            url,
            applicationSupport
                .appendingPathComponent("Private Presenter", isDirectory: true)
                .appendingPathComponent("current-snapshot.json", isDirectory: false)
        )
    }

    func testSaveAtomicallyReplacesSnapshot() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)

        try await store.scheduleSave(makeSnapshot(revision: 1))
        try await store.flush()
        try await store.scheduleSave(makeSnapshot(revision: 2))
        try await store.flush()

        XCTAssertEqual(fileSystem.committedRevisions, [1, 2])
        XCTAssertEqual(
            fileSystem.commitOperationBatches.first,
            [.createTemporary, .write, .synchronizeFile, .close, .move, .synchronizeParent]
        )
        XCTAssertEqual(
            fileSystem.lastCommitOperations,
            [.createTemporary, .write, .synchronizeFile, .close, .replace, .synchronizeParent]
        )
        XCTAssertEqual(try decodedRevision(fileSystem.destinationData), 2)

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-store-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let integrationStore = SnapshotStore(rootURL: temporaryRoot)
        try await integrationStore.scheduleSave(makeSnapshot(revision: 11))
        try await integrationStore.flush()
        try await integrationStore.scheduleSave(makeSnapshot(revision: 12))
        try await integrationStore.flush()
        let integrationData = try Data(
            contentsOf: temporaryRoot.appendingPathComponent("current-snapshot.json")
        )
        XCTAssertEqual(try decodedRevision(integrationData), 12)
    }

    func testFailedReplacePreservesLastKnownGoodSnapshot() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)
        try await store.scheduleSave(makeSnapshot(revision: 1))
        try await store.flush()
        let knownGood = fileSystem.destinationData
        fileSystem.failure = .replace

        try await store.scheduleSave(makeSnapshot(revision: 2))
        await assertStoreError(.persistenceFailed) { try await store.flush() }

        XCTAssertEqual(fileSystem.destinationData, knownGood)
        XCTAssertEqual(try decodedRevision(fileSystem.destinationData), 1)
        XCTAssertEqual(fileSystem.temporaryFileCount, 0)

        for failure in [
            RecordingSnapshotFileSystem.Failure.createTemporary,
            .write,
            .synchronizeFile,
            .close,
            .replace,
        ] {
            let stepFileSystem = RecordingSnapshotFileSystem(destinationData: knownGood)
            stepFileSystem.failure = failure
            let stepStore = makeStore(fileSystem: stepFileSystem)
            _ = await stepStore.load()
            try await stepStore.scheduleSave(makeSnapshot(revision: 2))
            await assertStoreError(.persistenceFailed) { try await stepStore.flush() }
            XCTAssertEqual(stepFileSystem.destinationData, knownGood)
            XCTAssertEqual(stepFileSystem.temporaryFileCount, 0)
        }

        let firstSaveFileSystem = RecordingSnapshotFileSystem()
        firstSaveFileSystem.failure = .move
        let firstSaveStore = makeStore(fileSystem: firstSaveFileSystem)
        try await firstSaveStore.scheduleSave(makeSnapshot(revision: 1))
        await assertStoreError(.persistenceFailed) { try await firstSaveStore.flush() }
        XCTAssertNil(firstSaveFileSystem.destinationData)
        XCTAssertEqual(firstSaveFileSystem.temporaryFileCount, 0)

        let parentSyncFileSystem = RecordingSnapshotFileSystem(destinationData: knownGood)
        parentSyncFileSystem.failure = .synchronizeParent
        let parentSyncStore = makeStore(fileSystem: parentSyncFileSystem)
        _ = await parentSyncStore.load()
        try await parentSyncStore.scheduleSave(makeSnapshot(revision: 2))
        try await parentSyncStore.flush()
        let parentSyncStatus = await parentSyncStore.status()
        XCTAssertEqual(try decodedRevision(parentSyncFileSystem.destinationData), 2)
        XCTAssertEqual(parentSyncStatus.persistedRevision, 2)
        XCTAssertEqual(parentSyncFileSystem.parentSynchronizationFailureCount, 1)
    }

    func testDebounceCoalescesRapidEdits() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let sleeper = ControlledSnapshotSleeper()
        let store = makeStore(fileSystem: fileSystem, sleeper: sleeper)

        try await store.scheduleSave(makeSnapshot(revision: 1))
        try await store.scheduleSave(makeSnapshot(revision: 2))
        try await store.scheduleSave(makeSnapshot(revision: 3))
        await waitForWaiters(sleeper, count: 3)
        XCTAssertEqual(fileSystem.commitCount, 0)
        let requestedDelays = await sleeper.requestedDelays()
        XCTAssertEqual(
            requestedDelays,
            [.milliseconds(300), .milliseconds(300), .milliseconds(300)]
        )

        await sleeper.resumeAll()
        await waitForCommit(fileSystem, count: 1)

        XCTAssertEqual(fileSystem.committedRevisions, [3])
    }

    func testStaleRevisionCannotOverwriteNewerPendingSnapshot() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)
        try await store.scheduleSave(makeSnapshot(revision: 2))

        await assertStoreError(.staleRevision(found: 1, minimum: 2)) {
            try await store.scheduleSave(makeSnapshot(revision: 1))
        }
        try await store.flush()

        XCTAssertEqual(fileSystem.committedRevisions, [2])
    }

    func testEqualRevisionWithDifferentPayloadIsConflict() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)
        try await store.scheduleSave(makeSnapshot(revision: 7, text: "generated-one"))

        await assertStoreError(.revisionConflict(revision: 7)) {
            try await store.scheduleSave(makeSnapshot(revision: 7, text: "generated-two"))
        }
        try await store.flush()

        XCTAssertEqual(fileSystem.committedRevisions, [7])
    }

    func testFlushPersistsLatestRevision() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)

        try await store.scheduleSave(makeSnapshot(revision: 4))
        try await store.scheduleSave(makeSnapshot(revision: 5))
        try await store.flush()

        XCTAssertEqual(fileSystem.committedRevisions, [5])
        let status = await store.status()
        XCTAssertEqual(status.persistedRevision, 5)
        XCTAssertNil(status.pendingRevision)
    }

    func testFlushCancelsPendingDebounceWithoutDuplicateWrite() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let sleeper = ControlledSnapshotSleeper()
        let store = makeStore(fileSystem: fileSystem, sleeper: sleeper)
        try await store.scheduleSave(makeSnapshot(revision: 1))
        await waitForWaiters(sleeper, count: 1)

        try await store.flush()
        await sleeper.resumeAll()
        await drainTasks()

        XCTAssertEqual(fileSystem.committedRevisions, [1])
    }

    func testSaveArrivingAroundFlushCannotLetStaleWriteWin() async throws {
        let fileSystem = RecordingSnapshotFileSystem()
        let sleeper = ControlledSnapshotSleeper()
        let store = makeStore(fileSystem: fileSystem, sleeper: sleeper)
        try await store.scheduleSave(makeSnapshot(revision: 1))
        await waitForWaiters(sleeper, count: 1)

        let flushTask = Task { try await store.flush() }
        let saveTask = Task { try await store.scheduleSave(makeSnapshot(revision: 2)) }
        try await flushTask.value
        try await saveTask.value
        try await store.flush()
        await waitForWaiters(sleeper, count: 2)
        await sleeper.resumeAll()
        await drainTasks()

        XCTAssertEqual(fileSystem.committedRevisions.last, 2)
        if let newestIndex = fileSystem.committedRevisions.lastIndex(of: 2) {
            XCTAssertFalse(fileSystem.committedRevisions.suffix(from: newestIndex).contains(1))
        }
        XCTAssertEqual(try decodedRevision(fileSystem.destinationData), 2)
    }

    func testMalformedFileIsQuarantined() async throws {
        let fileSystem = RecordingSnapshotFileSystem(
            destinationData: Data("generated malformed".utf8)
        )
        let clock = FixedSnapshotClock(Date(timeIntervalSince1970: 1_783_879_260))
        let store = makeStore(fileSystem: fileSystem, clock: clock)

        let result = await store.load()

        guard case let .recoveredMalformed(quarantineURL) = result else {
            return XCTFail("Expected content-neutral malformed recovery")
        }
        XCTAssertEqual(
            quarantineURL.lastPathComponent,
            "current-snapshot.malformed-20260712T180100000Z.json"
        )
        XCTAssertFalse(fileSystem.destinationExists)
        XCTAssertEqual(fileSystem.data(at: quarantineURL), Data("generated malformed".utf8))
    }

    func testQuarantineFailurePreservesSourceAndBlocksWrites() async throws {
        let malformed = Data("generated malformed".utf8)
        let fileSystem = RecordingSnapshotFileSystem(destinationData: malformed)
        fileSystem.failure = .quarantineMove
        let store = makeStore(fileSystem: fileSystem)

        let loadResult = await store.load()
        XCTAssertEqual(loadResult, .recoveryFailed(.quarantineFailed))
        XCTAssertEqual(fileSystem.destinationData, malformed)
        await assertStoreError(.writesBlocked(.quarantineFailed)) {
            try await store.scheduleSave(makeSnapshot(revision: 1))
        }
        await assertStoreError(.writesBlocked(.quarantineFailed)) { try await store.flush() }
    }

    func testFutureSchemaIsPreservedInPlace() async throws {
        let future = futureSchemaData(version: 99)
        let fileSystem = RecordingSnapshotFileSystem(destinationData: future)
        let store = makeStore(fileSystem: fileSystem)

        let loadResult = await store.load()
        XCTAssertEqual(
            loadResult,
            .unsupportedFutureSchema(found: 99, supported: PersistedSnapshot.currentSchemaVersion)
        )
        XCTAssertEqual(fileSystem.destinationData, future)
        XCTAssertTrue(fileSystem.movedItems.isEmpty)
    }

    func testFutureSchemaBlocksSubsequentSaveAndFlushWithoutChangingBytes() async throws {
        let future = futureSchemaData(version: 2)
        let fileSystem = RecordingSnapshotFileSystem(destinationData: future)
        let store = makeStore(fileSystem: fileSystem)
        _ = await store.load()

        await assertStoreError(.writesBlocked(.unsupportedFutureSchema(found: 2, supported: 1))) {
            try await store.scheduleSave(makeSnapshot(revision: 10))
        }
        await assertStoreError(.writesBlocked(.unsupportedFutureSchema(found: 2, supported: 1))) {
            try await store.flush()
        }

        XCTAssertEqual(fileSystem.destinationData, future)
        XCTAssertEqual(fileSystem.commitCount, 0)
    }

    func testQuarantineCollisionDoesNotDeleteEvidence() async throws {
        let malformed = Data("new generated malformed".utf8)
        let existingEvidence = Data("existing generated evidence".utf8)
        let fileSystem = RecordingSnapshotFileSystem(destinationData: malformed)
        let clock = FixedSnapshotClock(Date(timeIntervalSince1970: 1_783_879_260))
        let collision = fileSystem.rootURL.appendingPathComponent(
            "current-snapshot.malformed-20260712T180100000Z.json"
        )
        fileSystem.seed(existingEvidence, at: collision)
        let store = makeStore(fileSystem: fileSystem, clock: clock)

        guard case let .recoveredMalformed(quarantineURL) = await store.load() else {
            return XCTFail("Expected malformed recovery")
        }

        XCTAssertEqual(fileSystem.data(at: collision), existingEvidence)
        XCTAssertEqual(
            quarantineURL.lastPathComponent,
            "current-snapshot.malformed-20260712T180100000Z-1.json"
        )
        XCTAssertEqual(fileSystem.data(at: quarantineURL), malformed)

        let racingFileSystem = RecordingSnapshotFileSystem(destinationData: malformed)
        racingFileSystem.failure = .quarantineCollisionRace
        let racingStore = makeStore(fileSystem: racingFileSystem, clock: clock)
        let racingResult = await racingStore.load()
        XCTAssertEqual(racingResult, .recoveryFailed(.quarantineFailed))
        XCTAssertEqual(racingFileSystem.destinationData, malformed)
        let racedEvidenceURL = racingFileSystem.rootURL.appendingPathComponent(
            "current-snapshot.malformed-20260712T180100000Z.json"
        )
        XCTAssertEqual(
            racingFileSystem.data(at: racedEvidenceURL),
            Data("generated collision evidence".utf8)
        )
        XCTAssertEqual(racingFileSystem.temporaryFileCount, 0)
        await assertStoreError(.writesBlocked(.quarantineFailed)) {
            try await racingStore.scheduleSave(makeSnapshot(revision: 1))
        }
    }

    func testFailedWriteRetainsPendingSnapshotAndPersistedRevision() async throws {
        let fileSystem = RecordingSnapshotFileSystem(
            destinationData: try makeSnapshot(revision: 1).canonicalData()
        )
        let sleeper = ControlledSnapshotSleeper()
        let store = makeStore(fileSystem: fileSystem, sleeper: sleeper)
        _ = await store.load()
        fileSystem.failure = .synchronizeFile
        try await store.scheduleSave(makeSnapshot(revision: 2))
        await waitForWaiters(sleeper, count: 1)

        await sleeper.resumeAll()
        await waitForDiagnostic(.saveFailed, store: store)
        var status = await store.status()
        XCTAssertEqual(status.persistedRevision, 1)
        XCTAssertEqual(status.pendingRevision, 2)
        XCTAssertEqual(try decodedRevision(fileSystem.destinationData), 1)
        XCTAssertEqual(fileSystem.temporaryFileCount, 0)

        fileSystem.failure = nil
        try await store.flush()
        status = await store.status()
        XCTAssertEqual(status.persistedRevision, 2)
    }

    func testVerifiedRecoveryAndSupportedLoadCannotOverwriteFutureBytes() async throws {
        let future = futureSchemaData(version: 8)
        let fileSystem = RecordingSnapshotFileSystem()
        let store = makeStore(fileSystem: fileSystem)
        try await store.scheduleSave(makeSnapshot(revision: 1))
        fileSystem.seed(future, at: fileSystem.destinationURL)

        let blockedResult = await store.recoverAfterExternalIntervention()
        XCTAssertEqual(
            blockedResult,
            .unsupportedFutureSchema(found: 8, supported: 1)
        )
        XCTAssertEqual(fileSystem.destinationData, future)
        var status = await store.status()
        XCTAssertNil(status.pendingRevision)

        fileSystem.remove(at: fileSystem.destinationURL)
        let missingResult = await store.recoverAfterExternalIntervention()
        XCTAssertEqual(missingResult, .notFound)
        status = await store.status()
        XCTAssertNil(status.writeBlockReason)

        let supportedData = try makeSnapshot(revision: 5).canonicalData()
        fileSystem.seed(future, at: fileSystem.destinationURL)
        _ = await store.load()
        fileSystem.seed(supportedData, at: fileSystem.destinationURL)
        guard case let .loaded(restored) = await store.recoverAfterExternalIntervention() else {
            return XCTFail("Expected supported recovery")
        }
        XCTAssertEqual(restored.snapshot.revision, 5)
        try await store.scheduleSave(makeSnapshot(revision: 5))
        status = await store.status()
        XCTAssertNil(status.pendingRevision)
        XCTAssertEqual(fileSystem.commitCount, 0)
    }

    func testScriptIsNeverWrittenToUserDefaults() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Services/SnapshotStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let forbiddenAPI = ["User", "Defaults"].joined()

        XCTAssertFalse(source.contains(forbiddenAPI))
    }

    func testDiagnosticsAndErrorsDoNotContainScriptContent() async throws {
        let privateFixture = "generated-sensitive-\(UUID().uuidString)"
        let fileSystem = RecordingSnapshotFileSystem()
        fileSystem.failure = .write
        let store = makeStore(fileSystem: fileSystem)
        try await store.scheduleSave(makeSnapshot(revision: 1, text: privateFixture))

        do {
            try await store.flush()
            XCTFail("Expected content-neutral persistence failure")
        } catch {
            XCTAssertFalse(String(describing: error).contains(privateFixture))
        }

        let diagnostics = await store.diagnostics()
        XCTAssertFalse(diagnostics.map(\.description).joined().contains(privateFixture))
    }
}

private extension SnapshotStoreTests {
    func makeStore(
        fileSystem: RecordingSnapshotFileSystem,
        clock: any SnapshotClock = FixedSnapshotClock(Date(timeIntervalSince1970: 0)),
        sleeper: any SnapshotSleeper = InertSnapshotSleeper()
    ) -> SnapshotStore {
        SnapshotStore(
            rootURL: fileSystem.rootURL,
            fileSystem: fileSystem,
            clock: clock,
            sleeper: sleeper
        )
    }

    func makeSnapshot(revision: UInt64, text: String = "generated fixture") -> PersistedSnapshot {
        PersistedSnapshot(
            revision: revision,
            document: ScriptDocument(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                text: text,
                revision: revision,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            readingAnchor: ReadingAnchor(),
            preferences: TeleprompterPreferences()
        )
    }

    func futureSchemaData(version: Int) -> Data {
        Data("{\"schemaVersion\":\(version)}".utf8)
    }

    func decodedRevision(_ data: Data?) throws -> UInt64? {
        guard let data else { return nil }
        return try PersistedSnapshot.canonicalDecoder()
            .decode(PersistedSnapshot.self, from: data).revision
    }

    func assertStoreError(
        _ expected: SnapshotStoreError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as SnapshotStoreError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected content-neutral error type: \(type(of: error))")
        }
    }

    func waitForWaiters(_ sleeper: ControlledSnapshotSleeper, count: Int) async {
        for _ in 0..<100 {
            if await sleeper.waiterCount() >= count { break }
            await Task.yield()
        }
        let waiterCount = await sleeper.waiterCount()
        XCTAssertEqual(waiterCount, count)
    }

    func waitForCommit(_ fileSystem: RecordingSnapshotFileSystem, count: Int) async {
        for _ in 0..<100 {
            if fileSystem.commitCount >= count { break }
            await Task.yield()
        }
        XCTAssertEqual(fileSystem.commitCount, count)
    }

    func waitForDiagnostic(_ code: SnapshotDiagnostic.Code, store: SnapshotStore) async {
        for _ in 0..<100 {
            let diagnostics = await store.diagnostics()
            if diagnostics.contains(where: { $0.code == code }) { return }
            await Task.yield()
        }
        XCTFail("Expected content-neutral diagnostic code \(code.rawValue)")
    }

    func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }
}

private actor ControlledSnapshotSleeper: SnapshotSleeper {
    private var delays: [Duration] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        delays.append(duration)
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func requestedDelays() -> [Duration] { delays }
    func waiterCount() -> Int { waiters.count }

    func resumeAll() {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

private struct InertSnapshotSleeper: SnapshotSleeper {
    func sleep(for duration: Duration) async throws {
        throw CancellationError()
    }
}

private struct FixedSnapshotClock: SnapshotClock {
    let date: Date

    init(_ date: Date) {
        self.date = date
    }

    func now() -> Date { date }
}

private enum RecordedCommitOperation: String, Equatable, Sendable {
    case createTemporary
    case write
    case synchronizeFile
    case close
    case move
    case replace
    case synchronizeParent
}

private final class RecordingSnapshotFileSystem: SnapshotFileSystem, @unchecked Sendable {
    enum Failure: String {
        case createTemporary
        case write
        case synchronizeFile
        case close
        case move
        case replace
        case synchronizeParent
        case quarantineMove
        case quarantineCollisionRace
    }

    let rootURL = URL(fileURLWithPath: "/generated/\(UUID().uuidString)", isDirectory: true)
    var destinationURL: URL { rootURL.appendingPathComponent("current-snapshot.json") }
    private let lock = NSLock()
    private var files: [URL: Data] = [:]
    private var operationBatches: [[RecordedCommitOperation]] = []
    private var revisions: [UInt64] = []
    private var moves: [(URL, URL)] = []
    private var parentSyncFailures = 0
    private var configuredFailure: Failure?

    init(destinationData: Data? = nil) {
        if let destinationData {
            files[destinationURL] = destinationData
        }
    }

    var failure: Failure? {
        get { withLock { configuredFailure } }
        set { withLock { configuredFailure = newValue } }
    }

    var destinationData: Data? {
        withLock { files[destinationURL] }
    }

    var destinationExists: Bool { destinationData != nil }
    var commitCount: Int { withLock { revisions.count } }
    var committedRevisions: [UInt64] { withLock { revisions } }
    var commitOperationBatches: [[RecordedCommitOperation]] { withLock { operationBatches } }
    var lastCommitOperations: [RecordedCommitOperation] { withLock { operationBatches.last ?? [] } }
    var movedItems: [(URL, URL)] { withLock { moves } }
    var parentSynchronizationFailureCount: Int { withLock { parentSyncFailures } }
    var temporaryFileCount: Int {
        withLock {
            files.keys.filter { $0.lastPathComponent.hasPrefix("current-snapshot.tmp-") }.count
        }
    }

    func seed(_ data: Data, at url: URL) { withLock { files[url] = data } }
    func remove(at url: URL) { withLock { files[url] = nil } }
    func data(at url: URL) -> Data? { withLock { files[url] } }

    func createDirectory(at url: URL) throws {}

    func fileExists(at url: URL) -> Bool {
        withLock { files[url] != nil }
    }

    func readFile(at url: URL) throws -> Data {
        try withLock {
            guard let data = files[url] else { throw CocoaError(.fileReadNoSuchFile) }
            return data
        }
    }

    func atomicCommit(_ data: Data, to destinationURL: URL, temporaryURL: URL) throws {
        try withLock {
            var operations: [RecordedCommitOperation] = []
            let existed = files[destinationURL] != nil

            func perform(_ operation: RecordedCommitOperation) throws {
                operations.append(operation)
                if configuredFailure?.rawValue == operation.rawValue {
                    throw CocoaError(.fileWriteUnknown)
                }
            }

            do {
                try perform(.createTemporary)
                files[temporaryURL] = Data()
                try perform(.write)
                files[temporaryURL] = data
                try perform(.synchronizeFile)
                try perform(.close)
                try perform(existed ? .replace : .move)
                files[destinationURL] = files[temporaryURL]
                files[temporaryURL] = nil

                operations.append(.synchronizeParent)
                if configuredFailure == .synchronizeParent {
                    parentSyncFailures += 1
                }
                // Parent synchronization is deliberately best-effort after
                // the atomic commit, matching the production adapter.
                operationBatches.append(operations)
                let snapshot = try PersistedSnapshot.canonicalDecoder()
                    .decode(PersistedSnapshot.self, from: data)
                revisions.append(snapshot.revision)
            } catch {
                files[temporaryURL] = nil
                operationBatches.append(operations)
                throw error
            }
        }
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try withLock {
            if configuredFailure == .quarantineMove { throw CocoaError(.fileWriteUnknown) }
            if configuredFailure == .quarantineCollisionRace {
                files[destinationURL] = Data("generated collision evidence".utf8)
                throw CocoaError(.fileWriteFileExists)
            }
            guard files[destinationURL] == nil, let data = files[sourceURL] else {
                throw CocoaError(.fileWriteFileExists)
            }
            files[destinationURL] = data
            files[sourceURL] = nil
            moves.append((sourceURL, destinationURL))
        }
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
