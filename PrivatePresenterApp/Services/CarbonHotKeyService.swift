import Carbon.HIToolbox
import Foundation
import TeleprompterCore

private let productHotKeyEventHandler: EventHandlerUPP = {
    _, event, userInfo in
    guard let event, let userInfo else { return OSStatus(eventNotHandledErr) }
    var carbonIdentifier = EventHotKeyID()
    var actualSize = 0
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        &actualSize,
        &carbonIdentifier
    )
    guard status == noErr else { return status }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return registrar.receive(
        ProductHotKeyIdentifier(
            signature: carbonIdentifier.signature,
            id: carbonIdentifier.id
        )
    )
}

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private var callback: (@MainActor (ProductHotKeyIdentifier) -> Int32)?
    private var handlerReferences: [HotKeyHandlerToken: EventHandlerRef] = [:]
    private var hotKeyReferences: [HotKeyToken: EventHotKeyRef] = [:]
    private var nextToken: UInt64 = 1

    func installHandler(
        callback: @escaping @MainActor (ProductHotKeyIdentifier) -> Int32
    ) -> HotKeyCallResult<HotKeyHandlerToken> {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var reference: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            productHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &reference
        )
        guard status == noErr, let reference else { return .failure(status) }
        let token = HotKeyHandlerToken(rawValue: takeToken())
        self.callback = callback
        handlerReferences[token] = reference
        return .success(token)
    }

    func register(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        identifier: ProductHotKeyIdentifier
    ) -> HotKeyCallResult<HotKeyToken> {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            EventHotKeyID(signature: identifier.rawSignature, id: identifier.id),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return .failure(status) }
        let token = HotKeyToken(rawValue: takeToken())
        hotKeyReferences[token] = reference
        return .success(token)
    }

    func unregister(_ token: HotKeyToken) -> Int32 {
        guard let reference = hotKeyReferences[token] else { return noErr }
        let status = UnregisterEventHotKey(reference)
        if status == noErr { hotKeyReferences[token] = nil }
        return status
    }

    func removeHandler(_ token: HotKeyHandlerToken) -> Int32 {
        guard let reference = handlerReferences[token] else { return noErr }
        let status = RemoveEventHandler(reference)
        if status == noErr {
            handlerReferences[token] = nil
            callback = nil
        }
        return status
    }

    fileprivate nonisolated func receive(_ identifier: ProductHotKeyIdentifier) -> Int32 {
        MainActor.assumeIsolated {
            callback?(identifier) ?? Int32(eventNotHandledErr)
        }
    }

    private func takeToken() -> UInt64 {
        defer { nextToken += 1 }
        return nextToken
    }
}

enum HotKeyCleanupOperation: Equatable, Sendable {
    case unregister(ShortcutAction)
    case removeHandler
}

struct HotKeyCleanupStatus: Equatable, Sendable {
    let operation: HotKeyCleanupOperation
    let status: Int32
}

struct HotKeyFailure: Equatable, Sendable {
    let action: ShortcutAction
    let shortcut: KeyboardShortcut
    let status: Int32
    let cleanup: [HotKeyCleanupStatus]
}

enum HotKeyTransactionResult: Equatable, Sendable {
    case committed([ShortcutBinding])
    case conflict(HotKeyFailure)
    case degradedClean(HotKeyFailure)
    case cleanupUnknown(HotKeyFailure)
    case invalid([ShortcutViolation])
}

enum HotKeyServiceFailureKind: Equatable, Sendable {
    case degradedClean
    case cleanupUnknown
}

enum CarbonHotKeyServiceState: Equatable, Sendable {
    case unregistered
    case registering
    case registered([ShortcutBinding])
    case reconfiguring([ShortcutBinding])
    case rollingBack([ShortcutBinding])
    case degradedClean(HotKeyFailure)
    case cleanupUnknown(HotKeyFailure)

    var failureKind: HotKeyServiceFailureKind? {
        switch self {
        case .degradedClean: .degradedClean
        case .cleanupUnknown: .cleanupUnknown
        case .unregistered, .registering, .registered, .reconfiguring, .rollingBack: nil
        }
    }
}

struct HotKeyShutdownReport: Equatable, Sendable {
    let referenceStatuses: [Int32]
    let handlerStatus: Int32

    var succeeded: Bool {
        referenceStatuses.allSatisfy { $0 == noErr } && handlerStatus == noErr
    }
}

@MainActor
final class CarbonHotKeyService {
    static let cleanupUnknownMessage =
        "Global shortcuts could not be cleaned up safely. Quit and reopen Private Presenter before retrying."

    private struct ActiveEntry: Equatable {
        let binding: ShortcutBinding
        let token: HotKeyToken
    }

    private let registrar: HotKeyRegistering
    private let dispatch: @MainActor (ShortcutAction) -> Void
    private var active: [ShortcutAction: ActiveEntry] = [:]
    private var uncertain: [ActiveEntry] = []
    private var handlerToken: HotKeyHandlerToken?
    private var desiredBindings = ShortcutValidator.defaultBindings
    private var cachedShutdown: HotKeyShutdownReport?
    private(set) var state: CarbonHotKeyServiceState = .unregistered

    init(
        registrar: HotKeyRegistering,
        dispatch: @escaping @MainActor (ShortcutAction) -> Void
    ) {
        self.registrar = registrar
        self.dispatch = dispatch
    }

    var activeActionCount: Int { active.count }
    var handlerInstalled: Bool { handlerToken != nil }
    var registeredBindings: [ShortcutBinding] {
        guard case .registered(let bindings) = state else { return [] }
        return bindings
    }
    var retryAllowed: Bool {
        if case .cleanupUnknown = state { return false }
        return true
    }
    var claimsNoActiveHotKeys: Bool {
        switch state {
        case .unregistered, .degradedClean:
            return active.isEmpty && uncertain.isEmpty && handlerToken == nil
        case .registering, .registered, .reconfiguring, .rollingBack, .cleanupUnknown:
            return false
        }
    }

    func register(_ bindings: [ShortcutBinding]) -> HotKeyTransactionResult {
        if case .cleanupUnknown(let failure) = state {
            return .cleanupUnknown(failure)
        }
        if case .registered(let committed) = state, committed == bindings {
            return .committed(committed)
        }

        let canonical: [ShortcutBinding]
        do {
            canonical = try ShortcutValidator.validate(bindings)
        } catch let error as ShortcutValidationError {
            return .invalid(error.violations)
        } catch {
            return .invalid([.unknownActionCoverage])
        }

        desiredBindings = canonical
        cachedShutdown = nil
        active.removeAll()
        uncertain.removeAll()
        handlerToken = nil
        state = .registering

        let installed: HotKeyHandlerToken
        switch registrar.installHandler(callback: { [weak self] identifier in
            self?.receive(identifier: identifier) ?? Int32(eventNotHandledErr)
        }) {
        case .success(let token):
            installed = token
            handlerToken = token
        case .failure(let status):
            let failed = canonical[0]
            let failure = HotKeyFailure(
                action: failed.action,
                shortcut: failed.shortcut,
                status: status,
                cleanup: []
            )
            state = .unregistered
            return .conflict(failure)
        }

        var staged: [ShortcutAction: ActiveEntry] = [:]
        for binding in canonical {
            switch register(binding) {
            case .success(let token):
                staged[binding.action] = ActiveEntry(binding: binding, token: token)
            case .failure(let status):
                let cleanup = clean(
                    entries: orderedEntries(staged, reversed: true),
                    handler: installed
                )
                let failure = HotKeyFailure(
                    action: binding.action,
                    shortcut: binding.shortcut,
                    status: status,
                    cleanup: cleanup.records
                )
                active.removeAll()
                if cleanup.succeeded {
                    uncertain.removeAll()
                    handlerToken = nil
                    state = .unregistered
                    return .conflict(failure)
                }
                state = .cleanupUnknown(failure)
                return .cleanupUnknown(failure)
            }
        }

        active = staged
        state = .registered(canonical)
        return .committed(canonical)
    }

    func reconfigure(_ proposedBindings: [ShortcutBinding]) -> HotKeyTransactionResult {
        if case .cleanupUnknown(let failure) = state {
            return .cleanupUnknown(failure)
        }
        guard case .registered(let oldBindings) = state else {
            return register(proposedBindings)
        }

        let proposed: [ShortcutBinding]
        do {
            proposed = try ShortcutValidator.validate(proposedBindings)
        } catch let error as ShortcutValidationError {
            return .invalid(error.violations)
        } catch {
            return .invalid([.unknownActionCoverage])
        }
        guard proposed != oldBindings else { return .committed(oldBindings) }

        state = .reconfiguring(oldBindings)
        let oldByAction = Dictionary(uniqueKeysWithValues: oldBindings.map { ($0.action, $0) })
        let proposedByAction = Dictionary(uniqueKeysWithValues: proposed.map { ($0.action, $0) })
        let changedActions = ShortcutAction.stableOrder.filter {
            oldByAction[$0]?.shortcut != proposedByAction[$0]?.shortcut
        }
        let oldChangedEntries = changedActions.compactMap { active[$0] }

        for entry in oldChangedEntries {
            active[entry.binding.action] = nil
            let status = registrar.unregister(entry.token)
            if status != noErr {
                let cleanup = forceUnknownCleanup(
                    including: [entry] + Array(active.values),
                    primary: HotKeyFailure(
                        action: entry.binding.action,
                        shortcut: entry.binding.shortcut,
                        status: status,
                        cleanup: []
                    )
                )
                return cleanup
            }
        }

        var proposedEntries: [ShortcutAction: ActiveEntry] = [:]
        for action in changedActions {
            let binding = proposedByAction[action]!
            switch register(binding) {
            case .success(let token):
                proposedEntries[action] = ActiveEntry(binding: binding, token: token)
            case .failure(let status):
                let proposalCleanup = clean(
                    entries: orderedEntries(proposedEntries, reversed: true),
                    handler: nil
                )
                let proposalFailure = HotKeyFailure(
                    action: action,
                    shortcut: binding.shortcut,
                    status: status,
                    cleanup: proposalCleanup.records
                )
                guard proposalCleanup.succeeded else {
                    return forceUnknownCleanup(
                        including: Array(active.values) + uncertain,
                        primary: proposalFailure
                    )
                }
                return rollBack(
                    oldBindings: oldBindings,
                    oldChangedEntries: oldChangedEntries,
                    proposalFailure: proposalFailure
                )
            }
        }

        for (action, entry) in proposedEntries { active[action] = entry }
        desiredBindings = proposed
        state = .registered(proposed)
        return .committed(proposed)
    }

    func retry() -> HotKeyTransactionResult {
        if case .cleanupUnknown(let failure) = state {
            return .cleanupUnknown(failure)
        }
        guard active.isEmpty else {
            if case .registered(let bindings) = state { return .committed(bindings) }
            return register(desiredBindings)
        }
        return register(desiredBindings)
    }

    func shutdown() -> HotKeyShutdownReport {
        if let cachedShutdown { return cachedShutdown }
        let entries = orderedEntries(active, reversed: true) + Array(uncertain.reversed())
        active.removeAll()
        uncertain.removeAll()
        let statuses = entries.map { entry -> Int32 in
            let status = registrar.unregister(entry.token)
            if status != noErr { uncertain.append(entry) }
            return status
        }
        let handlerStatus: Int32
        if let handlerToken {
            handlerStatus = registrar.removeHandler(handlerToken)
        } else {
            handlerStatus = noErr
        }
        if handlerStatus == noErr { handlerToken = nil }
        let report = HotKeyShutdownReport(
            referenceStatuses: statuses,
            handlerStatus: handlerStatus
        )
        cachedShutdown = report
        if report.succeeded {
            state = .unregistered
        } else {
            let binding = desiredBindings.first ?? ShortcutValidator.defaultBindings[0]
            state = .cleanupUnknown(
                HotKeyFailure(
                    action: binding.action,
                    shortcut: binding.shortcut,
                    status: statuses.first(where: { $0 != noErr }) ?? handlerStatus,
                    cleanup: zip(entries, statuses).map {
                        HotKeyCleanupStatus(
                            operation: .unregister($0.0.binding.action),
                            status: $0.1
                        )
                    } + [.init(operation: .removeHandler, status: handlerStatus)]
                )
            )
        }
        return report
    }

    func receiveForTesting(identifier: ProductHotKeyIdentifier) -> Int32 {
        receive(identifier: identifier)
    }

    private func receive(identifier: ProductHotKeyIdentifier) -> Int32 {
        guard
            let action = identifier.action,
            case .registered = state,
            active[action] != nil
        else { return Int32(eventNotHandledErr) }
        dispatch(action)
        return noErr
    }

    private func register(_ binding: ShortcutBinding) -> HotKeyCallResult<HotKeyToken> {
        registrar.register(
            keyCode: binding.shortcut.virtualKeyCode,
            carbonModifiers: carbonModifiers(binding.shortcut.modifiers),
            identifier: ProductHotKeyIdentifier(action: binding.action)
        )
    }

    private func rollBack(
        oldBindings: [ShortcutBinding],
        oldChangedEntries: [ActiveEntry],
        proposalFailure: HotKeyFailure
    ) -> HotKeyTransactionResult {
        state = .rollingBack(oldBindings)
        var restored: [ShortcutAction: ActiveEntry] = [:]
        for oldEntry in oldChangedEntries {
            switch register(oldEntry.binding) {
            case .success(let token):
                restored[oldEntry.binding.action] = ActiveEntry(
                    binding: oldEntry.binding,
                    token: token
                )
            case .failure(let rollbackStatus):
                let teardownEntries = Array(active.values) + Array(restored.values)
                let teardown = clean(
                    entries: teardownEntries.sorted {
                        $0.binding.action.stableIndex > $1.binding.action.stableIndex
                    },
                    handler: handlerToken
                )
                active.removeAll()
                let rollbackFailure = HotKeyFailure(
                    action: oldEntry.binding.action,
                    shortcut: oldEntry.binding.shortcut,
                    status: rollbackStatus,
                    cleanup: proposalFailure.cleanup + teardown.records
                )
                if teardown.succeeded {
                    uncertain.removeAll()
                    handlerToken = nil
                    state = .degradedClean(rollbackFailure)
                    return .degradedClean(rollbackFailure)
                }
                state = .cleanupUnknown(rollbackFailure)
                return .cleanupUnknown(rollbackFailure)
            }
        }
        for (action, entry) in restored { active[action] = entry }
        state = .registered(oldBindings)
        return .conflict(proposalFailure)
    }

    private func forceUnknownCleanup(
        including entries: [ActiveEntry],
        primary: HotKeyFailure
    ) -> HotKeyTransactionResult {
        let unique = uniqueEntries(entries + Array(active.values) + uncertain)
        let cleanup = clean(
            entries: unique.sorted {
                $0.binding.action.stableIndex > $1.binding.action.stableIndex
            },
            handler: handlerToken
        )
        active.removeAll()
        let failure = HotKeyFailure(
            action: primary.action,
            shortcut: primary.shortcut,
            status: primary.status,
            cleanup: primary.cleanup + cleanup.records
        )
        state = .cleanupUnknown(failure)
        return .cleanupUnknown(failure)
    }

    private struct CleanupResult {
        let records: [HotKeyCleanupStatus]
        let succeeded: Bool
    }

    private func clean(
        entries: [ActiveEntry],
        handler: HotKeyHandlerToken?
    ) -> CleanupResult {
        var records: [HotKeyCleanupStatus] = []
        var succeeded = true
        for entry in uniqueEntries(entries) {
            let status = registrar.unregister(entry.token)
            records.append(.init(operation: .unregister(entry.binding.action), status: status))
            if status != noErr {
                succeeded = false
                uncertain.append(entry)
            }
        }
        if let handler {
            let status = registrar.removeHandler(handler)
            records.append(.init(operation: .removeHandler, status: status))
            if status == noErr {
                if handlerToken == handler { handlerToken = nil }
            } else {
                succeeded = false
            }
        }
        return CleanupResult(records: records, succeeded: succeeded)
    }

    private func orderedEntries(
        _ entries: [ShortcutAction: ActiveEntry],
        reversed: Bool
    ) -> [ActiveEntry] {
        entries.values.sorted {
            reversed
                ? $0.binding.action.stableIndex > $1.binding.action.stableIndex
                : $0.binding.action.stableIndex < $1.binding.action.stableIndex
        }
    }

    private func uniqueEntries(_ entries: [ActiveEntry]) -> [ActiveEntry] {
        var seen: Set<HotKeyToken> = []
        return entries.filter { seen.insert($0.token).inserted }
    }

    private func carbonModifiers(_ modifiers: Set<ShortcutModifier>) -> UInt32 {
        modifiers.reduce(into: UInt32(0)) { result, modifier in
            switch modifier {
            case .control: result |= UInt32(controlKey)
            case .option: result |= UInt32(optionKey)
            case .shift: result |= UInt32(shiftKey)
            case .command: result |= UInt32(cmdKey)
            }
        }
    }
}
