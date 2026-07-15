import Foundation

enum ControllerTopologyStatus: String, CaseIterable, Equatable, Sendable {
    case extended
    case mirrored
    case single
    case missing
    case ambiguous
    case queryFailure
}

enum ControllerControl: Hashable, Sendable {
    case title
    case editor
    case clear
    case openClose
    case hideShow
    case lock
    case displaySelection
    case fontSize
    case alignment
    case activeBand
    case start
    case pause
    case restart
    case speed
    case back
    case forward
    case focusMode
}

struct ControllerPresentation: Equatable, Sendable {
    static let mirroringWarning =
        "Display mirroring is on. Students may see the teleprompter. Use Extended Display mode."
    static let mirroringRecoveryGuidance =
        "The script remains hidden. Turn off mirroring, then select and confirm the private display again."
    static let emptyScriptInstruction =
        "Paste or type a script to prepare the teleprompter."
    static let m3Explanation = "Smooth scrolling is available in M3."
    static let m4Explanation = "Focus Mode and product shortcuts are available in M4."
    let scriptText: String
    let isPanelVisible: Bool
    let isClearConfirmationRequired: Bool

    var isEmpty: Bool {
        scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var emptyInstruction: String? { isEmpty ? Self.emptyScriptInstruction : nil }
    var openCloseLabel: String { isPanelVisible ? "Close Teleprompter" : "Open Teleprompter" }
    var hideShowLabel: String { isPanelVisible ? "Hide Panel" : "Show Panel" }

    func isEnabled(_ control: ControllerControl) -> Bool {
        switch control {
        case .focusMode:
            false
        case .start, .pause, .restart, .speed, .back, .forward:
            !isEmpty
        case .clear:
            !isEmpty
        default:
            true
        }
    }

    func explanation(for control: ControllerControl) -> String? {
        switch control {
        case .start, .pause, .restart, .speed, .back, .forward:
            nil
        case .focusMode:
            Self.m4Explanation
        default:
            nil
        }
    }

    func productCommand(for control: ControllerControl) -> AppCommand? {
        switch control {
        case .openClose, .hideShow:
            isPanelVisible ? .hideOverlay : .showOverlay
        case .start:
            .start
        case .pause:
            .pause
        case .restart:
            .restart
        case .back:
            .moveBackward
        case .forward:
            .moveForward
        default:
            nil
        }
    }

    static func selectedDisplayStatus(
        name: String?,
        isConfirmedInCurrentSession: Bool
    ) -> String {
        guard isConfirmedInCurrentSession, let name else {
            return "No private display confirmed for this session"
        }
        return "Private display confirmed: \(name)"
    }

    static func topologyLabel(for status: ControllerTopologyStatus) -> String {
        switch status {
        case .extended:
            "Extended display mode is available"
        case .mirrored:
            "Display mirroring is unsafe"
        case .single:
            "Only one display is online"
        case .missing:
            "The selected private display is missing"
        case .ambiguous:
            "Display identity is ambiguous — select and confirm the private display"
        case .queryFailure:
            "Display safety could not be verified"
        }
    }
}
