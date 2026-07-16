import Carbon.HIToolbox
import Darwin
import Dispatch
import Foundation

private let expectedAction = "toggleVisibility"
private let readyLine = "READY action=toggleVisibility status=0\n"

private final class CollisionHolder: @unchecked Sendable {
    private var reference: EventHotKeyRef?

    func register() -> OSStatus {
        var proposedReference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x50504D34), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &proposedReference
        )
        if status == noErr {
            reference = proposedReference
        }
        return status
    }

    func unregister() -> OSStatus {
        guard let reference else { return noErr }
        let status = UnregisterEventHotKey(reference)
        if status == noErr {
            self.reference = nil
        }
        return status
    }
}

private func fail(_ message: String) -> Never {
    fputs("error: \(message)\n", stderr)
    exit(EXIT_FAILURE)
}

guard CommandLine.arguments.count == 5,
      CommandLine.arguments[1] == "--action",
      CommandLine.arguments[2] == expectedAction,
      CommandLine.arguments[3] == "--ready-file"
else {
    fail("expected --action toggleVisibility --ready-file PATH")
}

let holder = CollisionHolder()
guard holder.register() == noErr else {
    fail("could not own the requested public Carbon chord")
}

do {
    try readyLine.write(
        toFile: CommandLine.arguments[4],
        atomically: true,
        encoding: .utf8
    )
} catch {
    _ = holder.unregister()
    fail("could not write the readiness marker")
}

signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)

let signals = [SIGTERM, SIGINT].map { signalNumber in
    let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
    source.setEventHandler {
        exit(holder.unregister() == noErr ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    source.resume()
    return source
}

withExtendedLifetime(signals) {
    dispatchMain()
}
