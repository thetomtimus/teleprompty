import AppKit
import SwiftUI
import XCTest

@testable import PrivatePresenter

@MainActor
final class OverlayPanelConfigurationTests: XCTestCase {
    func testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain() {
        let controller = OverlayPanelController()
        let snapshot = controller.configurationSnapshot

        XCTAssertEqual(snapshot.level, "statusBar")
        #if DEBUG
        XCTAssertEqual(snapshot.ordering, "frontRegardless")
        #endif
        XCTAssertFalse(snapshot.canBecomeKey)
        XCTAssertFalse(snapshot.canBecomeMain)
    }

    func testM2PreservesOpaqueRoundedReaderSurface() {
        let snapshot = OverlayPanelController().configurationSnapshot

        XCTAssertTrue(snapshot.interiorIsFullyOpaque)
        XCTAssertGreaterThan(OverlayRootView.cornerRadius, 0)
    }

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

    func testResizeZonesContainExactlyEightEdgesAndCorners() {
        XCTAssertEqual(OverlayRootView.resizeZones.count, 8)
        XCTAssertEqual(
            Set(OverlayRootView.resizeZones),
            Set(ClampedPanelInteractionController.ResizeEdge.allCases)
        )
    }

    func testEveryResizeZoneAppliesOnlyContainedIntermediateFrames() {
        let screen = NSRect(x: -1_920, y: -200, width: 1_920, height: 1_080)
        let start = NSRect(x: -1_500, y: 100, width: 700, height: 350)
        var applied: [NSRect] = []
        let interaction = ClampedPanelInteractionController { applied.append($0) }

        for edge in OverlayRootView.resizeZones {
            interaction.resize(
                frame: start,
                edge: edge,
                delta: NSSize(width: 5_000, height: -5_000),
                inside: screen
            )
        }

        XCTAssertEqual(applied.count, 8)
        XCTAssertTrue(applied.allSatisfy(screen.contains))
    }

    func testDragHeaderAppliesOnlyContainedIntermediateFrames() {
        let screen = NSRect(x: 1_440, y: 300, width: 1_920, height: 1_080)
        var applied: [NSRect] = []
        let interaction = ClampedPanelInteractionController { applied.append($0) }

        interaction.drag(
            frame: NSRect(x: 1_600, y: 400, width: 700, height: 350),
            delta: NSSize(width: -10_000, height: 10_000),
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

    func testUnlockedPanelRestoresInteractionWithoutAcceptingKey() {
        let panel = makeController().teleprompterPanel
        panel.setLocked(true)
        panel.setLocked(false)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
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

    func testRenderedRoundedInteriorIsOpaqueOverBrightAndCheckerboardBackdrops() throws {
        let hosting = NSHostingView(rootView: OverlayRootView())
        hosting.frame = NSRect(x: 0, y: 0, width: 240, height: 140)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(
            hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        )
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let pixel = try XCTUnwrap(bitmap.colorAt(x: 120, y: 70))
            .usingColorSpace(.deviceRGB)
        let alpha = try XCTUnwrap(pixel?.alphaComponent)

        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        for backdrop in [NSColor.white, NSColor(calibratedWhite: 0.75, alpha: 1)] {
            let composite = try XCTUnwrap(composite(pixel: pixel, over: backdrop))
            XCTAssertEqual(composite.alphaComponent, 1, accuracy: 0.001)
            XCTAssertEqual(composite.redComponent, pixel?.redComponent ?? -1, accuracy: 0.001)
            XCTAssertEqual(composite.greenComponent, pixel?.greenComponent ?? -1, accuracy: 0.001)
            XCTAssertEqual(composite.blueComponent, pixel?.blueComponent ?? -1, accuracy: 0.001)
        }
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

    func testDefaultProofLevelUsesLowestPhysicallyPassingStatusBarEvidence() {
        XCTAssertEqual(DiagnosticProofConfiguration.defaultLevel, .statusBar)
        XCTAssertEqual(OverlayPanelController().configurationSnapshot.level, "statusBar")
    }

    func testDefaultOrderingRetainsFrontRegardlessAfterPhysicalEvidence() {
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

        XCTAssertEqual(selected?.level, .floating)
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

    func testLevelSelectionRetainsFloatingBeforeComparingStatusBarSafety() {
        let selected = OverlayConfigurationSelector.select(from: [
            candidate(
                level: .floating,
                ordering: .frontRegardless,
                passes: true,
                activationTransitions: 1
            ),
            candidate(level: .statusBar, ordering: .front, passes: true),
        ])

        XCTAssertEqual(selected?.level, .floating)
        XCTAssertEqual(selected?.ordering, .frontRegardless)
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

    private func composite(pixel: NSColor?, over backdrop: NSColor) -> NSColor? {
        guard
            let foreground = pixel?.usingColorSpace(.deviceRGB),
            let background = backdrop.usingColorSpace(.deviceRGB)
        else { return nil }
        let alpha = foreground.alphaComponent
        return NSColor(
            calibratedRed: foreground.redComponent * alpha
                + background.redComponent * (1 - alpha),
            green: foreground.greenComponent * alpha
                + background.greenComponent * (1 - alpha),
            blue: foreground.blueComponent * alpha
                + background.blueComponent * (1 - alpha),
            alpha: alpha + background.alphaComponent * (1 - alpha)
        )
    }

    #if DEBUG
    private func candidate(
        level: OverlayPanelLevel = .floating,
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
