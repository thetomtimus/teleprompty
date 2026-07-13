import AppKit
import XCTest

@testable import PrivatePresenter

@MainActor
final class OverlayPanelConfigurationTests: XCTestCase {
    func testPanelIsBorderlessNonactivatingAndNotNativelyResizable() {
        let controller = makeController()
        let mask = controller.teleprompterPanel.styleMask

        XCTAssertFalse(mask.contains(.titled))
        XCTAssertTrue(mask.contains(.nonactivatingPanel))
        XCTAssertFalse(mask.contains(.resizable))
    }

    func testCustomResizeHandlesApplyOnlyContainedFrames() {
        var applied: [NSRect] = []
        let interaction = ClampedPanelInteractionController { applied.append($0) }
        let screen = NSRect(x: -1_920, y: -200, width: 1_920, height: 1_080)

        interaction.resize(
            frame: NSRect(x: -1_500, y: 100, width: 700, height: 350),
            edge: .topRight,
            delta: NSSize(width: 5_000, height: 5_000),
            inside: screen
        )

        XCTAssertEqual(applied.count, 1)
        XCTAssertTrue(screen.contains(applied[0]))
    }

    func testPanelJoinsAllSpacesAsFullScreenAuxiliary() {
        let behavior = makeController().teleprompterPanel.collectionBehavior
        XCTAssertTrue(behavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
    }

    func testPanelUsesBoundedLevel() {
        for proofLevel in OverlayPanelLevel.allCases {
            let controller = OverlayPanelController(proofLevel: proofLevel)
            XCTAssertEqual(controller.teleprompterPanel.level, proofLevel.appKitLevel)
        }
        XCTAssertEqual(Set(OverlayPanelLevel.allCases.map(\.rawValue)), ["floating", "statusBar"])
    }

    func testLockedPanelIgnoresMouseAndCannotBecomeKeyOrMain() {
        let panel = makeController().teleprompterPanel
        panel.setLocked(true)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testUnlockedPanelRestoresInteraction() {
        let panel = makeController().teleprompterPanel
        panel.setLocked(true)
        panel.setLocked(false)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.canBecomeKey, NSApp.isActive)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testShowDoesNotActivateApplication() {
        let controller = makeController()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        controller.show(
            proposedFrame: NSRect(x: 100, y: 100, width: 700, height: 350),
            on: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        XCTAssertEqual(
            NSWorkspace.shared.frontmostApplication?.processIdentifier,
            frontmostPID
        )
        XCTAssertFalse(controller.teleprompterPanel.isKeyWindow)
        XCTAssertFalse(controller.teleprompterPanel.isMainWindow)
    }

    func testReadingSurfaceInteriorIsOpaque() {
        let snapshot = makeController().configurationSnapshot
        XCTAssertTrue(snapshot.interiorIsFullyOpaque)
        XCTAssertFalse(makeController().teleprompterPanel.isOpaque)
        XCTAssertGreaterThan(OverlayRootView.cornerRadius, 0)
    }

    func testConfigurationSnapshotIsImmutableValue() {
        let controller = makeController()
        let unlocked = controller.configurationSnapshot
        controller.setLocked(true)
        let locked = controller.configurationSnapshot

        XCTAssertFalse(unlocked.isLocked)
        XCTAssertTrue(locked.isLocked)
        XCTAssertFalse(unlocked.ignoresMouseEvents)
        XCTAssertTrue(locked.ignoresMouseEvents)
    }

    #if DEBUG
    func testOrderingModesAreExactlyFrontAndFrontRegardless() {
        XCTAssertEqual(
            Set(OverlayPanelOrderingMode.allCases.map(\.rawValue)),
            ["front", "frontRegardless"]
        )
    }

    func testBothOrderingModesAvoidKeyMainAndExplicitActivation() {
        for ordering in OverlayPanelOrderingMode.allCases {
            var operations: [OverlayPanelOperation] = []
            let controller = OverlayPanelController(
                proofLevel: .floating,
                orderingMode: ordering,
                operationRecorder: { operations.append($0) }
            )
            let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)

            controller.show(
                proposedFrame: NSRect(x: 10, y: 10, width: 600, height: 300),
                on: screen
            )

            XCTAssertFalse(operations.contains(.activateApplication))
            XCTAssertFalse(operations.contains(.makeKey))
            XCTAssertFalse(operations.contains(.makeMain))
            XCTAssertFalse(controller.teleprompterPanel.isKeyWindow)
            XCTAssertFalse(controller.teleprompterPanel.isMainWindow)
        }
    }

    func testDefaultProofLevelRemainsStatusBarUntilPhysicalMatrix() {
        XCTAssertEqual(DiagnosticProofConfiguration.defaultLevel, .statusBar)
        XCTAssertEqual(OverlayPanelController().configurationSnapshot.level, "statusBar")
    }

    func testDefaultOrderingRemainsFrontRegardlessUntilPhysicalEvidence() {
        XCTAssertEqual(DiagnosticProofConfiguration.defaultOrdering, .frontRegardless)
        XCTAssertEqual(OverlayPanelController().orderingMode, .frontRegardless)
    }

    func testOrderingSelectionChoosesOnlyPassingMode() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(ordering: .front, passes: true),
            candidate(ordering: .frontRegardless, passes: false),
        ])

        XCTAssertEqual(selected?.ordering, .front)
    }

    func testOrderingSelectionRetainsCurrentSourceDefaultWhenBothModesAreEquivalent() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(ordering: .front, passes: true),
            candidate(ordering: .frontRegardless, passes: true),
        ])

        XCTAssertEqual(selected?.level, .statusBar)
        XCTAssertEqual(selected?.ordering, .frontRegardless)
    }

    func testOrderingSelectionUsesSafetyVectorBeforeDefaultTieBreak() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(level: .floating, ordering: .front, passes: true),
            candidate(
                ordering: .frontRegardless,
                passes: true,
                activationTransitions: 1
            ),
        ])

        XCTAssertEqual(selected?.level, .floating)
        XCTAssertEqual(selected?.ordering, .front)
    }

    func testOrderingSelectionRejectsLevelWhenNeitherModePasses() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(level: .floating, ordering: .front, passes: false),
            candidate(level: .floating, ordering: .frontRegardless, passes: false),
        ])

        XCTAssertNil(selected)
    }

    func testLevelSelectionPrefersFloatingOnlyAfterCompletePassingOrdering() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(level: .floating, ordering: .front, passes: true),
            candidate(level: .statusBar, ordering: .frontRegardless, passes: false),
        ])

        XCTAssertEqual(selected?.level, .floating)
    }

    func testConfigurationSnapshotExportsCommitOrderingAndLevel() {
        let configuration = makeDiagnosticConfiguration(level: .floating, ordering: .front)
        let controller = OverlayPanelController(
            proofLevel: configuration.proofLevel,
            orderingMode: configuration.ordering
        )

        XCTAssertEqual(configuration.implementationCommit.count, 40)
        XCTAssertEqual(controller.configurationSnapshot.level, "floating")
        XCTAssertEqual(controller.configurationSnapshot.ordering, "front")
    }

    func testActivationPolicyIsSetOnlyAtBootstrap() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = try swiftSources(at: root.appendingPathComponent("PrivatePresenterApp"))
        let mutations = sources.filter { $0.contents.contains("setActivationPolicy") }

        XCTAssertEqual(mutations.map(\.name), ["PrivatePresenterApp.swift"])
        XCTAssertEqual(
            mutations.first?.contents.components(separatedBy: "setActivationPolicy").count,
            2
        )
    }

    func testForbiddenWindowLevelsAndFocusWorkaroundsAreAbsent() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try swiftSources(at: root.appendingPathComponent("PrivatePresenterApp"))
            .map(\.contents)
            .joined(separator: "\n")
        let forbidden = [
            ".screenSaver",
            "CGWindowLevelForKey(",
            "NSApp.activate(",
            "makeKeyAndOrderFront(",
            "GetEventDispatcherTarget(",
            "performWindowDrag(",
            "NSWindow.Level(rawValue:",
            "AXUIElement",
            "AXObserver",
            "AXIsProcessTrusted",
            "import ApplicationServices",
            "styleMask.insert(.resizable)",
            "styleMask.formUnion([.resizable])",
        ]

        for marker in forbidden {
            XCTAssertFalse(source.contains(marker), "Forbidden Phase A marker: \(marker)")
        }
    }
    #endif

    private func makeController() -> OverlayPanelController {
        _ = NSApplication.shared
        return OverlayPanelController()
    }

    #if DEBUG
    private func candidate(
        level: OverlayPanelLevel = .statusBar,
        ordering: OverlayPanelOrderingMode,
        passes: Bool,
        activationTransitions: Int = 0
    ) -> OverlayConfigurationCandidate {
        OverlayConfigurationCandidate(
            level: level,
            ordering: ordering,
            completePass: passes,
            activationTransitions: activationTransitions,
            controllerPresentationOperations: 0,
            panelKeyMainTransitions: 0,
            missedVisibilitySamples: 0
        )
    }

    private func swiftSources(at root: URL) throws -> [(name: String, contents: String)] {
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        )
        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let contents = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    line.split(separator: "//", maxSplits: 1).first.map(String.init) ?? ""
                }
                .joined(separator: "\n")
            return (url.lastPathComponent, contents)
        }
    }
    #endif
}
