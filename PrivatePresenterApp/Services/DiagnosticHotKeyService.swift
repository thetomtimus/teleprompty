#if DEBUG
import Carbon.HIToolbox
import Dispatch
import Foundation

enum DiagnosticHotKeyAction: UInt32, CaseIterable, Sendable {
    case visibility = 1
    case lock = 2

    var chordDescription: String {
        switch self {
        case .visibility: "Control-Option-H"
        case .lock: "Control-Option-L"
        }
    }

    var virtualKeyCode: UInt32 {
        switch self {
        case .visibility: UInt32(kVK_ANSI_H)
        case .lock: UInt32(kVK_ANSI_L)
        }
    }
}

struct DiagnosticHotKeyRegistrationStatus: Equatable, Sendable {
    let visibility: OSStatus
    let lock: OSStatus

    static let success = DiagnosticHotKeyRegistrationStatus(
        visibility: noErr,
        lock: noErr
    )

    var allRegistered: Bool {
        visibility == noErr && lock == noErr
    }
}

private let diagnosticHotKeySignature: OSType = 0x5050_5452

private let diagnosticHotKeyEventHandler: EventHandlerUPP = {
    _, event, userInfo in
    guard let event, let userInfo else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    var actualSize = 0
    let parameterStatus = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        &actualSize,
        &identifier
    )
    guard parameterStatus == noErr else { return parameterStatus }
    let service = Unmanaged<DiagnosticHotKeyService>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return service.receiveCarbonEvent(identifier: identifier)
}

/// Two DEBUG-only global proof chords. Product hot-key registration remains M4 work.
@MainActor
final class DiagnosticHotKeyService {
    static let visibilityChordDescription = DiagnosticHotKeyAction.visibility.chordDescription
    static let lockChordDescription = DiagnosticHotKeyAction.lock.chordDescription

    private nonisolated let carbonReceipt: @Sendable (UUID, DiagnosticHotKeyAction) -> Void
    private let action: @MainActor (UUID, DiagnosticHotKeyAction) -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [DiagnosticHotKeyAction: EventHotKeyRef] = [:]
    private var registeredActions: Set<DiagnosticHotKeyAction> = []
    private let registrationOverride: (@MainActor (DiagnosticHotKeyAction) -> OSStatus)?
    private let unregistrationObserver: (@MainActor (DiagnosticHotKeyAction) -> Void)?
    private(set) var lastRegistrationStatus: DiagnosticHotKeyRegistrationStatus?

    init(action: @escaping @MainActor (DiagnosticHotKeyAction) -> Void) {
        carbonReceipt = { _, _ in }
        self.action = { _, hotKeyAction in action(hotKeyAction) }
        registrationOverride = nil
        unregistrationObserver = nil
    }

    init(
        carbonReceipt: @escaping @Sendable (UUID, DiagnosticHotKeyAction) -> Void,
        action: @escaping @MainActor (UUID, DiagnosticHotKeyAction) -> Void
    ) {
        self.carbonReceipt = carbonReceipt
        self.action = action
        registrationOverride = nil
        unregistrationObserver = nil
    }

    init(
        action: @escaping @MainActor (DiagnosticHotKeyAction) -> Void,
        registrationOverride: @escaping @MainActor (DiagnosticHotKeyAction) -> OSStatus,
        unregistrationObserver: @escaping @MainActor (DiagnosticHotKeyAction) -> Void
    ) {
        carbonReceipt = { _, _ in }
        self.action = { _, hotKeyAction in action(hotKeyAction) }
        self.registrationOverride = registrationOverride
        self.unregistrationObserver = unregistrationObserver
    }

    func register() -> DiagnosticHotKeyRegistrationStatus {
        if registeredActions.count == DiagnosticHotKeyAction.allCases.count {
            lastRegistrationStatus = .success
            return .success
        }
        unregister()

        if registrationOverride != nil {
            return registerSyntheticHotKeys()
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            diagnosticHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            let status = DiagnosticHotKeyRegistrationStatus(
                visibility: handlerStatus,
                lock: handlerStatus
            )
            lastRegistrationStatus = status
            return status
        }

        let visibilityStatus = register(.visibility)
        guard visibilityStatus == noErr else {
            unregister()
            let status = DiagnosticHotKeyRegistrationStatus(
                visibility: visibilityStatus,
                lock: OSStatus(eventNotHandledErr)
            )
            lastRegistrationStatus = status
            return status
        }

        let lockStatus = register(.lock)
        let status = DiagnosticHotKeyRegistrationStatus(
            visibility: visibilityStatus,
            lock: lockStatus
        )
        if !status.allRegistered { unregister() }
        lastRegistrationStatus = status
        return status
    }

    func unregister() {
        for hotKey in hotKeys.values {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll(keepingCapacity: false)
        for action in registeredActions {
            unregistrationObserver?(action)
        }
        registeredActions.removeAll(keepingCapacity: false)
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    var registeredActionCount: Int { registeredActions.count }

    private func registerSyntheticHotKeys() -> DiagnosticHotKeyRegistrationStatus {
        let visibilityStatus =
            registrationOverride?(.visibility)
            ?? OSStatus(eventNotHandledErr)
        if visibilityStatus == noErr { registeredActions.insert(.visibility) }
        guard visibilityStatus == noErr else {
            unregister()
            let status = DiagnosticHotKeyRegistrationStatus(
                visibility: visibilityStatus,
                lock: OSStatus(eventNotHandledErr)
            )
            lastRegistrationStatus = status
            return status
        }

        let lockStatus = registrationOverride?(.lock) ?? OSStatus(eventNotHandledErr)
        if lockStatus == noErr { registeredActions.insert(.lock) }
        let status = DiagnosticHotKeyRegistrationStatus(
            visibility: visibilityStatus,
            lock: lockStatus
        )
        if !status.allRegistered { unregister() }
        lastRegistrationStatus = status
        return status
    }

    private func register(_ hotKeyAction: DiagnosticHotKeyAction) -> OSStatus {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: diagnosticHotKeySignature,
            id: hotKeyAction.rawValue
        )
        let status = RegisterEventHotKey(
            hotKeyAction.virtualKeyCode,
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr, let reference {
            hotKeys[hotKeyAction] = reference
            registeredActions.insert(hotKeyAction)
        }
        return status
    }

    fileprivate nonisolated func receiveCarbonEvent(identifier: EventHotKeyID) -> OSStatus {
        guard
            identifier.signature == diagnosticHotKeySignature,
            let hotKeyAction = DiagnosticHotKeyAction(rawValue: identifier.id)
        else {
            return OSStatus(eventNotHandledErr)
        }
        receiveCarbonEvent(action: hotKeyAction)
        return noErr
    }

    private nonisolated func receiveCarbonEvent(action hotKeyAction: DiagnosticHotKeyAction) {
        let correlationID = UUID()
        carbonReceipt(correlationID, hotKeyAction)
        DispatchQueue.main.async { [weak self] in
            self?.invoke(correlationID: correlationID, action: hotKeyAction)
        }
    }

    fileprivate func invoke(
        correlationID: UUID,
        action hotKeyAction: DiagnosticHotKeyAction
    ) {
        action(correlationID, hotKeyAction)
    }

    func invokeForTesting(_ hotKeyAction: DiagnosticHotKeyAction = .visibility) {
        invoke(correlationID: UUID(), action: hotKeyAction)
    }

    nonisolated func receiveCarbonEventForTesting(
        _ hotKeyAction: DiagnosticHotKeyAction = .visibility
    ) {
        receiveCarbonEvent(action: hotKeyAction)
    }

    nonisolated func decodeForTesting(id: UInt32, signature: OSType) -> DiagnosticHotKeyAction? {
        guard signature == diagnosticHotKeySignature else { return nil }
        return DiagnosticHotKeyAction(rawValue: id)
    }
}
#endif
