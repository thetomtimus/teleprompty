import Foundation
import TeleprompterCore

enum SnapshotWriteBlockReason: Equatable, Sendable {
    case unsupportedFutureSchema(found: Int, supported: Int)
    case quarantineFailed
}

enum SnapshotStoreError: Error, Equatable, Sendable {
    case staleRevision(found: UInt64, minimum: UInt64)
    case revisionConflict(revision: UInt64)
    case writesBlocked(SnapshotWriteBlockReason)
    case encodingFailed
    case persistenceFailed
}

extension SnapshotStoreError: CustomStringConvertible {
    var description: String {
        switch self {
        case .staleRevision(let found, let minimum):
            return "Snapshot revision \(found) is older than accepted revision \(minimum)."
        case .revisionConflict(let revision):
            return "Snapshot revision \(revision) conflicts with the accepted payload."
        case .writesBlocked(let reason):
            switch reason {
            case .unsupportedFutureSchema(let found, let supported):
                return "Snapshot writes are blocked for schema \(found); supported schema is "
                    + "\(supported)."
            case .quarantineFailed:
                return "Snapshot writes are blocked until local recovery succeeds."
            }
        case .encodingFailed:
            return "Snapshot encoding failed."
        case .persistenceFailed:
            return "Snapshot persistence failed."
        }
    }
}

extension SnapshotStoreError: LocalizedError {
    var errorDescription: String? { description }
}

enum SnapshotRecoveryError: Error, Equatable, Sendable {
    case readFailed
    case quarantineFailed
}

enum SnapshotLoadResult: Equatable, Sendable {
    case notFound
    case loaded(RestoredState)
    case recoveredMalformed(quarantineURL: URL)
    case unsupportedFutureSchema(found: Int, supported: Int)
    case recoveryFailed(SnapshotRecoveryError)
}

struct SnapshotStoreStatus: Equatable, Sendable {
    let persistedRevision: UInt64?
    let pendingRevision: UInt64?
    let writeBlockReason: SnapshotWriteBlockReason?
}

struct SnapshotDiagnostic: Equatable, Sendable, CustomStringConvertible {
    enum Code: String, Equatable, Sendable {
        case loadNotFound
        case loadSucceeded
        case readFailed
        case saveScheduled
        case saveSucceeded
        case saveFailed
        case staleRevisionRejected
        case revisionConflict
        case malformedQuarantined
        case quarantineFailed
        case futureSchemaBlocked
        case pendingDiscarded
        case writeBlockCleared
    }

    let code: Code
    let url: URL?
    let revision: UInt64?

    var description: String {
        let path = url?.path ?? "none"
        let revisionText = revision.map(String.init) ?? "none"
        return "code=\(code.rawValue) url=\(path) revision=\(revisionText)"
    }
}

actor SnapshotStore {
    static let debounceDuration: Duration = .milliseconds(300)
    static let directoryName = "Private Presenter"
    static let snapshotFilename = "current-snapshot.json"

    nonisolated let rootURL: URL
    nonisolated let snapshotURL: URL

    private let fileSystem: any SnapshotFileSystem
    private let clock: any SnapshotClock
    private let sleeper: any SnapshotSleeper
    private let migrator: SnapshotMigrator

    private var pendingSnapshot: PersistedSnapshot?
    private var pendingCanonicalData: Data?
    private var persistedRevision: UInt64?
    private var persistedCanonicalData: Data?
    private var debounceGeneration: UInt64 = 0
    private var debounceTask: Task<Void, Never>?
    private var writeBlockReason: SnapshotWriteBlockReason?
    private var diagnosticRecords: [SnapshotDiagnostic] = []

    init(
        rootURL: URL,
        fileSystem: any SnapshotFileSystem = LocalSnapshotFileSystem(),
        clock: any SnapshotClock = SystemSnapshotClock(),
        sleeper: any SnapshotSleeper = ContinuousSnapshotSleeper(),
        migrator: SnapshotMigrator = SnapshotMigrator()
    ) {
        self.rootURL = rootURL
        snapshotURL = rootURL.appendingPathComponent(Self.snapshotFilename, isDirectory: false)
        self.fileSystem = fileSystem
        self.clock = clock
        self.sleeper = sleeper
        self.migrator = migrator
    }

    static func productionSnapshotURL(
        applicationSupportDirectory: URL? = nil
    ) throws -> URL {
        let applicationSupport: URL
        if let applicationSupportDirectory {
            applicationSupport = applicationSupportDirectory
        } else {
            applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        }

        return
            applicationSupport
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(snapshotFilename, isDirectory: false)
    }

    static func production(
        fileSystem: any SnapshotFileSystem = LocalSnapshotFileSystem(),
        clock: any SnapshotClock = SystemSnapshotClock(),
        sleeper: any SnapshotSleeper = ContinuousSnapshotSleeper()
    ) throws -> SnapshotStore {
        let url = try productionSnapshotURL()
        return SnapshotStore(
            rootURL: url.deletingLastPathComponent(),
            fileSystem: fileSystem,
            clock: clock,
            sleeper: sleeper
        )
    }

    func load() async -> SnapshotLoadResult {
        performLoad(clearWriteBlockWhenMissing: false)
    }

    /// Re-evaluates the on-disk source after external recovery. The write latch
    /// clears only after a supported load, successful quarantine, or verified
    /// absence; future bytes are never replaced by this operation.
    func recoverAfterExternalIntervention() async -> SnapshotLoadResult {
        resetPendingState()
        return performLoad(clearWriteBlockWhenMissing: true)
    }

    private func performLoad(clearWriteBlockWhenMissing: Bool) -> SnapshotLoadResult {
        supersedeDebounce()

        do {
            try fileSystem.createDirectory(at: rootURL)
        } catch {
            record(.readFailed, url: snapshotURL)
            return .recoveryFailed(.readFailed)
        }

        guard fileSystem.fileExists(at: snapshotURL) else {
            if clearWriteBlockWhenMissing {
                persistedRevision = nil
                persistedCanonicalData = nil
                writeBlockReason = nil
                record(.writeBlockCleared, url: snapshotURL)
            }
            record(.loadNotFound, url: snapshotURL)
            return .notFound
        }

        let data: Data
        do {
            data = try fileSystem.readFile(at: snapshotURL)
        } catch {
            record(.readFailed, url: snapshotURL)
            return .recoveryFailed(.readFailed)
        }

        do {
            let snapshot = try migrator.migrate(data)
            let canonicalData = try snapshot.canonicalData()
            pendingSnapshot = nil
            pendingCanonicalData = nil
            persistedRevision = snapshot.revision
            persistedCanonicalData = canonicalData
            writeBlockReason = nil
            record(.loadSucceeded, url: snapshotURL, revision: snapshot.revision)
            return .loaded(RestoredState(snapshot: snapshot))
        } catch let error as SnapshotMigrationError {
            switch error {
            case .unsupportedFutureSchema(let found, let supported):
                resetPendingState()
                let reason = SnapshotWriteBlockReason.unsupportedFutureSchema(
                    found: found,
                    supported: supported
                )
                writeBlockReason = reason
                record(.futureSchemaBlocked, url: snapshotURL)
                return .unsupportedFutureSchema(found: found, supported: supported)
            case .unsupportedLegacySchema, .malformed:
                return quarantineMalformedSource()
            }
        } catch {
            return quarantineMalformedSource()
        }
    }

    func scheduleSave(_ snapshot: PersistedSnapshot) async throws {
        if let writeBlockReason {
            throw SnapshotStoreError.writesBlocked(writeBlockReason)
        }

        let canonicalData: Data
        do {
            canonicalData = try snapshot.canonicalData()
        } catch {
            throw SnapshotStoreError.encodingFailed
        }

        if let pendingSnapshot, let pendingCanonicalData {
            switch snapshot.revision {
            case ..<pendingSnapshot.revision:
                record(.staleRevisionRejected, revision: snapshot.revision)
                throw SnapshotStoreError.staleRevision(
                    found: snapshot.revision,
                    minimum: pendingSnapshot.revision
                )
            case pendingSnapshot.revision:
                guard canonicalData != pendingCanonicalData else { return }
                record(.revisionConflict, revision: snapshot.revision)
                throw SnapshotStoreError.revisionConflict(revision: snapshot.revision)
            default:
                break
            }
        } else if let persistedRevision, let persistedCanonicalData {
            switch snapshot.revision {
            case ..<persistedRevision:
                record(.staleRevisionRejected, revision: snapshot.revision)
                throw SnapshotStoreError.staleRevision(
                    found: snapshot.revision,
                    minimum: persistedRevision
                )
            case persistedRevision:
                guard canonicalData != persistedCanonicalData else { return }
                record(.revisionConflict, revision: snapshot.revision)
                throw SnapshotStoreError.revisionConflict(revision: snapshot.revision)
            default:
                break
            }
        }

        pendingSnapshot = snapshot
        pendingCanonicalData = canonicalData
        debounceGeneration &+= 1
        let generation = debounceGeneration
        let revision = snapshot.revision
        debounceTask?.cancel()

        let sleeper = self.sleeper
        debounceTask = Task { [weak self, sleeper] in
            do {
                try await sleeper.sleep(for: Self.debounceDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.debounceElapsed(generation: generation, revision: revision)
        }
        record(.saveScheduled, revision: revision)
    }

    func flush() async throws {
        if let writeBlockReason {
            throw SnapshotStoreError.writesBlocked(writeBlockReason)
        }

        supersedeDebounce()
        try commitPendingSnapshot()
    }

    func discardPendingSave() async {
        supersedeDebounce()
        pendingSnapshot = nil
        pendingCanonicalData = nil
        record(.pendingDiscarded)
    }

    func diagnostics() -> [SnapshotDiagnostic] {
        diagnosticRecords
    }

    func status() -> SnapshotStoreStatus {
        SnapshotStoreStatus(
            persistedRevision: persistedRevision,
            pendingRevision: pendingSnapshot?.revision,
            writeBlockReason: writeBlockReason
        )
    }

    private func debounceElapsed(generation: UInt64, revision: UInt64) {
        guard
            generation == debounceGeneration,
            pendingSnapshot?.revision == revision,
            writeBlockReason == nil
        else {
            return
        }

        debounceTask = nil
        do {
            try commitPendingSnapshot()
        } catch {
            // The pending snapshot remains available for an explicit retry.
        }
    }

    private func commitPendingSnapshot() throws {
        guard let snapshot = pendingSnapshot, let data = pendingCanonicalData else { return }

        do {
            try fileSystem.createDirectory(at: rootURL)
            let temporaryURL = rootURL.appendingPathComponent(
                "current-snapshot.tmp-\(UUID().uuidString.lowercased()).json",
                isDirectory: false
            )
            try fileSystem.atomicCommit(data, to: snapshotURL, temporaryURL: temporaryURL)
        } catch {
            record(.saveFailed, url: snapshotURL, revision: snapshot.revision)
            throw SnapshotStoreError.persistenceFailed
        }

        persistedRevision = snapshot.revision
        persistedCanonicalData = data
        pendingSnapshot = nil
        pendingCanonicalData = nil
        record(.saveSucceeded, url: snapshotURL, revision: snapshot.revision)
    }

    private func quarantineMalformedSource() -> SnapshotLoadResult {
        let quarantineURL = nextQuarantineURL()
        do {
            try fileSystem.moveItem(at: snapshotURL, to: quarantineURL)
        } catch {
            resetPendingState()
            writeBlockReason = .quarantineFailed
            record(.quarantineFailed, url: snapshotURL)
            return .recoveryFailed(.quarantineFailed)
        }

        pendingSnapshot = nil
        pendingCanonicalData = nil
        persistedRevision = nil
        persistedCanonicalData = nil
        writeBlockReason = nil
        record(.malformedQuarantined, url: quarantineURL)
        return .recoveredMalformed(quarantineURL: quarantineURL)
    }

    private func nextQuarantineURL() -> URL {
        let timestamp = Self.quarantineTimestamp(clock.now())
        let stem = "current-snapshot.malformed-\(timestamp)"
        var candidate = rootURL.appendingPathComponent("\(stem).json", isDirectory: false)
        var collision = 0
        while fileSystem.fileExists(at: candidate) {
            collision += 1
            candidate = rootURL.appendingPathComponent(
                "\(stem)-\(collision).json",
                isDirectory: false
            )
        }
        return candidate
    }

    private static func quarantineTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmssSSS'Z'"
        return formatter.string(from: date)
    }

    private func supersedeDebounce() {
        debounceGeneration &+= 1
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func resetPendingState() {
        supersedeDebounce()
        pendingSnapshot = nil
        pendingCanonicalData = nil
    }

    private func record(
        _ code: SnapshotDiagnostic.Code,
        url: URL? = nil,
        revision: UInt64? = nil
    ) {
        diagnosticRecords.append(SnapshotDiagnostic(code: code, url: url, revision: revision))
    }
}
