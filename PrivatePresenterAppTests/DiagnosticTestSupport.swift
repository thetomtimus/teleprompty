#if DEBUG
import Foundation
@testable import PrivatePresenter

func makeDiagnosticConfiguration(
    level: OverlayPanelLevel = .statusBar,
    ordering: OverlayPanelOrderingMode = .frontRegardless,
    cohort: DiagnosticControllerCohort = .orderedOut,
    repetition: String = "1"
) -> DiagnosticProofConfiguration {
    DiagnosticProofConfiguration(
        implementationCommit: String(repeating: "a", count: 40),
        proofLevel: level,
        ordering: ordering,
        declaredControllerCohort: cohort,
        repetition: repetition,
        executableSHA256: String(repeating: "b", count: 64),
        buildLogPath: "/tmp/private-presenter-generated-proof-build.log",
        buildLogSHA256: String(repeating: "c", count: 64),
        buildManifestPath: "/tmp/private-presenter-generated-proof-manifest.txt"
    )
}

enum RecordingDiagnosticSinkFailure: String, Error, Sendable {
    case append
    case synchronize
    case close
    case publish
}

final class RecordingDiagnosticSink: DiagnosticEvidenceSink, @unchecked Sendable {
    let pendingURL: URL
    let finalURL: URL

    private let condition = NSCondition()
    private let failure: RecordingDiagnosticSinkFailure?
    private let blocksFirstAppend: Bool
    private var appendCalls = 0
    private var releaseFirstAppend = false
    private var chunks: [Data] = []
    private var recordedOperations: [String] = []

    init(
        pendingURL: URL,
        finalURL: URL,
        failure: RecordingDiagnosticSinkFailure? = nil,
        blocksFirstAppend: Bool = false
    ) {
        self.pendingURL = pendingURL
        self.finalURL = finalURL
        self.failure = failure
        self.blocksFirstAppend = blocksFirstAppend
        try? FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: pendingURL.path, contents: nil)
    }

    func append(_ data: Data) throws {
        condition.lock()
        appendCalls += 1
        let shouldBlock = blocksFirstAppend && appendCalls == 1
        condition.broadcast()
        while shouldBlock && !releaseFirstAppend {
            condition.wait()
        }
        recordedOperations.append("append")
        chunks.append(data)
        condition.broadcast()
        condition.unlock()
        if failure == .append { throw RecordingDiagnosticSinkFailure.append }
    }

    func synchronize() throws {
        recordOperation("synchronize")
        if failure == .synchronize { throw RecordingDiagnosticSinkFailure.synchronize }
    }

    func close() throws {
        recordOperation("close")
        if failure == .close { throw RecordingDiagnosticSinkFailure.close }
    }

    func publish() throws {
        recordOperation("publish")
        if failure == .publish { throw RecordingDiagnosticSinkFailure.publish }
        condition.lock()
        let data = chunks.reduce(into: Data()) { $0.append($1) }
        condition.unlock()
        try? FileManager.default.removeItem(at: pendingURL)
        FileManager.default.createFile(atPath: finalURL.path, contents: data)
    }

    func waitUntilFirstAppendStarts(timeout: TimeInterval = 2) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while appendCalls == 0 {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }

    func unblockFirstAppend() {
        condition.lock()
        releaseFirstAppend = true
        condition.broadcast()
        condition.unlock()
    }

    func waitForAppendCount(_ expected: Int, timeout: TimeInterval = 2) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while appendCalls < expected {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }

    var operations: [String] {
        condition.lock()
        defer { condition.unlock() }
        return recordedOperations
    }

    var envelopes: [DiagnosticEventEnvelope] {
        condition.lock()
        let data = chunks.reduce(into: Data()) { $0.append($1) }
        condition.unlock()
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap {
            try? decoder.decode(DiagnosticEventEnvelope.self, from: Data($0))
        }
    }

    private func recordOperation(_ operation: String) {
        condition.lock()
        recordedOperations.append(operation)
        condition.broadcast()
        condition.unlock()
    }
}

struct DiagnosticRecorderHarness {
    let recorder: DiagnosticEvidenceRecorder
    let sink: RecordingDiagnosticSink
    let rootURL: URL
}

func makeDiagnosticRecorderHarness(
    configuration: DiagnosticProofConfiguration = makeDiagnosticConfiguration(),
    capacity: Int = 64,
    failure: RecordingDiagnosticSinkFailure? = nil,
    blocksFirstAppend: Bool = false,
    clock: @escaping DiagnosticEvidenceRecorder.MonotonicClock = {
        DispatchTime.now().uptimeNanoseconds
    }
) -> DiagnosticRecorderHarness {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "private-presenter-diagnostics-generated-\(UUID().uuidString)",
        isDirectory: true
    )
    let sessionID = UUID()
    let sessionRoot = root.appendingPathComponent(
        sessionID.uuidString.lowercased(),
        isDirectory: true
    )
    let finalURL = sessionRoot.appendingPathComponent(DiagnosticEvidenceRecorder.filename)
    let sink = RecordingDiagnosticSink(
        pendingURL: finalURL.appendingPathExtension("pending"),
        finalURL: finalURL,
        failure: failure,
        blocksFirstAppend: blocksFirstAppend
    )
    let recorder = DiagnosticEvidenceRecorder(
        configuration: configuration,
        sessionID: sessionID,
        rootURL: root,
        capacity: capacity,
        clock: clock,
        sinkFactory: { _, _ in sink }
    )
    return DiagnosticRecorderHarness(recorder: recorder, sink: sink, rootURL: root)
}
#endif
