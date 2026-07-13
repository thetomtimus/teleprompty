#if DEBUG
import CryptoKit
import Darwin
import Foundation

enum DiagnosticEventKind: String, Codable, CaseIterable, Sendable {
    case configurationBound
    case controllerCohortObserved
    case carbonReceived
    case mainDispatchBegan
    case commandBefore
    case commandAfter
    case directiveBefore
    case directiveAfter
    case effectEmitted
    case effectApplyBefore
    case effectApplyAfter
    case panelOperation
    case controllerOperation
    case applicationLifecycle
    case workspaceActivation
    case windowLifecycle
    case focusImmediate
    case focusNextMainRunLoop
    case focusDelayed100Milliseconds
    case focusDelayed500Milliseconds
    case correlationWindowClosed
    case recorderFault
    case sessionEnded
    case sessionCompletion
}

enum DiagnosticFaultCode: String, Codable, CaseIterable, Hashable, Sendable {
    case evidenceOpenFailed = "EVIDENCE_OPEN_FAILED"
    case evidenceAppendFailed = "EVIDENCE_APPEND_FAILED"
    case evidenceFlushFailed = "EVIDENCE_FLUSH_FAILED"
    case evidencePathUnresolved = "EVIDENCE_PATH_UNRESOLVED"
    case evidenceQueueOverflow = "EVIDENCE_QUEUE_OVERFLOW"
    case evidenceCloseFailed = "EVIDENCE_CLOSE_FAILED"
    case evidenceFinalizeFailed = "EVIDENCE_FINALIZE_FAILED"
    case configCommitInvalid = "CONFIG_COMMIT_INVALID"
    case configLevelInvalid = "CONFIG_LEVEL_INVALID"
    case configOrderingInvalid = "CONFIG_ORDERING_INVALID"
    case configControllerCohortInvalid = "CONFIG_CONTROLLER_COHORT_INVALID"
    case configRepetitionInvalid = "CONFIG_REPETITION_INVALID"
    case controllerCohortMismatch = "CONTROLLER_COHORT_MISMATCH"
    case configExecutableHashInvalid = "CONFIG_EXECUTABLE_HASH_INVALID"
    case configBuildLogPathInvalid = "CONFIG_BUILD_LOG_PATH_INVALID"
    case configBuildLogHashInvalid = "CONFIG_BUILD_LOG_HASH_INVALID"
    case configBuildManifestPathInvalid = "CONFIG_BUILD_MANIFEST_PATH_INVALID"
    case provenanceExecutableHashMismatch = "PROVENANCE_EXECUTABLE_HASH_MISMATCH"
    case provenanceBuildLogHashMismatch = "PROVENANCE_BUILD_LOG_HASH_MISMATCH"
    case provenanceHeadMismatch = "PROVENANCE_HEAD_MISMATCH"
}

enum DiagnosticProofStatus: Equatable, Sendable {
    case pending
    case valid
    case invalid(DiagnosticFaultCode)
}

enum DiagnosticSerializedProofStatus: String, Codable, Sendable {
    case pending
    case valid
    case invalid
}

enum DiagnosticFocusVerdict: Equatable, Sendable {
    case pass
    case failUnexpectedActivation

    static func evaluate(
        envelopes: [DiagnosticEventEnvelope],
        normalTerminationConfirmed: Bool
    ) -> DiagnosticFocusVerdict {
        let lastClosedSequence =
            envelopes
            .filter { $0.kind == .correlationWindowClosed }
            .map(\.sequence)
            .max()
        for envelope in envelopes where envelope.kind == .applicationLifecycle {
            guard
                envelope.payload.applicationLifecycle == .willBecomeActive
                    || envelope.payload.applicationLifecycle == .didBecomeActive
            else {
                continue
            }
            let isPermittedQuit =
                envelope.payload.observationPhase == .postCorrelationQuit
                && normalTerminationConfirmed
                && lastClosedSequence.map { $0 < envelope.sequence } == true
            if !isPermittedQuit { return .failUnexpectedActivation }
        }
        return .pass
    }
}

enum DiagnosticControllerCohort: String, Codable, CaseIterable, Sendable {
    case visibleDesktopSpace
    case orderedOut
}

enum DiagnosticObservationPhase: String, Codable, Sendable {
    case correlatedAction
    case postCorrelationQuit
}

enum DiagnosticApplicationLifecycle: String, Codable, Sendable {
    case willBecomeActive
    case didBecomeActive
    case willResignActive
    case didResignActive
}

enum DiagnosticWorkspaceActivation: String, Codable, Sendable {
    case didActivateApplication
}

enum DiagnosticWindowLifecycle: String, Codable, Sendable {
    case didBecomeKey
    case didResignKey
    case didBecomeMain
    case didResignMain
    case didOrderOnScreen
    case didOrderOffScreen
    case didChangeOcclusionState
}

enum DiagnosticCommandName: String, Codable, Sendable {
    case showOverlay
    case hideOverlay
}

enum DiagnosticEffectName: String, Codable, Sendable {
    case stagePanelHidden
    case showPanel
    case hidePanel
    case setPanelLocked
    case moveControllerWhileShielded
    case other
}

enum DiagnosticPrivacyDirectiveName: String, Codable, Sendable {
    case pauseScrolling
    case hideOverlay
    case shieldController
    case invalidatePendingShow
    case queryTopology
    case evaluatePrivacy
    case moveWindowsWhileShielded
    case requestConfirmation
    case publishSafeState
}

enum DiagnosticPanelOperationName: String, Codable, Sendable {
    case stageHidden
    case applyContainedFrame
    case orderFront
    case orderFrontRegardless
    case orderOut
    case setLocked
}

enum DiagnosticControllerOperationName: String, Codable, Sendable {
    case showShieldedEntry
    case frameChanged
    case showWindow
    case showShieldedExit
}

enum DiagnosticWindowOwner: String, Codable, Sendable {
    case panel
    case controller
}

struct DiagnosticRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }
}

struct DiagnosticWindowState: Codable, Equatable, Sendable {
    let isVisible: Bool
    let isKey: Bool
    let isMain: Bool
    let frame: DiagnosticRect
    let occlusionState: UInt
}

struct DiagnosticFocusState: Codable, Equatable, Sendable {
    let frontmostProcessIdentifier: Int32?
    let frontmostBundleIdentifier: String?
    let applicationIsActive: Bool
    let activationPolicy: String
    let panel: DiagnosticWindowState
    let controller: DiagnosticWindowState?
    let controllerShowCount: Int
    let controllerShielded: Bool
}

struct DiagnosticEventPayload: Codable, Equatable, Sendable {
    var configuration: DiagnosticProofConfiguration?
    var faultCode: DiagnosticFaultCode?
    var droppedEventCount: UInt64?
    var declaredControllerCohort: DiagnosticControllerCohort?
    var observedControllerCohort: DiagnosticControllerCohort?
    var command: DiagnosticCommandName?
    var effect: DiagnosticEffectName?
    var privacyDirective: DiagnosticPrivacyDirectiveName?
    var panelOperation: DiagnosticPanelOperationName?
    var controllerOperation: DiagnosticControllerOperationName?
    var applicationLifecycle: DiagnosticApplicationLifecycle?
    var workspaceActivation: DiagnosticWorkspaceActivation?
    var windowLifecycle: DiagnosticWindowLifecycle?
    var windowOwner: DiagnosticWindowOwner?
    var observationPhase: DiagnosticObservationPhase?
    var focus: DiagnosticFocusState?
    var panelState: DiagnosticWindowState?
    var controllerState: DiagnosticWindowState?
    var proofStatus: DiagnosticSerializedProofStatus?
    var permanentInvalidation: DiagnosticFaultCode?
    var implementationCommit: String?

    init(
        configuration: DiagnosticProofConfiguration? = nil,
        faultCode: DiagnosticFaultCode? = nil,
        droppedEventCount: UInt64? = nil,
        declaredControllerCohort: DiagnosticControllerCohort? = nil,
        observedControllerCohort: DiagnosticControllerCohort? = nil,
        command: DiagnosticCommandName? = nil,
        effect: DiagnosticEffectName? = nil,
        privacyDirective: DiagnosticPrivacyDirectiveName? = nil,
        panelOperation: DiagnosticPanelOperationName? = nil,
        controllerOperation: DiagnosticControllerOperationName? = nil,
        applicationLifecycle: DiagnosticApplicationLifecycle? = nil,
        workspaceActivation: DiagnosticWorkspaceActivation? = nil,
        windowLifecycle: DiagnosticWindowLifecycle? = nil,
        windowOwner: DiagnosticWindowOwner? = nil,
        observationPhase: DiagnosticObservationPhase? = nil,
        focus: DiagnosticFocusState? = nil,
        panelState: DiagnosticWindowState? = nil,
        controllerState: DiagnosticWindowState? = nil,
        proofStatus: DiagnosticSerializedProofStatus? = nil,
        permanentInvalidation: DiagnosticFaultCode? = nil,
        implementationCommit: String? = nil
    ) {
        self.configuration = configuration
        self.faultCode = faultCode
        self.droppedEventCount = droppedEventCount
        self.declaredControllerCohort = declaredControllerCohort
        self.observedControllerCohort = observedControllerCohort
        self.command = command
        self.effect = effect
        self.privacyDirective = privacyDirective
        self.panelOperation = panelOperation
        self.controllerOperation = controllerOperation
        self.applicationLifecycle = applicationLifecycle
        self.workspaceActivation = workspaceActivation
        self.windowLifecycle = windowLifecycle
        self.windowOwner = windowOwner
        self.observationPhase = observationPhase
        self.focus = focus
        self.panelState = panelState
        self.controllerState = controllerState
        self.proofStatus = proofStatus
        self.permanentInvalidation = permanentInvalidation
        self.implementationCommit = implementationCommit
    }
}

struct DiagnosticEventEnvelope: Codable, Equatable, Sendable {
    let sessionID: UUID
    let correlationID: UUID?
    let sourceMonotonicNanoseconds: UInt64
    let sequence: UInt64
    let kind: DiagnosticEventKind
    let payload: DiagnosticEventPayload
}

struct DiagnosticProofConfiguration: Codable, Equatable, Sendable {
    static let defaultLevel = OverlayPanelLevel.statusBar
    static let defaultOrdering = OverlayPanelOrderingMode.frontRegardless

    let implementationCommit: String
    let proofLevel: OverlayPanelLevel
    let ordering: OverlayPanelOrderingMode
    let declaredControllerCohort: DiagnosticControllerCohort
    let repetition: String
    let executableSHA256: String
    let buildLogPath: String
    let buildLogSHA256: String
    let buildManifestPath: String

    var configurationIdentifier: String {
        [proofLevel.rawValue, ordering.rawValue, declaredControllerCohort.rawValue, repetition]
            .joined(separator: "-")
    }

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DiagnosticConfigurationResolution {
        var faults: [DiagnosticFaultCode] = []

        let rawCommit = environment["PRIVATE_PRESENTER_EVIDENCE_COMMIT"] ?? ""
        let commit: String
        if isLowercaseHex(rawCommit, count: 40) {
            commit = rawCommit
        } else {
            commit = String(repeating: "0", count: 40)
            faults.append(.configCommitInvalid)
        }

        let level: OverlayPanelLevel
        if let value = environment["PRIVATE_PRESENTER_PROOF_LEVEL"],
            let parsed = OverlayPanelLevel(rawValue: value)
        {
            level = parsed
        } else {
            level = defaultLevel
            faults.append(.configLevelInvalid)
        }

        let ordering: OverlayPanelOrderingMode
        if let value = environment["PRIVATE_PRESENTER_ORDERING"],
            let parsed = OverlayPanelOrderingMode(rawValue: value)
        {
            ordering = parsed
        } else {
            ordering = defaultOrdering
            faults.append(.configOrderingInvalid)
        }

        let cohort: DiagnosticControllerCohort
        if let value = environment["PRIVATE_PRESENTER_CONTROLLER_COHORT"],
            let parsed = DiagnosticControllerCohort(rawValue: value)
        {
            cohort = parsed
        } else {
            cohort = .visibleDesktopSpace
            faults.append(.configControllerCohortInvalid)
        }

        let rawRepetition = environment["PRIVATE_PRESENTER_REPETITION"] ?? ""
        let repetition: String
        if rawRepetition == "1" || rawRepetition == "2" || rawRepetition == "3" {
            repetition = rawRepetition
        } else {
            repetition = ""
            faults.append(.configRepetitionInvalid)
        }

        let rawExecutableHash =
            environment[
                "PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256"
            ] ?? ""
        let executableHash: String
        if isLowercaseHex(rawExecutableHash, count: 64) {
            executableHash = rawExecutableHash
        } else {
            executableHash = String(repeating: "0", count: 64)
            faults.append(.configExecutableHashInvalid)
        }

        let rawBuildLogPath = environment["PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG"] ?? ""
        let buildLogPath: String
        if isResolvedAbsolutePath(rawBuildLogPath) {
            buildLogPath = rawBuildLogPath
        } else {
            buildLogPath = ""
            faults.append(.configBuildLogPathInvalid)
        }

        let rawBuildLogHash =
            environment[
                "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256"
            ] ?? ""
        let buildLogHash: String
        if isLowercaseHex(rawBuildLogHash, count: 64) {
            buildLogHash = rawBuildLogHash
        } else {
            buildLogHash = String(repeating: "0", count: 64)
            faults.append(.configBuildLogHashInvalid)
        }

        let rawManifestPath =
            environment[
                "PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST"
            ] ?? ""
        let manifestPath: String
        if isResolvedAbsolutePath(rawManifestPath) {
            manifestPath = rawManifestPath
        } else {
            manifestPath = ""
            faults.append(.configBuildManifestPathInvalid)
        }

        return DiagnosticConfigurationResolution(
            configuration: DiagnosticProofConfiguration(
                implementationCommit: commit,
                proofLevel: level,
                ordering: ordering,
                declaredControllerCohort: cohort,
                repetition: repetition,
                executableSHA256: executableHash,
                buildLogPath: buildLogPath,
                buildLogSHA256: buildLogHash,
                buildManifestPath: manifestPath
            ),
            faults: faults
        )
    }

    private static func isLowercaseHex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count
            && value.utf8.allSatisfy { byte in
                (48...57).contains(byte) || (97...102).contains(byte)
            }
    }

    private static func isResolvedAbsolutePath(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let url = URL(fileURLWithPath: value)
        return url.path == value && url.standardizedFileURL.path == value
    }
}

struct DiagnosticConfigurationResolution: Equatable, Sendable {
    let configuration: DiagnosticProofConfiguration
    let faults: [DiagnosticFaultCode]
}

enum DiagnosticProvenanceValidator {
    static func validate(
        _ configuration: DiagnosticProofConfiguration,
        executableURL: URL? = Bundle.main.executableURL,
        fileManager: FileManager = .default
    ) -> [DiagnosticFaultCode] {
        guard
            let executableURL,
            fileManager.isExecutableFile(atPath: executableURL.path),
            let actualExecutableHash = sha256(of: executableURL)
        else {
            return [.provenanceExecutableHashMismatch]
        }

        var faults: [DiagnosticFaultCode] = []
        if actualExecutableHash != configuration.executableSHA256 {
            faults.append(.provenanceExecutableHashMismatch)
        }

        let buildLogURL = URL(fileURLWithPath: configuration.buildLogPath)
        guard fileManager.isReadableFile(atPath: buildLogURL.path),
            let actualBuildLogHash = sha256(of: buildLogURL),
            let buildLogData = try? Data(contentsOf: buildLogURL),
            let buildLogText = String(data: buildLogData, encoding: .utf8)
        else {
            faults.append(.configBuildLogPathInvalid)
            return faults
        }
        if actualBuildLogHash != configuration.buildLogSHA256 {
            faults.append(.provenanceBuildLogHashMismatch)
        }

        let manifestURL = URL(fileURLWithPath: configuration.buildManifestPath)
        guard
            fileManager.isReadableFile(atPath: manifestURL.path),
            let manifestData = try? Data(contentsOf: manifestURL),
            let manifestText = String(data: manifestData, encoding: .utf8)
        else {
            faults.append(.configBuildManifestPathInvalid)
            return faults
        }

        let requiredManifestKeys: Set<String> = [
            "commit",
            "clean_head",
            "executable_path",
            "executable_sha256",
            "build_log_path",
            "build_log_sha256",
        ]
        var manifest: [String: String] = [:]
        var manifestMalformed = false
        for line in manifestText.split(whereSeparator: { $0.isNewline }) {
            let parts = line.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard parts.count == 2 else {
                manifestMalformed = true
                continue
            }
            let key = String(parts[0])
            guard requiredManifestKeys.contains(key), manifest[key] == nil else {
                manifestMalformed = true
                continue
            }
            manifest[key] = String(parts[1])
        }
        let buildLogLines = buildLogText.split(
            maxSplits: .max,
            omittingEmptySubsequences: false,
            whereSeparator: { $0.isNewline }
        ).map(String.init)
        let buildCommits =
            buildLogLines
            .filter { $0.hasPrefix("commit=") }
            .map { String($0.dropFirst("commit=".count)) }
        let buildStatuses =
            buildLogLines
            .filter { $0.hasPrefix("status_porcelain=") }
            .map { String($0.dropFirst("status_porcelain=".count)) }
        if manifestMalformed
            || Set(manifest.keys) != requiredManifestKeys
            || manifest["commit"] != configuration.implementationCommit
            || manifest["clean_head"] != "true"
            || buildCommits != [configuration.implementationCommit]
            || buildStatuses != [""]
        {
            faults.append(.provenanceHeadMismatch)
        }
        if manifest["executable_path"] != executableURL.path
            || manifest["executable_sha256"] != configuration.executableSHA256
        {
            faults.append(.provenanceExecutableHashMismatch)
        }
        if manifest["build_log_path"] != configuration.buildLogPath
            || manifest["build_log_sha256"] != configuration.buildLogSHA256
        {
            faults.append(.provenanceBuildLogHashMismatch)
        }
        return Array(Set(faults)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let data = try handle.read(upToCount: 64 * 1_024), !data.isEmpty {
                hasher.update(data: data)
            }
        } catch {
            return nil
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

protocol DiagnosticEvidenceSink: AnyObject, Sendable {
    var pendingURL: URL { get }
    var finalURL: URL { get }
    func append(_ data: Data) throws
    func synchronize() throws
    func close() throws
    func publish() throws
}

final class LocalDiagnosticEvidenceSink: DiagnosticEvidenceSink, @unchecked Sendable {
    let pendingURL: URL
    let finalURL: URL
    private let fileManager: FileManager
    private var handle: FileHandle?

    init(pendingURL: URL, finalURL: URL, fileManager: FileManager = .default) throws {
        self.pendingURL = pendingURL
        self.finalURL = finalURL
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: finalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard
            !fileManager.fileExists(atPath: pendingURL.path),
            !fileManager.fileExists(atPath: finalURL.path),
            fileManager.createFile(atPath: pendingURL.path, contents: nil)
        else { throw DiagnosticSinkError.openFailed }
        handle = try FileHandle(forWritingTo: pendingURL)
    }

    func append(_ data: Data) throws {
        guard let handle else { throw DiagnosticSinkError.closed }
        try handle.write(contentsOf: data)
    }

    func synchronize() throws {
        guard let handle else { throw DiagnosticSinkError.closed }
        try handle.synchronize()
    }

    func close() throws {
        guard let handle else { throw DiagnosticSinkError.closed }
        try handle.close()
        self.handle = nil
    }

    func publish() throws {
        guard handle == nil else { throw DiagnosticSinkError.notClosed }
        try fileManager.moveItem(at: pendingURL, to: finalURL)
    }

    private enum DiagnosticSinkError: Error {
        case openFailed
        case closed
        case notClosed
    }
}

final class DiagnosticEvidenceRecorder: @unchecked Sendable {
    typealias MonotonicClock = @Sendable () -> UInt64
    typealias SinkFactory = @Sendable (URL, URL) throws -> any DiagnosticEvidenceSink

    static let defaultCapacity = 4_096
    static let directoryName = "Private Presenter"
    static let validationDirectoryName = "Validation"
    static let filename = "overlay-diagnostics.txt"

    let sessionID: UUID
    let configuration: DiagnosticProofConfiguration
    let pendingURL: URL?
    let finalURL: URL?

    private struct PendingEvent {
        let correlationID: UUID?
        let sourceMonotonicNanoseconds: UInt64
        let sequence: UInt64
        let kind: DiagnosticEventKind
        let payload: DiagnosticEventPayload
    }

    private let capacity: Int
    private let clock: MonotonicClock
    private let sink: (any DiagnosticEvidenceSink)?
    private let writerQueue = DispatchQueue(
        label: "com.privatepresenter.diagnostic-evidence-writer",
        qos: .utility
    )
    private let queueLock = NSLock()
    private let faultLock = NSLock()
    private var ring: [PendingEvent?]
    private var head = 0
    private var count = 0
    private var atomicSequence: Int64 = 0
    private var writerScheduled = false
    private var acceptingEvents = true
    private var firstFault: DiagnosticFaultCode?
    private var droppedEventCount: UInt64 = 0
    private var overflowFaultSerialized = false
    private var finalizationSucceeded = false
    private var sinkFailure = false
    private var finishStarted = false
    private var overflowInvalidated: Int32 = 0
    private var atomicOverflowSequence: Int64 = 0
    private var atomicDroppedEventCount: Int64 = 0
    private var inFlightProducers: Int32 = 0

    init(
        configuration: DiagnosticProofConfiguration,
        sessionID: UUID = UUID(),
        rootURL: URL,
        capacity: Int = DiagnosticEvidenceRecorder.defaultCapacity,
        clock: @escaping MonotonicClock = { DispatchTime.now().uptimeNanoseconds },
        sinkFactory: SinkFactory = { pendingURL, finalURL in
            try LocalDiagnosticEvidenceSink(pendingURL: pendingURL, finalURL: finalURL)
        }
    ) {
        precondition(capacity > 0)
        self.configuration = configuration
        self.sessionID = sessionID
        self.capacity = capacity
        self.clock = clock
        ring = Array(repeating: nil, count: capacity)
        let sessionRoot = rootURL.appendingPathComponent(
            sessionID.uuidString.lowercased(),
            isDirectory: true
        )
        let finalURL = sessionRoot.appendingPathComponent(Self.filename)
        let pendingURL = finalURL.appendingPathExtension("pending")
        do {
            sink = try sinkFactory(pendingURL, finalURL)
            self.pendingURL = pendingURL
            self.finalURL = finalURL
        } catch {
            sink = nil
            self.pendingURL = nil
            self.finalURL = nil
        }
        _ = record(
            kind: .configurationBound,
            payload: DiagnosticEventPayload(
                configuration: configuration,
                declaredControllerCohort: configuration.declaredControllerCohort
            )
        )
        if sink == nil { invalidate(.evidenceOpenFailed) }
    }

    static func production(
        resolution: DiagnosticConfigurationResolution,
        fileManager: FileManager = .default
    ) -> DiagnosticEvidenceRecorder {
        let applicationSupport: URL
        do {
            applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            let recorder = DiagnosticEvidenceRecorder(
                configuration: resolution.configuration,
                rootURL: URL(fileURLWithPath: "/dev/null/private-presenter-validation"),
                sinkFactory: { _, _ in throw DiagnosticProductionError.pathUnresolved }
            )
            recorder.invalidate(.evidencePathUnresolved)
            resolution.faults.forEach(recorder.invalidate)
            return recorder
        }

        let root =
            applicationSupport
            .appendingPathComponent(Self.directoryName, isDirectory: true)
            .appendingPathComponent(Self.validationDirectoryName, isDirectory: true)
        let recorder = DiagnosticEvidenceRecorder(
            configuration: resolution.configuration,
            rootURL: root
        )
        resolution.faults.forEach(recorder.invalidate)
        DiagnosticProvenanceValidator.validate(resolution.configuration)
            .forEach(recorder.invalidate)
        return recorder
    }

    @discardableResult
    func record(
        kind: DiagnosticEventKind,
        correlationID: UUID? = nil,
        payload: DiagnosticEventPayload = DiagnosticEventPayload()
    ) -> Bool {
        OSAtomicIncrement32Barrier(&inFlightProducers)
        defer { OSAtomicDecrement32Barrier(&inFlightProducers) }
        let sourceTime = clock()
        let sequence = UInt64(bitPattern: OSAtomicIncrement64Barrier(&atomicSequence))
        queueLock.lock()

        guard acceptingEvents else {
            queueLock.unlock()
            return false
        }
        guard count < capacity else {
            queueLock.unlock()
            noteOverflow(sequence: sequence)
            scheduleWriterIfNeeded()
            return false
        }

        let event = PendingEvent(
            correlationID: correlationID,
            sourceMonotonicNanoseconds: sourceTime,
            sequence: sequence,
            kind: kind,
            payload: payload
        )
        ring[(head + count) % capacity] = event
        count += 1
        let shouldSchedule = !writerScheduled
        if shouldSchedule { writerScheduled = true }
        queueLock.unlock()
        if shouldSchedule { writerQueue.async { [weak self] in self?.drainLoop() } }
        return true
    }

    func invalidate(_ code: DiagnosticFaultCode) {
        latchFault(code, incrementDropCount: false, overflowSequence: nil)
        if code != .evidenceQueueOverflow {
            _ = record(
                kind: .recorderFault,
                payload: DiagnosticEventPayload(faultCode: code)
            )
        }
    }

    var proofStatus: DiagnosticProofStatus {
        faultLock.lock()
        let fault = firstFault
        let finalized = finalizationSucceeded
        faultLock.unlock()
        if let fault { return .invalid(fault) }
        if OSAtomicAdd32Barrier(0, &overflowInvalidated) != 0 {
            return .invalid(.evidenceQueueOverflow)
        }
        return finalized ? .valid : .pending
    }

    var contentNeutralDroppedEventCount: UInt64 {
        UInt64(max(0, OSAtomicAdd64Barrier(0, &atomicDroppedEventCount)))
    }

    func finish() async -> Bool {
        let shouldFinish = queueLock.withLock {
            guard !finishStarted else { return false }
            finishStarted = true
            acceptingEvents = false
            return true
        }
        guard shouldFinish else { return false }

        return await withCheckedContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                self.drainLoop()
                self.serializeTerminalEvents()
                let result = self.finalizeSink()
                continuation.resume(returning: result)
            }
        }
    }

    private func scheduleWriterIfNeeded() {
        guard queueLock.try() else {
            writerQueue.async { [weak self] in self?.drainLoop() }
            return
        }
        let shouldSchedule = !writerScheduled
        if shouldSchedule { writerScheduled = true }
        queueLock.unlock()
        if shouldSchedule { writerQueue.async { [weak self] in self?.drainLoop() } }
    }

    private func noteOverflow(sequence: UInt64?) {
        _ = OSAtomicCompareAndSwap32Barrier(0, 1, &overflowInvalidated)
        if let sequence {
            _ = OSAtomicCompareAndSwap64Barrier(
                0,
                Int64(bitPattern: sequence),
                &atomicOverflowSequence
            )
        }
        incrementAtomicDropCount()
        latchFault(
            .evidenceQueueOverflow,
            incrementDropCount: true,
            overflowSequence: sequence
        )
        scheduleWriterIfNeeded()
    }

    private func latchFault(
        _ code: DiagnosticFaultCode,
        incrementDropCount: Bool,
        overflowSequence: UInt64?
    ) {
        if code == .evidenceQueueOverflow {
            _ = OSAtomicCompareAndSwap32Barrier(0, 1, &overflowInvalidated)
        }
        faultLock.lock()
        updateFaultState(
            code,
            incrementDropCount: incrementDropCount,
            overflowSequence: overflowSequence
        )
        faultLock.unlock()
    }

    private func updateFaultState(
        _ code: DiagnosticFaultCode,
        incrementDropCount: Bool,
        overflowSequence: UInt64?
    ) {
        if firstFault == nil { firstFault = code }
        if incrementDropCount {
            droppedEventCount = UInt64(max(0, OSAtomicAdd64Barrier(0, &atomicDroppedEventCount)))
        }
        if let overflowSequence, code == .evidenceQueueOverflow {
            _ = OSAtomicCompareAndSwap64Barrier(
                0,
                Int64(bitPattern: overflowSequence),
                &atomicOverflowSequence
            )
        }
    }

    private func drainLoop() {
        while true {
            waitForIngressQuiescence()
            let batch = takeBatch()
            if batch.isEmpty {
                if serializeOverflowFaultIfNeeded() { continue }
                queueLock.lock()
                if count == 0 {
                    writerScheduled = false
                    queueLock.unlock()
                    return
                }
                queueLock.unlock()
                continue
            }
            for event in batch.sorted(by: { $0.sequence < $1.sequence }) {
                _ = serializeOverflowFaultIfNeeded(before: event.sequence)
                serialize(event)
            }
        }
    }

    private func takeBatch() -> [PendingEvent] {
        queueLock.lock()
        var batch: [PendingEvent] = []
        batch.reserveCapacity(count)
        while count > 0 {
            if let event = ring[head] { batch.append(event) }
            ring[head] = nil
            head = (head + 1) % capacity
            count -= 1
        }
        queueLock.unlock()
        return batch
    }

    private func serializeOverflowFaultIfNeeded(before upperBound: UInt64? = nil) -> Bool {
        faultLock.lock()
        guard
            !overflowFaultSerialized,
            OSAtomicAdd32Barrier(0, &overflowInvalidated) != 0,
            upperBound.map({ bound in
                let sequence = OSAtomicAdd64Barrier(0, &atomicOverflowSequence)
                guard sequence != 0 else { return false }
                return UInt64(bitPattern: sequence) < bound
            }) ?? true
        else {
            faultLock.unlock()
            return false
        }
        overflowFaultSerialized = true
        let sequence = OSAtomicAdd64Barrier(0, &atomicOverflowSequence)
        let dropped = UInt64(max(0, OSAtomicAdd64Barrier(0, &atomicDroppedEventCount)))
        faultLock.unlock()

        let resolvedSequence: UInt64
        if sequence != 0 {
            resolvedSequence = UInt64(bitPattern: sequence)
        } else {
            resolvedSequence = UInt64(
                bitPattern: OSAtomicIncrement64Barrier(&atomicSequence)
            )
        }
        serialize(
            PendingEvent(
                correlationID: nil,
                sourceMonotonicNanoseconds: clock(),
                sequence: resolvedSequence,
                kind: .recorderFault,
                payload: DiagnosticEventPayload(
                    faultCode: .evidenceQueueOverflow,
                    droppedEventCount: dropped
                )
            ))
        return true
    }

    private func serialize(_ event: PendingEvent) {
        guard let sink else { return }
        let envelope = DiagnosticEventEnvelope(
            sessionID: sessionID,
            correlationID: event.correlationID,
            sourceMonotonicNanoseconds: event.sourceMonotonicNanoseconds,
            sequence: event.sequence,
            kind: event.kind,
            payload: event.payload
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(envelope)
            data.append(0x0A)
            try sink.append(data)
        } catch {
            faultLock.lock()
            sinkFailure = true
            faultLock.unlock()
            latchFault(
                .evidenceAppendFailed,
                incrementDropCount: false,
                overflowSequence: nil
            )
        }
    }

    private func finalizeSink() -> Bool {
        guard let sink else { return false }
        faultLock.lock()
        let appendFailed = sinkFailure
        faultLock.unlock()
        guard !appendFailed else {
            try? sink.close()
            return false
        }
        do {
            try sink.synchronize()
        } catch {
            latchFault(.evidenceFlushFailed, incrementDropCount: false, overflowSequence: nil)
            return false
        }
        do {
            try sink.close()
        } catch {
            latchFault(.evidenceCloseFailed, incrementDropCount: false, overflowSequence: nil)
            return false
        }
        do {
            try sink.publish()
        } catch {
            latchFault(.evidenceFinalizeFailed, incrementDropCount: false, overflowSequence: nil)
            try? FileManager.default.removeItem(at: sink.finalURL)
            return false
        }
        faultLock.lock()
        finalizationSucceeded = true
        faultLock.unlock()
        return true
    }

    private func serializeTerminalEvents() {
        _ = serializeOverflowFaultIfNeeded()
        let endedSequence = reserveSequence()
        serialize(
            PendingEvent(
                correlationID: nil,
                sourceMonotonicNanoseconds: clock(),
                sequence: endedSequence,
                kind: .sessionEnded,
                payload: DiagnosticEventPayload()
            ))

        faultLock.lock()
        let fault = firstFault
        let appendFailed = sinkFailure
        faultLock.unlock()
        let overflowed = OSAtomicAdd32Barrier(0, &overflowInvalidated) != 0
        let invalidation = fault ?? (overflowed ? .evidenceQueueOverflow : nil)
        let serializedStatus: DiagnosticSerializedProofStatus =
            invalidation == nil && !appendFailed
            ? .valid
            : .invalid
        let completionSequence = reserveSequence()
        serialize(
            PendingEvent(
                correlationID: nil,
                sourceMonotonicNanoseconds: clock(),
                sequence: completionSequence,
                kind: .sessionCompletion,
                payload: DiagnosticEventPayload(
                    proofStatus: serializedStatus,
                    permanentInvalidation: invalidation,
                    implementationCommit: configuration.implementationCommit
                )
            ))
    }

    private func reserveSequence() -> UInt64 {
        UInt64(bitPattern: OSAtomicIncrement64Barrier(&atomicSequence))
    }

    private func incrementAtomicDropCount() {
        while true {
            let current = OSAtomicAdd64Barrier(0, &atomicDroppedEventCount)
            guard current < Int64.max else { return }
            if OSAtomicCompareAndSwap64Barrier(
                current,
                current + 1,
                &atomicDroppedEventCount
            ) {
                return
            }
        }
    }

    private func waitForIngressQuiescence() {
        while OSAtomicAdd32Barrier(0, &inFlightProducers) != 0 {
            sched_yield()
        }
    }

    private enum DiagnosticProductionError: Error {
        case pathUnresolved
    }
}
#endif
