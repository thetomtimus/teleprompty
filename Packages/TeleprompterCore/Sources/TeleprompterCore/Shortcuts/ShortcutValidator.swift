import Foundation

public extension ShortcutAction {
    static let stableOrder: [ShortcutAction] = [
        .togglePlayback,
        .increaseSpeed,
        .decreaseSpeed,
        .moveBackward,
        .moveForward,
        .toggleVisibility,
        .toggleLock,
    ]

    var stableIndex: Int {
        Self.stableOrder.firstIndex(of: self)!
    }
}

public enum ShortcutViolation: Equatable, Sendable {
    case missingAction(action: ShortcutAction)
    case duplicateAction(action: ShortcutAction)
    case duplicateChord(actions: [ShortcutAction], shortcut: KeyboardShortcut)
    case modifierRequired(action: ShortcutAction)
    case bareReservedKey(action: ShortcutAction, keyCode: UInt16)
    case unknownActionCoverage
}

public struct ShortcutValidationError: Error, Equatable, Sendable {
    public let violations: [ShortcutViolation]

    public init(violations: [ShortcutViolation]) {
        self.violations = violations
    }
}

public enum ShortcutValidator {
    private static let reservedBareKeyCodes: Set<UInt16> = [49, 123, 124, 125, 126]

    public static var defaultBindings: [ShortcutBinding] {
        ShortcutAction.stableOrder.map { action in
            ShortcutBinding(action: action, shortcut: KeyboardShortcut.defaultMap[action]!)
        }
    }

    public static func validate(_ bindings: [ShortcutBinding]) throws -> [ShortcutBinding] {
        var violations: [ShortcutViolation] = []

        for action in ShortcutAction.stableOrder {
            let matching = bindings.filter { $0.action == action }
            if matching.isEmpty {
                violations.append(.missingAction(action: action))
            } else if matching.count > 1 {
                violations.append(.duplicateAction(action: action))
            }
        }

        if bindings.count != ShortcutAction.stableOrder.count,
            violations.isEmpty
        {
            violations.append(.unknownActionCoverage)
        }

        for binding in bindings {
            guard binding.shortcut.modifiers.isEmpty else { continue }
            if reservedBareKeyCodes.contains(binding.shortcut.virtualKeyCode) {
                violations.append(
                    .bareReservedKey(
                        action: binding.action,
                        keyCode: binding.shortcut.virtualKeyCode
                    )
                )
            } else {
                violations.append(.modifierRequired(action: binding.action))
            }
        }

        var remainingIndices = Array(bindings.indices)
        while let firstIndex = remainingIndices.first {
            let shortcut = bindings[firstIndex].shortcut
            let matchingIndices = remainingIndices.filter {
                bindings[$0].shortcut == shortcut
            }
            let actions = Array(Set(matchingIndices.map { bindings[$0].action }))
                .sorted { $0.stableIndex < $1.stableIndex }
            if actions.count > 1 {
                violations.append(.duplicateChord(actions: actions, shortcut: shortcut))
            }
            let matched = Set(matchingIndices)
            remainingIndices.removeAll { matched.contains($0) }
        }

        guard violations.isEmpty else {
            throw ShortcutValidationError(violations: violations)
        }

        return bindings.sorted { $0.action.stableIndex < $1.action.stableIndex }
    }
}

public struct ShortcutRestoreResolution: Equatable, Sendable {
    public let snapshot: PersistedSnapshot
    public let usedDefaultBindings: Bool

    public init(snapshot: PersistedSnapshot, usedDefaultBindings: Bool) {
        self.snapshot = snapshot
        self.usedDefaultBindings = usedDefaultBindings
    }
}

public enum ShortcutRestorePolicy {
    public static func resolve(_ snapshot: PersistedSnapshot) -> ShortcutRestoreResolution {
        let bindings: [ShortcutBinding]
        let usedDefaults: Bool
        do {
            bindings = try ShortcutValidator.validate(snapshot.shortcutBindings)
            usedDefaults = false
        } catch {
            bindings = ShortcutValidator.defaultBindings
            usedDefaults = true
        }

        return ShortcutRestoreResolution(
            snapshot: PersistedSnapshot(
                schemaVersion: snapshot.schemaVersion,
                revision: snapshot.revision,
                document: snapshot.document,
                readingAnchor: snapshot.readingAnchor,
                preferences: snapshot.preferences,
                panelFrames: snapshot.panelFrames,
                shortcutBindings: bindings
            ),
            usedDefaultBindings: usedDefaults
        )
    }
}

public enum ShortcutCustomizationAvailability {
    public static let isEnabledByDefault = false
}
