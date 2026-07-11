#if DEBUG
import Carbon.HIToolbox
import Dispatch

private let diagnosticHotKeyEventHandler: EventHandlerUPP = {
    _, _, userInfo in
    guard let userInfo else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<DiagnosticHotKeyService>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    DispatchQueue.main.async {
        service.invoke()
    }
    return noErr
}

/// One DEBUG-only proof chord. Product hotkey registration remains deferred to M4.
@MainActor
final class DiagnosticHotKeyService {
    static let chordDescription = "Control-Option-H"

    private let action: @MainActor () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func register() -> OSStatus {
        guard hotKey == nil else { return noErr }
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
        guard handlerStatus == noErr else { return handlerStatus }

        let identifier = EventHotKeyID(signature: 0x5050_5452, id: 1)
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if registrationStatus != noErr {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
            }
            self.eventHandler = nil
        }
        return registrationStatus
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        hotKey = nil
        eventHandler = nil
    }

    fileprivate func invoke() {
        action()
    }
}
#endif
