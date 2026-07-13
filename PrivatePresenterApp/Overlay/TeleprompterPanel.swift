import AppKit

enum OverlayPanelLevel: String, Codable, CaseIterable, Sendable {
    case floating
    case statusBar

    @MainActor var appKitLevel: NSWindow.Level {
        switch self {
        case .floating: .floating
        case .statusBar: .statusBar
        }
    }
}

#if DEBUG
enum OverlayPanelOrderingMode: String, Codable, CaseIterable, Sendable {
    case front
    case frontRegardless
}

struct OverlayConfigurationCandidate: Equatable, Sendable {
    let level: OverlayPanelLevel
    let ordering: OverlayPanelOrderingMode
    let completePass: Bool
    let activationTransitions: Int
    let controllerPresentationOperations: Int
    let panelKeyMainTransitions: Int
    let missedVisibilitySamples: Int

    var safetyVector: [Int] {
        [
            activationTransitions,
            controllerPresentationOperations,
            panelKeyMainTransitions,
            missedVisibilitySamples,
        ]
    }
}

enum OverlayConfigurationSelector {
    static func select(
        from candidates: [OverlayConfigurationCandidate],
        sourceDefaultLevel: OverlayPanelLevel = .statusBar,
        sourceDefaultOrdering: OverlayPanelOrderingMode = .frontRegardless
    ) -> OverlayConfigurationCandidate? {
        let passing = candidates.filter(\.completePass)
        guard !passing.isEmpty else { return nil }
        return passing.min { lhs, rhs in
            if lhs.safetyVector != rhs.safetyVector {
                return lhs.safetyVector.lexicographicallyPrecedes(rhs.safetyVector)
            }
            let lhsDefault = lhs.level == sourceDefaultLevel
                && lhs.ordering == sourceDefaultOrdering
            let rhsDefault = rhs.level == sourceDefaultLevel
                && rhs.ordering == sourceDefaultOrdering
            if lhsDefault != rhsDefault { return lhsDefault }
            if lhs.level != rhs.level { return lhs.level == .floating }
            if lhs.ordering != rhs.ordering { return lhs.ordering == sourceDefaultOrdering }
            return false
        }
    }
}
#endif

/// The single AppKit-owned overlay. The nonopaque window exists only to permit clear
/// pixels outside the rounded card; the hosted card itself always paints an opaque fill.
@MainActor
class TeleprompterPanel: NSPanel {
    private(set) var isOverlayLocked = false
    var containmentFrame: NSRect?

    init(contentRect: NSRect, proofLevel: OverlayPanelLevel = .statusBar) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = proofLevel.appKitLevel
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        animationBehavior = .none
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool {
        !isOverlayLocked && NSApp.isActive
    }

    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let containmentFrame else {
            return super.constrainFrameRect(frameRect, to: screen)
        }
        return ClampedPanelInteractionController.clamp(
            frameRect,
            inside: containmentFrame,
            minimumSize: NSSize(width: 320, height: 180),
            maximumSize: containmentFrame.size
        )
    }

    func setLocked(_ locked: Bool) {
        isOverlayLocked = locked
        ignoresMouseEvents = locked
        if locked, isKeyWindow {
            resignKey()
        }
    }
}
