import AppKit
import Foundation
import SwiftUI
import TeleprompterCore

enum PresenterAccessibility {
    static let fontSizeRange: ClosedRange<Double> = 24...96
    static let fontSizeStep = 2.0
    static let speedRange: ClosedRange<Double> = 10...240
    static let speedStep = 5.0

    struct State {
        let scriptTitle: String
        let scriptText: String
        let displayName: String
        let fontSizePoints: Double
        let speedPointsPerSecond: Double
        let alignment: TeleprompterTextAlignment
        let isActiveBandEnabled: Bool
        let isPlaying: Bool
        let isVisible: Bool
        let isLocked: Bool
        let isFocusModeEnabled: Bool
        let retryShortcutsVisible: Bool
        let topologyStatus: ControllerTopologyStatus
    }

    struct Entry {
        let identifier: String
        let label: String
        let value: String
        let help: String
        let toolTip: String
        let isControl: Bool
        let isDynamic: Bool
        let isPublicSurface: Bool
        let isReadOnly: Bool
        let requiresConfirmedPrivateOverlay: Bool
        let isIgnored: Bool
        let minimumHitSize: CGSize

        init(
            _ identifier: String,
            label: String,
            value: String = "",
            help: String,
            toolTip: String? = nil,
            isControl: Bool = true,
            isDynamic: Bool = false,
            isPublicSurface: Bool = false,
            isReadOnly: Bool = false,
            requiresConfirmedPrivateOverlay: Bool = false,
            isIgnored: Bool = false,
            minimumHitSize: CGSize = .zero
        ) {
            self.identifier = identifier
            self.label = label
            self.value = value
            self.help = help
            self.toolTip = toolTip ?? help
            self.isControl = isControl
            self.isDynamic = isDynamic
            self.isPublicSurface = isPublicSurface
            self.isReadOnly = isReadOnly
            self.requiresConfirmedPrivateOverlay = requiresConfirmedPrivateOverlay
            self.isIgnored = isIgnored
            self.minimumHitSize = minimumHitSize
        }
    }

    struct WarningFocusDecision: Equatable {
        let shouldMoveFocus: Bool
        let shouldActivateApplication: Bool
        let consumedGeneration: Int?
    }

    struct MotionPolicy: Equatable {
        let decorativeFocusDuration: TimeInterval
        let readingMotionEnabled: Bool
    }

    static let shieldTraversal = [
        "privatePresenter.privateDisplayPicker",
        "privatePresenter.confirmPrivateDisplay",
        "privatePresenter.keepScriptHidden",
    ]

    static func controllerTraversal(retryShortcutsVisible: Bool) -> [String] {
        var identifiers = [
            "privatePresenter.scriptTitle",
            "privatePresenter.scriptEditor",
            "privatePresenter.openClose",
            "privatePresenter.hideShow",
            "privatePresenter.lock",
            "privatePresenter.clear",
            "privatePresenter.fontSize",
            "privatePresenter.alignment",
            "privatePresenter.activeBand",
            "privatePresenter.start",
            "privatePresenter.pause",
            "privatePresenter.restart",
            "privatePresenter.back",
            "privatePresenter.forward",
            "privatePresenter.speed",
            "privatePresenter.focusMode",
        ]
        if retryShortcutsVisible {
            identifiers.append("privatePresenter.retryShortcuts")
        }
        return identifiers
    }

    static func controllerReverseTraversal(retryShortcutsVisible: Bool) -> [String] {
        Array(controllerTraversal(retryShortcutsVisible: retryShortcutsVisible).reversed())
    }

    static func manifest(state: State) -> [Entry] {
        let alignment = state.alignment == .center ? "Center" : "Left"
        let playbackState = state.isPlaying ? "Playing" : "Paused"
        let visibilityState = state.isVisible ? "Visible" : "Hidden"
        let lockState = state.isLocked ? "Locked" : "Unlocked"
        let bandState = state.isActiveBandEnabled ? "On" : "Off"
        let focusState = state.isFocusModeEnabled ? "On" : "Off"
        let safetyState = genericSafetyState(state.topologyStatus)
        let overlayTarget = CGSize(width: 44, height: 44)

        return [
            Entry(
                "privatePresenter.privateDisplayPicker",
                label: "Private display",
                value: state.displayName.isEmpty ? "Selection required" : state.displayName,
                help: "Choose the display only you can see",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.confirmPrivateDisplay",
                label: "Confirm private display",
                value: "Not confirmed",
                help: "Confirm the selected display for this session",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.keepScriptHidden",
                label: "Keep script hidden",
                value: "Script hidden",
                help: "Keep the editor and teleprompter hidden",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.scriptTitle",
                label: "Script title",
                help: "Edit the local script title"
            ),
            Entry(
                "privatePresenter.scriptEditor",
                label: "Script editor",
                help: "Edit the local teleprompter script"
            ),
            Entry(
                "privatePresenter.openClose",
                label: state.isVisible ? "Close teleprompter" : "Open teleprompter",
                value: visibilityState,
                help: state.isVisible
                    ? "Close the teleprompter on the private display"
                    : "Open the teleprompter on the confirmed private display",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.hideShow",
                label: state.isVisible ? "Hide teleprompter" : "Show teleprompter",
                value: visibilityState,
                help: state.isVisible
                    ? "Hide the teleprompter immediately"
                    : "Show the teleprompter on the confirmed private display",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.lock",
                label: state.isLocked ? "Unlock teleprompter" : "Lock teleprompter",
                value: lockState,
                help: state.isLocked
                    ? "Unlock teleprompter pointer interaction"
                    : "Lock the teleprompter against pointer interaction",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.clear",
                label: "Clear script",
                help: "Ask for confirmation before clearing the local script"
            ),
            Entry(
                "privatePresenter.fontSize",
                label: "Font size",
                value: "\(Int(state.fontSizePoints)) points",
                help: "Adjust teleprompter font size from 24 to 96 points",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.alignment",
                label: "Text alignment",
                value: alignment,
                help: "Choose Left or Center text alignment",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.activeBand",
                label: "Active band",
                value: bandState,
                help: state.isActiveBandEnabled
                    ? "Turn off the active reading band"
                    : "Turn on the active reading band",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.start",
                label: "Start scrolling",
                value: playbackState,
                help: "Start continuous teleprompter scrolling",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.pause",
                label: "Pause scrolling",
                value: playbackState,
                help: "Pause teleprompter scrolling",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.restart",
                label: "Restart script",
                value: playbackState,
                help: "Return to the beginning and remain paused",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.back",
                label: "Move back",
                help: "Move the script back by three laid-out lines"
            ),
            Entry(
                "privatePresenter.forward",
                label: "Move forward",
                help: "Move the script forward by three laid-out lines"
            ),
            Entry(
                "privatePresenter.speed",
                label: "Scroll speed",
                value: "\(Int(state.speedPointsPerSecond)) points per second",
                help: "Adjust scroll speed from 10 to 240 points per second",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.focusMode",
                label: "Focus mode",
                value: focusState,
                help: state.isFocusModeEnabled
                    ? "Turn off automatic chrome hiding"
                    : "Turn on automatic chrome hiding",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.retryShortcuts",
                label: "Retry shortcuts",
                value: state.retryShortcutsVisible ? "Available" : "Unavailable",
                help: "Retry registration of the fixed global shortcuts",
                isDynamic: true
            ),
            Entry(
                "privatePresenter.overlayPlayback",
                label: state.isPlaying ? "Pause scrolling" : "Start scrolling",
                value: playbackState,
                help: state.isPlaying ? "Pause scrolling" : "Start scrolling",
                isDynamic: true,
                minimumHitSize: overlayTarget
            ),
            Entry(
                "privatePresenter.overlayVisibility",
                label: state.isVisible ? "Hide teleprompter" : "Show teleprompter",
                value: visibilityState,
                help: state.isVisible ? "Hide the teleprompter" : "Show the teleprompter",
                isDynamic: true,
                minimumHitSize: overlayTarget
            ),
            Entry(
                "privatePresenter.overlayLock",
                label: state.isLocked ? "Unlock teleprompter" : "Lock teleprompter",
                value: lockState,
                help: state.isLocked ? "Unlock pointer interaction" : "Lock pointer interaction",
                isDynamic: true,
                minimumHitSize: overlayTarget
            ),
            Entry(
                "privatePresenter.statusItem",
                label: "Private Presenter",
                value: "Controls available",
                help: "Open generic Private Presenter controls",
                isDynamic: true,
                isPublicSurface: true
            ),
            publicMenuEntry(
                "privatePresenter.menuShowController",
                label: "Show Controller",
                help: "Show the existing controller"
            ),
            publicMenuEntry(
                "privatePresenter.menuPlayback",
                label: state.isPlaying ? "Pause" : "Start",
                value: playbackState,
                help: state.isPlaying ? "Pause scrolling" : "Start scrolling"
            ),
            publicMenuEntry(
                "privatePresenter.menuVisibility",
                label: state.isVisible ? "Hide Teleprompter" : "Show Teleprompter",
                value: visibilityState,
                help: state.isVisible ? "Hide the teleprompter" : "Show the teleprompter"
            ),
            publicMenuEntry(
                "privatePresenter.menuLock",
                label: state.isLocked ? "Unlock" : "Lock",
                value: lockState,
                help: state.isLocked ? "Unlock pointer interaction" : "Lock pointer interaction"
            ),
            publicMenuEntry(
                "privatePresenter.menuQuit",
                label: "Quit",
                help: "Save paused state and quit Private Presenter"
            ),
            Entry(
                "privatePresenter.displaySafetyStatus",
                label: "Display safety: \(safetyState)",
                value: safetyState,
                help: "Review display safety before revealing the controller",
                isControl: false,
                isDynamic: true
            ),
            Entry(
                "privatePresenter.displaySafetyIcon",
                label: "Display safety status",
                value: safetyState,
                help: "Visible display safety indicator",
                isControl: false,
                isDynamic: true
            ),
            Entry(
                "privatePresenter.reader",
                label: "Teleprompter script",
                help: "Read-only script on the confirmed private overlay",
                isControl: false,
                isReadOnly: true,
                requiresConfirmedPrivateOverlay: true
            ),
        ] + ignoredEntries
    }

    @MainActor
    static func state(model: AppModel) -> State {
        State(
            scriptTitle: model.document.title,
            scriptText: model.document.text,
            displayName: model.selectedDisplayName,
            fontSizePoints: model.preferences.fontSizePoints,
            speedPointsPerSecond: model.preferences.speedPointsPerSecond,
            alignment: model.preferences.textAlignment,
            isActiveBandEnabled: model.preferences.isActiveBandEnabled,
            isPlaying: !model.isPaused,
            isVisible: model.overlaySession.visibility == .visible,
            isLocked: model.isLocked,
            isFocusModeEnabled: model.preferences.isFocusModeEnabled,
            retryShortcutsVisible: retryShortcutsVisible(model.hotKeyStatus),
            topologyStatus: model.topologyStatus
        )
    }

    @MainActor
    static func publicState(model: AppModel) -> State {
        State(
            scriptTitle: "",
            scriptText: "",
            displayName: "",
            fontSizePoints: 42,
            speedPointsPerSecond: 60,
            alignment: .center,
            isActiveBandEnabled: true,
            isPlaying: !model.isPaused,
            isVisible: model.overlaySession.visibility == .visible,
            isLocked: model.isLocked,
            isFocusModeEnabled: true,
            retryShortcutsVisible: false,
            topologyStatus: .queryFailure
        )
    }

    static func warningFocusDecision(
        unsafeGeneration: Int,
        lastFocusedGeneration: Int?,
        controllerIsActive: Bool
    ) -> WarningFocusDecision {
        let shouldMove = controllerIsActive && lastFocusedGeneration != unsafeGeneration
        return WarningFocusDecision(
            shouldMoveFocus: shouldMove,
            shouldActivateApplication: false,
            consumedGeneration: shouldMove ? unsafeGeneration : nil
        )
    }

    static func motionPolicy(reduceMotion: Bool) -> MotionPolicy {
        MotionPolicy(
            decorativeFocusDuration: reduceMotion ? 0 : 0.18,
            readingMotionEnabled: true
        )
    }

    static func entry(_ identifier: String, state: State) -> Entry {
        guard let entry = manifest(state: state).first(where: { $0.identifier == identifier }) else {
            preconditionFailure("Unknown presenter accessibility identifier")
        }
        return entry
    }

    static func staticEntry(_ identifier: String) -> Entry {
        entry(
            identifier,
            state: State(
                scriptTitle: "",
                scriptText: "",
                displayName: "",
                fontSizePoints: 42,
                speedPointsPerSecond: 60,
                alignment: .center,
                isActiveBandEnabled: true,
                isPlaying: false,
                isVisible: false,
                isLocked: true,
                isFocusModeEnabled: true,
                retryShortcutsVisible: false,
                topologyStatus: .queryFailure
            )
        )
    }

    static func genericSafetyState(_ status: ControllerTopologyStatus) -> String {
        switch status {
        case .extended:
            "Extended display available"
        case .mirrored:
            "Mirroring is unsafe"
        case .single:
            "Audience separation unavailable"
        case .missing:
            "Private display missing"
        case .ambiguous:
            "Display identity ambiguous"
        case .queryFailure:
            "Safety could not be verified"
        }
    }

    private static func retryShortcutsVisible(_ status: HotKeyTransactionResult?) -> Bool {
        guard let status else { return false }
        switch status {
        case .conflict, .degradedClean:
            true
        case .committed, .cleanupUnknown, .invalid:
            false
        }
    }

    private static func publicMenuEntry(
        _ identifier: String,
        label: String,
        value: String = "Available",
        help: String
    ) -> Entry {
        Entry(
            identifier,
            label: label,
            value: value,
            help: help,
            isDynamic: true,
            isPublicSurface: true
        )
    }

    private static let ignoredEntries = [
        "privatePresenter.readerBand",
        "privatePresenter.readerBackground",
        "privatePresenter.overlayDragZone",
        "privatePresenter.resizeTop",
        "privatePresenter.resizeBottom",
        "privatePresenter.resizeLeft",
        "privatePresenter.resizeRight",
        "privatePresenter.resizeTopLeft",
        "privatePresenter.resizeTopRight",
        "privatePresenter.resizeBottomLeft",
        "privatePresenter.resizeBottomRight",
    ].map {
        Entry(
            $0,
            label: "",
            help: "",
            isControl: false,
            isIgnored: true
        )
    }
}

extension View {
    @ViewBuilder
    func presenterAccessibility(
        _ entry: PresenterAccessibility.Entry
    ) -> some View {
        let described = accessibilityIdentifier(entry.identifier)
            .accessibilityLabel(Text(entry.label))
            .accessibilityHint(Text(entry.help))
            .help(entry.toolTip)
        if entry.value.isEmpty {
            described
        } else {
            described.accessibilityValue(Text(entry.value))
        }
    }
}

enum M5ApplicationSupportRootPolicy {
    static func resolve(
        environment: [String: String],
        isDebugBuild: Bool,
        normalRoot: URL,
        temporaryDirectory: URL,
        fileManager: FileManager
    ) -> URL {
        guard isDebugBuild,
            environment["PRIVATE_PRESENTER_UI_TEST"] == "1",
            let configuration = environment["XCTestConfigurationFilePath"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !configuration.isEmpty,
            let rawOverride = environment["PRIVATE_PRESENTER_UI_TEST_STORE_ROOT"],
            !rawOverride.isEmpty,
            !rawOverride.split(separator: "/", omittingEmptySubsequences: false)
                .contains("..")
        else { return normalRoot }

        let temporary = temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = URL(fileURLWithPath: rawOverride, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard isStrictDescendant(candidate, of: temporary),
            fileManager.fileExists(atPath: candidate.path)
        else { return normalRoot }
        return candidate
    }

    private static func isStrictDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let parentComponents = parent.pathComponents
        let candidateComponents = candidate.pathComponents
        return candidateComponents.count > parentComponents.count
            && Array(candidateComponents.prefix(parentComponents.count)) == parentComponents
    }
}
