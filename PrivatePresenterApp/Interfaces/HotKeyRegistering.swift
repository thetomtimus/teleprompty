import Foundation
import TeleprompterCore

struct HotKeyHandlerToken: Equatable, Hashable, Sendable {
    let rawValue: UInt64
}

struct HotKeyToken: Equatable, Hashable, Sendable {
    let rawValue: UInt64
}

enum HotKeyAttemptOperation: Equatable, Sendable {
    case installHandler
    case initialRegistration
    case oldUnregistration
    case proposedRegistration
    case rollbackRegistration
}

struct HotKeyAttemptStatus: Equatable, Sendable {
    let operation: HotKeyAttemptOperation
    let action: ShortcutAction
    let shortcut: KeyboardShortcut
    let status: Int32
}

enum HotKeyCallResult<Value> {
    case success(Value)
    case failure(Int32)
}

extension HotKeyCallResult: Equatable where Value: Equatable {}

struct ProductHotKeyIdentifier: Equatable, Sendable {
    static let signature: UInt32 = 0x5050_4D34

    let rawSignature: UInt32
    let id: UInt32

    init(signature: UInt32, id: UInt32) {
        rawSignature = signature
        self.id = id
    }

    init(action: ShortcutAction) {
        rawSignature = Self.signature
        id = UInt32(action.stableIndex + 1)
    }

    var action: ShortcutAction? {
        guard rawSignature == Self.signature, (1...7).contains(id) else { return nil }
        return ShortcutAction.stableOrder[Int(id - 1)]
    }
}

@MainActor
protocol HotKeyRegistering: AnyObject {
    func installHandler(
        callback: @escaping @MainActor (ProductHotKeyIdentifier) -> Int32
    ) -> HotKeyCallResult<HotKeyHandlerToken>

    func register(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        identifier: ProductHotKeyIdentifier
    ) -> HotKeyCallResult<HotKeyToken>

    func unregister(_ token: HotKeyToken) -> Int32
    func removeHandler(_ token: HotKeyHandlerToken) -> Int32
}

enum HotKeyStartupMode: Equatable, Sendable {
    case product
    case legacyDiagnostic

    static func resolve(
        productEnabled: Bool,
        legacyProofEnabled: Bool
    ) -> HotKeyStartupMode? {
        switch (productEnabled, legacyProofEnabled) {
        case (true, false): .product
        case (false, true): .legacyDiagnostic
        case (false, false), (true, true): nil
        }
    }
}
