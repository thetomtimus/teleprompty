import AppKit
import SwiftUI
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class PresenterAccessibilityTests: XCTestCase {
    private let fileManager = FileManager.default
    private var testContainer: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testContainer = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "private-presenter-m5-root-policy-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: testContainer,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testContainer {
            try? fileManager.removeItem(at: testContainer)
        }
        try super.tearDownWithError()
    }

    func testAccessibilityManifestContainsEveryActionExactlyOnce() {
        let manifest = PresenterAccessibility.manifest(state: accessibilityState())
        let identifiers = manifest.filter(\.isControl).map(\.identifier)
        let expected = [
            "privatePresenter.privateDisplayPicker",
            "privatePresenter.confirmPrivateDisplay",
            "privatePresenter.keepScriptHidden",
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
            "privatePresenter.retryShortcuts",
            "privatePresenter.overlayPlayback",
            "privatePresenter.overlayVisibility",
            "privatePresenter.overlayLock",
            "privatePresenter.statusItem",
            "privatePresenter.menuShowController",
            "privatePresenter.menuPlayback",
            "privatePresenter.menuVisibility",
            "privatePresenter.menuLock",
            "privatePresenter.menuQuit",
        ]

        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(Set(identifiers), Set(expected))
        XCTAssertEqual(identifiers.count, expected.count)
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("privatePresenter.") })
    }

    func testEveryDynamicControlExposesLabelValueHelpAndIdentifier() throws {
        let manifest = PresenterAccessibility.manifest(state: accessibilityState())
        let dynamicEntries = manifest.filter(\.isDynamic)
        XCTAssertFalse(dynamicEntries.isEmpty)
        for entry in dynamicEntries {
            XCTAssertTrue(entry.identifier.hasPrefix("privatePresenter."), entry.identifier)
            XCTAssertFalse(entry.label.isEmpty, entry.identifier)
            XCTAssertFalse(entry.value.isEmpty, entry.identifier)
            XCTAssertFalse(entry.help.isEmpty, entry.identifier)
            XCTAssertFalse(entry.label.lowercased().contains("button"), entry.identifier)
            XCTAssertFalse(entry.label.lowercased().contains("slider"), entry.identifier)
        }

        XCTAssertEqual(try entry("privatePresenter.fontSize", in: manifest).label, "Font size")
        XCTAssertEqual(try entry("privatePresenter.fontSize", in: manifest).value, "42 points")
        XCTAssertEqual(try entry("privatePresenter.speed", in: manifest).label, "Scroll speed")
        XCTAssertEqual(
            try entry("privatePresenter.speed", in: manifest).value,
            "60 points per second"
        )
        XCTAssertEqual(try entry("privatePresenter.alignment", in: manifest).value, "Center")
        XCTAssertEqual(try entry("privatePresenter.activeBand", in: manifest).value, "On")
        XCTAssertEqual(try entry("privatePresenter.focusMode", in: manifest).value, "On")
        XCTAssertEqual(try entry("privatePresenter.start", in: manifest).value, "Paused")
        XCTAssertEqual(try entry("privatePresenter.hideShow", in: manifest).value, "Hidden")
        XCTAssertEqual(try entry("privatePresenter.lock", in: manifest).value, "Locked")
        XCTAssertEqual(PresenterAccessibility.fontSizeRange, 24...96)
        XCTAssertEqual(PresenterAccessibility.fontSizeStep, 2)
        XCTAssertEqual(PresenterAccessibility.speedRange, 10...240)
        XCTAssertEqual(PresenterAccessibility.speedStep, 5)

        let title = try entry("privatePresenter.scriptTitle", in: manifest)
        XCTAssertEqual(title.label, "Script title")
        let editor = try entry("privatePresenter.scriptEditor", in: manifest)
        XCTAssertEqual(editor.label, "Script editor")
        XCTAssertEqual(editor.help, "Edit the local teleprompter script")
        let reader = try entry("privatePresenter.reader", in: manifest)
        XCTAssertEqual(reader.label, "Teleprompter script")
        XCTAssertTrue(reader.isReadOnly)
        XCTAssertTrue(reader.requiresConfirmedPrivateOverlay)
    }

    func testControllerReverseTraversalHasNoTrap() {
        let expected = [
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
            "privatePresenter.retryShortcuts",
        ]

        let forward = PresenterAccessibility.controllerTraversal(
            retryShortcutsVisible: true
        )
        XCTAssertEqual(forward, expected)
        XCTAssertEqual(
            PresenterAccessibility.controllerReverseTraversal(
                retryShortcutsVisible: true
            ),
            Array(expected.reversed())
        )
        XCTAssertEqual(
            PresenterAccessibility.controllerTraversal(
                retryShortcutsVisible: false
            ),
            Array(expected.dropLast())
        )
        XCTAssertEqual(
            PresenterAccessibility.shieldTraversal,
            [
                "privatePresenter.privateDisplayPicker",
                "privatePresenter.confirmPrivateDisplay",
                "privatePresenter.keepScriptHidden",
            ]
        )
    }

    func testOverlayActionTargetsAreAtLeastFortyFourPoints() {
        let manifest = PresenterAccessibility.manifest(state: accessibilityState())
        let overlayIdentifiers = Set([
            "privatePresenter.overlayPlayback",
            "privatePresenter.overlayVisibility",
            "privatePresenter.overlayLock",
        ])
        let overlayActions = manifest.filter { overlayIdentifiers.contains($0.identifier) }

        XCTAssertEqual(Set(overlayActions.map(\.identifier)), overlayIdentifiers)
        XCTAssertFalse(overlayActions.isEmpty)
        for action in overlayActions {
            XCTAssertGreaterThanOrEqual(action.minimumHitSize.width, 44, action.identifier)
            XCTAssertGreaterThanOrEqual(action.minimumHitSize.height, 44, action.identifier)
            XCTAssertFalse(action.toolTip.isEmpty, action.identifier)
        }
    }

    func testHostedOverlayChromeBridgesHelpAndActualFortyFourPointFrames() {
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "synthetic hosted accessibility fixture"),
            restorationRequired: false
        )
        let hosting = NSHostingView(rootView: OverlayChromeView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 640, height: 80)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        let expectedLabels = Set(["Start", "Show", "Unlock"])
        let controls = hostedDescendants(of: hosting).filter {
            guard let label = $0.accessibilityLabel() else { return false }
            return expectedLabels.contains(label)
        }

        XCTAssertEqual(Set(controls.compactMap { $0.accessibilityLabel() }), expectedLabels)
        for control in controls {
            let actualFrame = control.convert(control.bounds, to: hosting)
            XCTAssertGreaterThanOrEqual(actualFrame.width, 44)
            XCTAssertGreaterThanOrEqual(actualFrame.height, 44)
            XCTAssertFalse(control.accessibilityHelp()?.isEmpty ?? true)
        }
        window.close()
    }

    func testReaderBandAndInteractionZonesAreIgnored() {
        let manifest = PresenterAccessibility.manifest(state: accessibilityState())
        let ignored = Set(manifest.filter(\.isIgnored).map(\.identifier))
        let expected = Set([
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
        ])

        XCTAssertEqual(ignored, expected)
    }

    func testWarningFocusNeverActivatesBackgroundApplication() {
        let background = PresenterAccessibility.warningFocusDecision(
            unsafeGeneration: 7,
            lastFocusedGeneration: nil,
            controllerIsActive: false
        )
        XCTAssertFalse(background.shouldMoveFocus)
        XCTAssertFalse(background.shouldActivateApplication)

        let first = PresenterAccessibility.warningFocusDecision(
            unsafeGeneration: 7,
            lastFocusedGeneration: nil,
            controllerIsActive: true
        )
        XCTAssertTrue(first.shouldMoveFocus)
        XCTAssertFalse(first.shouldActivateApplication)
        XCTAssertEqual(first.consumedGeneration, 7)

        let duplicate = PresenterAccessibility.warningFocusDecision(
            unsafeGeneration: 7,
            lastFocusedGeneration: 7,
            controllerIsActive: true
        )
        XCTAssertFalse(duplicate.shouldMoveFocus)
        XCTAssertFalse(duplicate.shouldActivateApplication)

        let next = PresenterAccessibility.warningFocusDecision(
            unsafeGeneration: 8,
            lastFocusedGeneration: 7,
            controllerIsActive: true
        )
        XCTAssertTrue(next.shouldMoveFocus)
        XCTAssertFalse(next.shouldActivateApplication)
    }

    func testPublicAccessibilitySurfacesNeverContainPrivateSentinels() {
        let sentinels = [
            "SENTINEL_PRIVATE_TITLE",
            "SENTINEL_PRIVATE_SCRIPT",
            "SENTINEL_PRIVATE_DISPLAY",
        ]
        let manifest = PresenterAccessibility.manifest(
            state: accessibilityState(
                scriptTitle: sentinels[0],
                scriptText: sentinels[1],
                displayName: sentinels[2]
            )
        )
        let publicText = manifest
            .filter(\.isPublicSurface)
            .flatMap { [$0.label, $0.value, $0.help, $0.toolTip] }
            .joined(separator: " ")

        XCTAssertFalse(publicText.isEmpty)
        for sentinel in sentinels {
            XCTAssertFalse(publicText.contains(sentinel))
        }
        XCTAssertTrue(publicText.contains("Private Presenter"))
        XCTAssertTrue(publicText.contains("Show Controller"))
        XCTAssertTrue(publicText.contains("Quit"))
    }

    func testReduceMotionChangeRemovesFadeButKeepsReadingMotion() {
        let reduced = PresenterAccessibility.motionPolicy(reduceMotion: true)
        XCTAssertEqual(reduced.decorativeFocusDuration, 0)
        XCTAssertTrue(reduced.readingMotionEnabled)

        let standard = PresenterAccessibility.motionPolicy(reduceMotion: false)
        XCTAssertGreaterThan(standard.decorativeFocusDuration, 0)
        XCTAssertTrue(standard.readingMotionEnabled)
    }

    func testUITestStoreOverrideRequiresDebugFlagXCTestAndTemporaryDescendant() throws {
        let candidate = testContainer.appendingPathComponent("valid", isDirectory: true)
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)
        let environment = overrideEnvironment(candidate.path)

        XCTAssertEqual(
            M5ApplicationSupportRootPolicy.resolve(
                environment: environment,
                isDebugBuild: true,
                normalRoot: normal,
                temporaryDirectory: temporaryDirectory,
                fileManager: fileManager
            ),
            candidate.resolvingSymlinksInPath().standardizedFileURL
        )

        for invalidEnvironment in [
            environment.merging(["PRIVATE_PRESENTER_UI_TEST": "0"]) { _, new in new },
            environment.filter { $0.key != "PRIVATE_PRESENTER_UI_TEST" },
            environment.merging(["XCTestConfigurationFilePath": ""]) { _, new in new },
            environment.filter { $0.key != "PRIVATE_PRESENTER_UI_TEST_STORE_ROOT" },
        ] {
            XCTAssertEqual(
                resolvedRoot(invalidEnvironment, isDebugBuild: true, normalRoot: normal),
                normal
            )
        }
    }

    func testUITestStoreOverrideRejectsDotDotTraversal() {
        let rawTraversal = testContainer.path + "/valid/../escape"
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)

        XCTAssertEqual(
            resolvedRoot(
                overrideEnvironment(rawTraversal),
                isDebugBuild: true,
                normalRoot: normal
            ),
            normal
        )
    }

    func testUITestStoreOverrideRejectsSymlinkEscape() throws {
        let link = testContainer.appendingPathComponent("escape-link", isDirectory: true)
        try fileManager.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/"))
        let escaped = link.appendingPathComponent("private-presenter", isDirectory: true)
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)

        XCTAssertEqual(
            resolvedRoot(
                overrideEnvironment(escaped.path),
                isDebugBuild: true,
                normalRoot: normal
            ),
            normal
        )
    }

    func testUITestStoreOverrideRejectsPrefixOnlySibling() {
        let temporary = temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
        let prefixSibling = temporary.deletingLastPathComponent()
            .appendingPathComponent(
                temporary.lastPathComponent + "-not-a-descendant",
                isDirectory: true
            )
            .appendingPathComponent("private-presenter", isDirectory: true)
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)

        XCTAssertEqual(
            resolvedRoot(
                overrideEnvironment(prefixSibling.path),
                isDebugBuild: true,
                normalRoot: normal
            ),
            normal
        )
    }

    func testUITestStoreOverrideRejectsReleaseBuild() throws {
        let candidate = testContainer.appendingPathComponent("release", isDirectory: true)
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)

        XCTAssertEqual(
            resolvedRoot(
                overrideEnvironment(candidate.path),
                isDebugBuild: false,
                normalRoot: normal
            ),
            normal
        )
    }

    func testUITestStoreOverrideRejectsMissingXCTestConfiguration() throws {
        let candidate = testContainer.appendingPathComponent("no-xctest", isDirectory: true)
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        let normal = URL(fileURLWithPath: "/normal/application-support", isDirectory: true)
        var environment = overrideEnvironment(candidate.path)
        environment.removeValue(forKey: "XCTestConfigurationFilePath")

        XCTAssertEqual(
            resolvedRoot(environment, isDebugBuild: true, normalRoot: normal),
            normal
        )
    }

    private var temporaryDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private func accessibilityState(
        scriptTitle: String = "Synthetic title",
        scriptText: String = "Synthetic script",
        displayName: String = "Synthetic private display"
    ) -> PresenterAccessibility.State {
        PresenterAccessibility.State(
            scriptTitle: scriptTitle,
            scriptText: scriptText,
            displayName: displayName,
            fontSizePoints: 42,
            speedPointsPerSecond: 60,
            alignment: .center,
            isActiveBandEnabled: true,
            isPlaying: false,
            isVisible: false,
            isLocked: true,
            isFocusModeEnabled: true,
            retryShortcutsVisible: true,
            topologyStatus: .extended
        )
    }

    private func hostedDescendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(hostedDescendants(of:))
    }

    private func entry(
        _ identifier: String,
        in manifest: [PresenterAccessibility.Entry]
    ) throws -> PresenterAccessibility.Entry {
        try XCTUnwrap(manifest.first { $0.identifier == identifier })
    }

    private func overrideEnvironment(_ path: String) -> [String: String] {
        [
            "PRIVATE_PRESENTER_UI_TEST": "1",
            "XCTestConfigurationFilePath": "/synthetic/PrivatePresenter.xctestconfiguration",
            "PRIVATE_PRESENTER_UI_TEST_STORE_ROOT": path,
        ]
    }

    private func resolvedRoot(
        _ environment: [String: String],
        isDebugBuild: Bool,
        normalRoot: URL
    ) -> URL {
        M5ApplicationSupportRootPolicy.resolve(
            environment: environment,
            isDebugBuild: isDebugBuild,
            normalRoot: normalRoot,
            temporaryDirectory: temporaryDirectory,
            fileManager: fileManager
        )
    }
}
