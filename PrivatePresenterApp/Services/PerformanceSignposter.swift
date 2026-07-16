import Foundation
import os
import TeleprompterCore

final class PerformanceSignposter: PerformanceSignposting, @unchecked Sendable {
    static let subsystem = "com.privatepresenter.teleprompter"

    private struct ActiveInterval {
        let operation: PerformanceSignpostOperation
        let state: OSSignpostIntervalState
    }

    private let lock = NSLock()
    private let load = OSSignposter(subsystem: subsystem, category: "load")
    private let layout = OSSignposter(subsystem: subsystem, category: "layout")
    private let edit = OSSignposter(subsystem: subsystem, category: "edit")
    private let scroll = OSSignposter(subsystem: subsystem, category: "scroll")
    private let persistence = OSSignposter(subsystem: subsystem, category: "persistence")
    private var nextTokenRawValue: UInt64 = 0
    private var active: [UInt64: ActiveInterval] = [:]

    var isEnabled: Bool {
        load.isEnabled || layout.isEnabled || edit.isEnabled
            || scroll.isEnabled || persistence.isEnabled
    }

    func beginInterval(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceSignpostToken? {
        guard isEnabled else { return nil }
        _ = reason
        lock.lock()
        defer { lock.unlock() }
        let (next, overflow) = nextTokenRawValue.addingReportingOverflow(1)
        precondition(!overflow, "Performance signpost token exhausted")
        nextTokenRawValue = next
        let state = begin(operation)
        active[next] = ActiveInterval(operation: operation, state: state)
        return PerformanceSignpostToken(rawValue: next)
    }

    func endInterval(
        _ token: PerformanceSignpostToken,
        outcome: PerformanceSignpostOutcome
    ) {
        _ = outcome
        lock.lock()
        guard let interval = active.removeValue(forKey: token.rawValue) else {
            lock.unlock()
            return
        }
        end(interval.operation, state: interval.state)
        lock.unlock()
    }

    private func begin(_ operation: PerformanceSignpostOperation) -> OSSignpostIntervalState {
        switch operation {
        case .restoreToInteractive:
            load.beginInterval("restore-to-interactive", id: load.makeSignpostID())
        case .readerLayout:
            layout.beginInterval("reader-layout", id: layout.makeSignpostID())
        case .editToVisible:
            edit.beginInterval("edit-to-visible", id: edit.makeSignpostID())
        case .scrollSession:
            scroll.beginInterval("scroll-session", id: scroll.makeSignpostID())
        case .scrollTick:
            scroll.beginInterval("scroll-tick", id: scroll.makeSignpostID())
        case .snapshotEncode:
            persistence.beginInterval("snapshot-encode", id: persistence.makeSignpostID())
        case .snapshotWrite:
            persistence.beginInterval("snapshot-write", id: persistence.makeSignpostID())
        case .snapshotFlush:
            persistence.beginInterval("snapshot-flush", id: persistence.makeSignpostID())
        }
    }

    private func end(
        _ operation: PerformanceSignpostOperation,
        state: OSSignpostIntervalState
    ) {
        switch operation {
        case .restoreToInteractive:
            load.endInterval("restore-to-interactive", state)
        case .readerLayout:
            layout.endInterval("reader-layout", state)
        case .editToVisible:
            edit.endInterval("edit-to-visible", state)
        case .scrollSession:
            scroll.endInterval("scroll-session", state)
        case .scrollTick:
            scroll.endInterval("scroll-tick", state)
        case .snapshotEncode:
            persistence.endInterval("snapshot-encode", state)
        case .snapshotWrite:
            persistence.endInterval("snapshot-write", state)
        case .snapshotFlush:
            persistence.endInterval("snapshot-flush", state)
        }
    }
}

struct PerformanceIntervalHandle: Hashable, Sendable {
    fileprivate let rawValue: UInt64
}

final class PerformanceIntervalRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private let signposter: any PerformanceSignposting
    private var nextHandleRawValue: UInt64 = 0
    private var active: [PerformanceIntervalHandle: PerformanceSignpostToken] = [:]
    private var editIntervalsByRevision: [UInt64: PerformanceIntervalHandle] = [:]
    private var acceptsNewIntervals = true

    init(signposter: any PerformanceSignposting) {
        self.signposter = signposter
    }

    var isEnabled: Bool { signposter.isEnabled }

    var openIntervalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return active.count
    }

    @discardableResult
    func begin(
        _ operation: PerformanceSignpostOperation,
        reason: PerformanceSignpostReason?
    ) -> PerformanceIntervalHandle? {
        lock.lock()
        guard acceptsNewIntervals else {
            lock.unlock()
            return nil
        }
        guard let token = signposter.beginInterval(operation, reason: reason) else {
            lock.unlock()
            return nil
        }
        defer { lock.unlock() }
        let (next, overflow) = nextHandleRawValue.addingReportingOverflow(1)
        precondition(!overflow, "Performance interval handle exhausted")
        nextHandleRawValue = next
        let handle = PerformanceIntervalHandle(rawValue: next)
        active[handle] = token
        return handle
    }

    func end(
        _ handle: PerformanceIntervalHandle?,
        outcome: PerformanceSignpostOutcome
    ) {
        guard let handle else { return }
        lock.lock()
        let token = active.removeValue(forKey: handle)
        editIntervalsByRevision = editIntervalsByRevision.filter { $0.value != handle }
        lock.unlock()
        guard let token else { return }
        signposter.endInterval(token, outcome: outcome)
    }

    func beginEditToVisible(for revision: UInt64) {
        guard let handle = begin(.editToVisible, reason: nil) else { return }
        lock.lock()
        let superseded: PerformanceIntervalHandle?
        if active[handle] != nil {
            superseded = editIntervalsByRevision.updateValue(handle, forKey: revision)
        } else {
            superseded = nil
        }
        lock.unlock()
        if let superseded, superseded != handle {
            end(superseded, outcome: .cancelled)
        }
    }

    func endEditToVisible(
        for revision: UInt64,
        outcome: PerformanceSignpostOutcome
    ) {
        lock.lock()
        let handle = editIntervalsByRevision.removeValue(forKey: revision)
        lock.unlock()
        end(handle, outcome: outcome)
    }

    func cancelAll() {
        lock.lock()
        acceptsNewIntervals = false
        let tokens = active
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map(\.value)
        active.removeAll()
        editIntervalsByRevision.removeAll()
        lock.unlock()
        for token in tokens {
            signposter.endInterval(token, outcome: .cancelled)
        }
    }
}

enum RestoreInteractivePerformanceMode: Equatable, Sendable {
    case normal
    case benchmark
}

enum RestoreInteractiveMilestone: Equatable, Sendable {
    case restoreCompleted
    case readerAttached
    case readerFirstLayoutCompleted
    case editorReady
    case syntheticEditAccepted
    case syntheticEditReflectedInReader
    case mainActorSentinelCompleted
}

@MainActor
final class RestoreInteractivePerformanceGate {
    private let registry: PerformanceIntervalRegistry
    private var handle: PerformanceIntervalHandle?
    private var mode: RestoreInteractivePerformanceMode = .normal
    private var didRestore = false
    private var isReaderAttached = false
    private var didCompleteFirstLayout = false
    private var isEditorReady = false
    private var didAcceptSyntheticEdit = false
    private var didReflectSyntheticEdit = false
    private var sentinelGeneration: UInt64 = 0
    private(set) var recordedMilestones: [RestoreInteractiveMilestone] = []
    private(set) var openCountsAfterMilestones: [Int] = []

    init(registry: PerformanceIntervalRegistry) {
        self.registry = registry
    }

    func begin(
        reason: PerformanceSignpostReason,
        mode: RestoreInteractivePerformanceMode = .normal
    ) {
        cancel()
        self.mode = mode
        didRestore = false
        isReaderAttached = false
        didCompleteFirstLayout = false
        isEditorReady = false
        didAcceptSyntheticEdit = false
        didReflectSyntheticEdit = false
        recordedMilestones.removeAll(keepingCapacity: true)
        openCountsAfterMilestones.removeAll(keepingCapacity: true)
        handle = registry.begin(.restoreToInteractive, reason: reason)
    }

    func restoreCompleted() {
        guard handle != nil, !didRestore else { return }
        didRestore = true
        record(.restoreCompleted)
        scheduleCompletionIfReady()
    }

    func readerAttached() {
        guard handle != nil, didRestore, !isReaderAttached else { return }
        isReaderAttached = true
        record(.readerAttached)
        scheduleCompletionIfReady()
    }

    func readerFirstLayoutCompleted() {
        guard handle != nil, didRestore, !didCompleteFirstLayout else { return }
        didCompleteFirstLayout = true
        record(.readerFirstLayoutCompleted)
        scheduleCompletionIfReady()
    }

    func editorReady() {
        guard handle != nil, didRestore, !isEditorReady else { return }
        isEditorReady = true
        record(.editorReady)
        scheduleCompletionIfReady()
    }

    func syntheticEditAccepted() {
        guard mode == .benchmark, !didAcceptSyntheticEdit else { return }
        didAcceptSyntheticEdit = true
        record(.syntheticEditAccepted)
        scheduleCompletionIfReady()
    }

    func syntheticEditReflectedInReader() {
        guard mode == .benchmark, !didReflectSyntheticEdit else { return }
        didReflectSyntheticEdit = true
        record(.syntheticEditReflectedInReader)
        scheduleCompletionIfReady()
    }

    func completeAfterMainActorSentinel() async {
        let (next, overflow) = sentinelGeneration.addingReportingOverflow(1)
        precondition(!overflow, "Restore sentinel generation exhausted")
        sentinelGeneration = next
        await Task.yield()
        guard
            handle != nil,
            sentinelGeneration == next,
            didRestore,
            isReaderAttached,
            isReadyForSentinel
        else { return }
        registry.end(handle, outcome: .success)
        handle = nil
        record(.mainActorSentinelCompleted)
    }

    func fail() {
        registry.end(handle, outcome: .failure)
        handle = nil
    }

    func cancel() {
        sentinelGeneration = nextSentinelGeneration()
        registry.end(handle, outcome: .cancelled)
        handle = nil
    }

    private func scheduleCompletionIfReady() {
        guard handle != nil, isReadyForSentinel else {
            return
        }
        let generation = nextSentinelGeneration()
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.sentinelGeneration == generation else { return }
            self.registry.end(self.handle, outcome: .success)
            self.handle = nil
            self.record(.mainActorSentinelCompleted)
        }
    }

    private var isReadyForSentinel: Bool {
        guard didRestore, isReaderAttached, didCompleteFirstLayout else { return false }
        guard mode == .benchmark else { return true }
        return isEditorReady && didAcceptSyntheticEdit && didReflectSyntheticEdit
    }

    private func record(_ milestone: RestoreInteractiveMilestone) {
        recordedMilestones.append(milestone)
        openCountsAfterMilestones.append(registry.openIntervalCount)
    }

    private func nextSentinelGeneration() -> UInt64 {
        let (next, overflow) = sentinelGeneration.addingReportingOverflow(1)
        precondition(!overflow, "Restore sentinel generation exhausted")
        sentinelGeneration = next
        return next
    }
}

enum PerformancePersistenceContext {
    @TaskLocal static var reason: PerformanceSignpostReason?
}

final class PerformancePersistenceIntervals: @unchecked Sendable {
    private let registry: PerformanceIntervalRegistry

    init(registry: PerformanceIntervalRegistry) {
        self.registry = registry
    }

    func scheduleSave(
        _ snapshot: PersistedSnapshot,
        store: SnapshotStore
    ) async throws {
        let handle = registry.begin(.snapshotEncode, reason: nil)
        do {
            try await PerformancePersistenceContext.$reason.withValue(.debounced) {
                try await store.scheduleSave(snapshot)
            }
            registry.end(handle, outcome: .success)
        } catch {
            registry.end(handle, outcome: .failure)
            throw error
        }
    }

    func flush(store: SnapshotStore) async throws {
        let handle = registry.begin(.snapshotFlush, reason: .flush)
        do {
            try await PerformancePersistenceContext.$reason.withValue(.flush) {
                try await store.flush()
            }
            registry.end(handle, outcome: .success)
        } catch {
            registry.end(handle, outcome: .failure)
            throw error
        }
    }
}

struct PerformanceSnapshotFileSystem<Base: SnapshotFileSystem>: SnapshotFileSystem {
    let base: Base
    let registry: PerformanceIntervalRegistry

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
        let handle = registry.begin(
            .snapshotWrite,
            reason: PerformancePersistenceContext.reason ?? .debounced
        )
        do {
            try base.atomicCommit(data, to: destinationURL, temporaryURL: temporaryURL)
            registry.end(handle, outcome: .success)
        } catch {
            registry.end(handle, outcome: .failure)
            throw error
        }
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try base.moveItem(at: sourceURL, to: destinationURL)
    }
}
