import Foundation

public enum ShortcutAction: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case togglePlayback
    case increaseSpeed
    case decreaseSpeed
    case moveBackward
    case moveForward
    case toggleVisibility
    case toggleLock
}

public enum ShortcutModifier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case control = "Control"
    case option = "Option"
    case shift = "Shift"
    case command = "Command"
}

public enum KeyboardShortcutCodingError: Error, Equatable, Sendable {
    case duplicateModifier
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public var virtualKeyCode: UInt16
    public var modifiers: Set<ShortcutModifier>

    public init(virtualKeyCode: UInt16, modifiers: Set<ShortcutModifier>) {
        self.virtualKeyCode = virtualKeyCode
        self.modifiers = modifiers
    }

    public static let defaultMap: [ShortcutAction: KeyboardShortcut] = {
        let modifiers: Set<ShortcutModifier> = [.control, .option]
        return [
            .togglePlayback: KeyboardShortcut(virtualKeyCode: 49, modifiers: modifiers),
            .increaseSpeed: KeyboardShortcut(virtualKeyCode: 126, modifiers: modifiers),
            .decreaseSpeed: KeyboardShortcut(virtualKeyCode: 125, modifiers: modifiers),
            .moveBackward: KeyboardShortcut(virtualKeyCode: 123, modifiers: modifiers),
            .moveForward: KeyboardShortcut(virtualKeyCode: 124, modifiers: modifiers),
            .toggleVisibility: KeyboardShortcut(virtualKeyCode: 4, modifiers: modifiers),
            .toggleLock: KeyboardShortcut(virtualKeyCode: 37, modifiers: modifiers),
        ]
    }()

    private enum CodingKeys: String, CodingKey {
        case virtualKeyCode
        case modifiers
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(virtualKeyCode, forKey: .virtualKeyCode)
        try container.encode(modifiers.sorted { $0.rawValue < $1.rawValue }, forKey: .modifiers)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        virtualKeyCode = try container.decode(UInt16.self, forKey: .virtualKeyCode)
        let decodedModifiers = try container.decode([ShortcutModifier].self, forKey: .modifiers)
        let modifierSet = Set(decodedModifiers)
        guard modifierSet.count == decodedModifiers.count else {
            throw KeyboardShortcutCodingError.duplicateModifier
        }
        modifiers = modifierSet
    }
}
