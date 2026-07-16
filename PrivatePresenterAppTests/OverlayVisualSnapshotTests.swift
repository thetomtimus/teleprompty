import AppKit
import SwiftUI
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class OverlayVisualSnapshotTests: XCTestCase {
    func testReferenceSurfaceUsesExactOpaqueNavyTokens() throws {
        let stops = OverlayVisualTokens.cardGradientStops
        XCTAssertEqual(stops.map(\.location), [0.00, 0.42, 1.00])
        try assertColor(stops[0].color.appKitColor, red: 52, green: 70, blue: 111, alpha: 1)
        try assertColor(stops[1].color.appKitColor, red: 44, green: 61, blue: 99, alpha: 1)
        try assertColor(stops[2].color.appKitColor, red: 32, green: 43, blue: 75, alpha: 1)
        try assertColor(OverlayVisualTokens.readingText.appKitColor, red: 247, green: 248, blue: 252, alpha: 1)
        try assertColor(OverlayVisualTokens.cardBorder.appKitColor, red: 255, green: 255, blue: 255, alpha: 0.24)
        XCTAssertEqual(OverlayVisualTokens.cardRadius, 30)
        XCTAssertEqual(OverlayVisualTokens.cardBorderWidth, 1)
    }

    func testRoundedInteriorIsOpaqueOverWhiteAndBlack() throws {
        let hosting = NSHostingView(
            rootView: OverlayRootView().frame(width: 320, height: 180)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(
            hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        )
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        let interiorSamples = [
            NSPoint(x: 40, y: 40), NSPoint(x: 160, y: 40),
            NSPoint(x: 280, y: 40), NSPoint(x: 40, y: 90),
            NSPoint(x: 160, y: 90), NSPoint(x: 280, y: 90),
            NSPoint(x: 40, y: 140), NSPoint(x: 160, y: 140),
            NSPoint(x: 280, y: 140),
        ]
        for point in interiorSamples {
            let rendered = try XCTUnwrap(
                bitmap.colorAt(x: Int(point.x), y: Int(point.y))?.usingColorSpace(.sRGB)
            )
            XCTAssertEqual(rendered.alphaComponent, 1, accuracy: 0.001)
            for backdrop in [NSColor.white, NSColor.black] {
                let composited = composite(rendered, over: backdrop)
                XCTAssertEqual(composited.red, rendered.redComponent, accuracy: 0.001)
                XCTAssertEqual(composited.green, rendered.greenComponent, accuracy: 0.001)
                XCTAssertEqual(composited.blue, rendered.blueComponent, accuracy: 0.001)
            }
        }
    }

    func testNoTitleBarScrollbarGlowOrCompetingReaderFill() {
        let panel = TeleprompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 350)
        )
        XCTAssertFalse(panel.styleMask.contains(.titled))
        XCTAssertFalse(panel.styleMask.contains(.resizable))
        XCTAssertFalse(panel.isOpaque)
        XCTAssertTrue(panel.hasShadow)

        let system = ReaderTextSystem(text: "Synthetic visual test copy", revision: 0)
        let reader = ReaderTextView.makeReaderView(system: system)
        XCTAssertEqual(reader.subviews.count, 3)
        XCTAssertTrue(reader.subviews[0] === reader.backgroundView)
        XCTAssertTrue(reader.subviews[1] === system.activeBandView)
        XCTAssertTrue(reader.subviews[2] === reader.scrollView)
        XCTAssertEqual(reader.backgroundView.identifier?.rawValue, "privatePresenter.readerBackground")
        XCTAssertEqual(reader.backgroundView.layer?.backgroundColor?.alpha, 0)
        XCTAssertFalse(reader.scrollView.drawsBackground)
        XCTAssertFalse(reader.scrollView.contentView.drawsBackground)
        XCTAssertFalse(system.textView.drawsBackground)
        XCTAssertFalse(reader.scrollView.hasVerticalScroller)
        XCTAssertFalse(reader.scrollView.hasHorizontalScroller)
    }

    func testReaderUsesSystemTypographyAndReferenceSpacing() throws {
        let system = ReaderTextSystem(text: "Reference typography", revision: 0)
        system.updateAttributes(fontSize: 42, fontWeight: .regular, alignment: .left)
        let attributes = system.textStorage.attributes(at: 0, effectiveRange: nil)
        let font = try XCTUnwrap(attributes[.font] as? NSFont)
        let paragraph = try XCTUnwrap(attributes[.paragraphStyle] as? NSParagraphStyle)
        let foreground = try XCTUnwrap(attributes[.foregroundColor] as? NSColor)

        XCTAssertEqual(font.pointSize, 42)
        XCTAssertEqual(ReaderTextSystem.appKitWeight(for: .regular), .regular)
        XCTAssertEqual(paragraph.lineHeightMultiple, 1.42, accuracy: 0.000_001)
        XCTAssertEqual(paragraph.paragraphSpacing, 0)
        XCTAssertEqual(paragraph.alignment, .left)
        XCTAssertEqual(paragraph.hyphenationFactor, 0)
        XCTAssertNil(attributes[.underlineStyle])
        XCTAssertNil(attributes[.link])
        try assertColor(foreground, red: 247, green: 248, blue: 252, alpha: 1)

        let compact = OverlayLayoutMetrics(size: CGSize(width: 320, height: 180))
        let standard = OverlayLayoutMetrics(size: CGSize(width: 700, height: 350))
        let spacious = OverlayLayoutMetrics(size: CGSize(width: 1_036, height: 460))
        let wide = OverlayLayoutMetrics(size: CGSize(width: 1_440, height: 460))
        XCTAssertEqual(compact.tier, .compact)
        XCTAssertEqual(standard.tier, .standard)
        XCTAssertEqual(spacious.tier, .spacious)
        XCTAssertEqual(compact.headerHeight, 52)
        XCTAssertEqual(compact.readingSideInset, 20)
        XCTAssertEqual(compact.readingTopReserve, 58)
        XCTAssertEqual(compact.readingBottomReserve, 88)
        XCTAssertEqual(standard.headerHeight, 72)
        XCTAssertEqual(standard.readingSideInset, 48)
        XCTAssertEqual(standard.readingTopReserve, 96)
        XCTAssertEqual(standard.readingBottomReserve, 90)
        XCTAssertEqual(spacious.headerHeight, 92)
        XCTAssertEqual(spacious.readingSideInset, 52)
        XCTAssertEqual(spacious.readingTopReserve, 124)
        XCTAssertEqual(spacious.readingBottomReserve, 114)
        XCTAssertEqual(wide.effectiveReadingSideInset, 195)
        XCTAssertLessThanOrEqual(wide.readableLineWidth, 1_050)

        system.configureViewport(NSSize(width: 1_440, height: 460))
        XCTAssertEqual(system.textView.textContainerInset.width, 195)
        XCTAssertLessThanOrEqual(
            system.textView.frame.width - 2 * system.textView.textContainerInset.width,
            1_050
        )
    }

    func testPersistedWeightMapsWithoutReplacingText() {
        let system = ReaderTextSystem(text: "Persisted weight", revision: 0)
        let storage = system.textStorage
        let replacements = system.fullReplacementCount
        let expected: [(TeleprompterFontWeight, NSFont.Weight)] = [
            (.regular, .regular), (.medium, .medium), (.semibold, .semibold),
        ]

        for (weight, appKitWeight) in expected {
            system.updateAttributes(fontSize: 42, fontWeight: weight, alignment: .left)
            XCTAssertEqual(ReaderTextSystem.appKitWeight(for: weight), appKitWeight)
            XCTAssertTrue(system.textStorage === storage)
            XCTAssertEqual(system.textStorage.string, "Persisted weight")
            XCTAssertEqual(system.fullReplacementCount, replacements)
        }
    }

    func testActiveBandUsesTwoCachedTextKit2LineFragmentsForEveryWeightAtDefaultAndLargeSizes() {
        let text = (1...40).map { "Synthetic reference line \($0)" }.joined(separator: "\n")
        for weight in TeleprompterFontWeight.allCases {
            for (fontSize, size) in [
                (42.0, NSSize(width: 700, height: 350)),
                (96.0, NSSize(width: 1_036, height: 460)),
            ] {
                let viewport = makeReader(
                    text: text, size: size, fontSize: fontSize, fontWeight: weight
                )
                XCTAssertEqual(viewport.container.resolvedBandFragments.count, 2)
                let unconstrained = viewport.container.resolvedBandFragments
                    .reduce(12) { $0 + $1.frame.height }
                XCTAssertEqual(
                    viewport.container.resolvedActiveBandHeight,
                    min(unconstrained, viewport.container.maximumActiveBandHeight),
                    accuracy: 1
                )
            }
        }
    }

    func testBandLineSelectionUsesNearestThenAdjacentWithFollowingTieBreak() {
        let lines = [
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 0..<1, frame: NSRect(x: 0, y: 0, width: 100, height: 20)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 1..<2, frame: NSRect(x: 0, y: 30, width: 100, height: 20)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 2..<3, frame: NSRect(x: 0, y: 60, width: 100, height: 20)
            ),
        ]
        let selected = ReaderViewportAdapter.selectActiveBandLineFragments(
            from: lines, targetY: 40
        )
        XCTAssertEqual(selected.map(\.utf16Range), [1..<2, 2..<3])

        let nearestTie = ReaderViewportAdapter.selectActiveBandLineFragments(
            from: lines, targetY: 25
        )
        XCTAssertEqual(nearestTie.map(\.utf16Range), [0..<1, 1..<2])
    }

    func testActiveBandOneAndZeroFragmentFallbacksAndCompactClampDoNotClipGlyphs() {
        let line = ReaderViewportAdapter.LineFragmentEvidence(
            utf16Range: 0..<1, frame: NSRect(x: 0, y: 0, width: 100, height: 44)
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [line], fallbackLineHeight: 50, maximumHeight: 200
            ),
            100
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [], fallbackLineHeight: 50, maximumHeight: 200
            ),
            112
        )
        XCTAssertEqual(
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: [], fallbackLineHeight: 50, maximumHeight: 34
            ),
            34
        )
    }

    func testBandMetricsCreateNoSecondTextLayoutManagerOrCacheOwner() throws {
        let viewport = makeReader(
            text: "One\nTwo\nThree\nFour", size: NSSize(width: 700, height: 350)
        )
        let manager = try XCTUnwrap(viewport.system.textView.textLayoutManager)
        _ = viewport.adapter.cachedActiveBandLineFragments(viewportFraction: 0.5)
        XCTAssertTrue(viewport.system.textView.textLayoutManager === manager)
        let source = try String(
            contentsOf: sourceURL("ReaderViewportAdapter.swift"), encoding: .utf8
        )
        let queryStart = try XCTUnwrap(source.range(of: "func cachedActiveBandLineFragments"))
        let querySource = source[queryStart.lowerBound...]
        XCTAssertFalse(querySource.prefix(1_200).contains("ensureLayout("))
        XCTAssertFalse(querySource.prefix(1_200).contains("NSTextLayoutManager("))
    }

    func testLiteralTextAndBandContrastThresholds() throws {
        try assertColor(
            OverlayVisualTokens.activeBandLeading.appKitColor,
            red: 130, green: 160, blue: 213, alpha: 0.28
        )
        try assertColor(
            OverlayVisualTokens.activeBandMiddle.appKitColor,
            red: 113, green: 145, blue: 202, alpha: 0.35
        )
        try assertColor(
            OverlayVisualTokens.activeBandTrailing.appKitColor,
            red: 130, green: 160, blue: 213, alpha: 0.20
        )
        try assertColor(
            OverlayVisualTokens.activeBandAccent.appKitColor,
            red: 190, green: 211, blue: 248, alpha: 0.62
        )
        XCTAssertEqual(OverlayVisualTokens.activeBandRadius, 8)
        XCTAssertEqual(OverlayVisualTokens.activeBandAccentWidth, 3)
        let text = (247.0 / 255, 248.0 / 255, 252.0 / 255)
        let cardStops = [
            (52.0 / 255, 70.0 / 255, 111.0 / 255),
            (44.0 / 255, 61.0 / 255, 99.0 / 255),
            (32.0 / 255, 43.0 / 255, 75.0 / 255),
        ]
        for card in cardStops {
            XCTAssertGreaterThanOrEqual(contrast(text, card), 7)
            for band in [
                (130.0 / 255, 160.0 / 255, 213.0 / 255, 0.28),
                (113.0 / 255, 145.0 / 255, 202.0 / 255, 0.35),
                (130.0 / 255, 160.0 / 255, 213.0 / 255, 0.20),
            ] {
                let composited = (
                    band.0 * band.3 + card.0 * (1 - band.3),
                    band.1 * band.3 + card.1 * (1 - band.3),
                    band.2 * band.3 + card.2 * (1 - band.3)
                )
                XCTAssertGreaterThanOrEqual(contrast(text, composited), 4.5)
            }
        }
    }

    func testHeaderHasTitlePlaybackLockAndSettingsInOrder() {
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(title: "Lecture Teleprompter", text: "Synthetic"),
            restorationRequired: false
        )
        XCTAssertEqual(OverlayChromeView.title(model: model), "Lecture Teleprompter")
        XCTAssertEqual(
            OverlayChromeView.actionIdentifiers,
            [
                "privatePresenter.headerPlayback",
                "privatePresenter.headerLock",
                "privatePresenter.headerSettings",
            ]
        )
    }

    func testQuickPillHasSevenTypedActionsInOrder() {
        XCTAssertEqual(
            OverlayQuickControlsView.actionIdentifiers,
            [
                "privatePresenter.quickSmaller",
                "privatePresenter.quickLarger",
                "privatePresenter.quickAlignment",
                "privatePresenter.quickSlower",
                "privatePresenter.quickPlayback",
                "privatePresenter.quickFaster",
                "privatePresenter.quickFocus",
            ]
        )
    }

    func testHeaderAndPillUseFrozenSymbolAndStateVariantsAtEveryTier() {
        for (tier, size) in [
            (OverlayLayoutMetrics.Tier.compact, CGFloat(16)),
            (.standard, 18),
            (.spacious, 20),
        ] {
            XCTAssertEqual(
                OverlayChromeView.symbols(isPlaying: false, isLocked: false),
                ["play.fill", "lock.open.fill", "gearshape"]
            )
            XCTAssertEqual(
                OverlayChromeView.symbols(isPlaying: true, isLocked: true),
                ["pause.fill", "lock.fill", "gearshape"]
            )
            XCTAssertEqual(
                OverlayQuickControlsView.symbols(
                    isPlaying: false, alignment: .left, isFocusModeEnabled: false
                ),
                [
                    "textformat.size.smaller", "textformat.size.larger",
                    "text.alignleft", "minus", "play.fill", "plus", "eye",
                ]
            )
            XCTAssertEqual(
                OverlayQuickControlsView.symbols(
                    isPlaying: true, alignment: .center, isFocusModeEnabled: true
                ),
                [
                    "textformat.size.smaller", "textformat.size.larger",
                    "text.aligncenter", "minus", "pause.fill", "plus", "eye.slash",
                ]
            )
            XCTAssertEqual(OverlayChromeView.iconSize(for: tier), size)
            XCTAssertEqual(OverlayQuickControlsView.iconSize(for: tier), size)
        }
    }

    func testEveryM6IconHasDynamicSemanticsTooltipAndFortyFourPointTarget() {
        let manifest = PresenterAccessibility.manifest(state: m6AccessibilityState())
        let identifiers = Set(
            OverlayChromeView.actionIdentifiers + OverlayQuickControlsView.actionIdentifiers
        )
        let entries = manifest.filter { identifiers.contains($0.identifier) }
        XCTAssertEqual(Set(entries.map(\.identifier)), identifiers)
        for entry in entries {
            XCTAssertTrue(entry.isDynamic, entry.identifier)
            XCTAssertFalse(entry.label.isEmpty, entry.identifier)
            XCTAssertFalse(entry.value.isEmpty, entry.identifier)
            XCTAssertFalse(entry.help.isEmpty, entry.identifier)
            XCTAssertFalse(entry.toolTip.isEmpty, entry.identifier)
            XCTAssertGreaterThanOrEqual(entry.minimumHitSize.width, 44, entry.identifier)
            XCTAssertGreaterThanOrEqual(entry.minimumHitSize.height, 44, entry.identifier)
        }
    }

    func testHeaderDragNeverInterceptsControls() throws {
        let source = try String(
            contentsOf: sourceURL("OverlayChromeView.swift"), encoding: .utf8
        )
        XCTAssertEqual(source.components(separatedBy: "DragGesture(").count - 1, 1)
        XCTAssertTrue(source.contains("privatePresenter.headerDragRegion"))
        XCTAssertFalse(source.contains(".overlay {\n            interactionZone(edge: nil)"))
        XCTAssertTrue(source.contains(".zIndex(1)"))
    }

    func testLockedVisibleAndHiddenChromeAreNotInteractiveOrAccessibilityNavigable() {
        let visible = OverlayRootView.chromePresentation(
            focusState: .lockedChromeVisible,
            isLocked: true,
            transitionDuration: 0.18
        )
        let hidden = OverlayRootView.chromePresentation(
            focusState: .lockedFocusChromeHidden,
            isLocked: true,
            transitionDuration: 0.18
        )
        XCTAssertEqual(visible.opacity, 1)
        XCTAssertEqual(hidden.opacity, 0)
        XCTAssertFalse(visible.allowsInteraction)
        XCTAssertFalse(hidden.allowsInteraction)
        XCTAssertTrue(visible.isAccessibilityHidden)
        XCTAssertTrue(hidden.isAccessibilityHidden)
    }

    func testOnlyUnlockedSettingsDispatchesShowControllerWithoutActivationWorkaround() throws {
        var effects: [AppEffect] = []
        let model = AppModel(
            overlayController: OverlayPanelController(),
            restorationRequired: false,
            effectHandler: { effects.append($0) }
        )
        model.send(.showController)
        XCTAssertEqual(effects, [.showExistingController])
        let source = try String(
            contentsOf: sourceURL("OverlayChromeView.swift"), encoding: .utf8
        )
        XCTAssertEqual(source.components(separatedBy: "model.send(.showController)").count - 1, 1)
        XCTAssertFalse(source.contains("NSApp.activate"))
        XCTAssertFalse(source.contains("makeKeyAndOrderFront"))
    }

    func testFocusModeFadesChromeWithoutChangingReaderGeometryOrAnchor() {
        let metrics = OverlayLayoutMetrics(size: CGSize(width: 700, height: 350))
        let visible = OverlayRootView.chromePresentation(
            focusState: .lockedFocusChromeVisible,
            isLocked: true,
            transitionDuration: 0.18,
            readerGeometryIdentity: metrics.readableLineWidth
        )
        let hidden = OverlayRootView.chromePresentation(
            focusState: .lockedFocusChromeHidden,
            isLocked: true,
            transitionDuration: 0.18,
            readerGeometryIdentity: metrics.readableLineWidth
        )
        XCTAssertEqual(visible.readerGeometryIdentity, hidden.readerGeometryIdentity)
        XCTAssertEqual(visible.readerGeometryIdentity, metrics.readableLineWidth)
        XCTAssertEqual(visible.transitionDuration, 0.18)
        XCTAssertEqual(hidden.transitionDuration, 0.18)
    }

    func testReduceMotionRemovesOnlyDecorativeFade() {
        let reduced = PresenterAccessibility.motionPolicy(reduceMotion: true)
        let ordinary = PresenterAccessibility.motionPolicy(reduceMotion: false)
        XCTAssertEqual(reduced.decorativeFocusDuration, 0)
        XCTAssertEqual(ordinary.decorativeFocusDuration, 0.18)
        XCTAssertTrue(reduced.readingMotionEnabled)
        XCTAssertTrue(ordinary.readingMotionEnabled)
    }

    func testResizeMatrixKeepsEveryPixelAndControlInsideRoundedSurface() {
        for size in m6ResizeSizeMatrix() {
            let metrics = OverlayLayoutMetrics(size: size)
            let path = RoundedRectangle(
                cornerRadius: 30, style: .continuous
            ).path(in: metrics.cardBounds).cgPath

            assertPixelSubset(metrics.toolbarFrame, inside: path)
            for region in metrics.controlRegions {
                assertPixelSubset(region.frame, inside: path)
            }
            XCTAssertTrue(metrics.cardBounds.contains(metrics.headerFrame))
            for region in metrics.resizeRegions {
                XCTAssertTrue(metrics.cardBounds.contains(region.frame), "\(size):\(region.edge)")
            }
        }

        let compact = OverlayLayoutMetrics(size: CGSize(width: 320, height: 180))
        XCTAssertEqual(compact.toolbarFrame, CGRect(x: 2, y: 30, width: 316, height: 52))
        XCTAssertEqual(compact.quickControlRegions.first?.frame, CGRect(x: 6, y: 34, width: 44, height: 44))
        XCTAssertEqual(compact.quickControlRegions.last?.frame, CGRect(x: 270, y: 34, width: 44, height: 44))
    }

    func testToolbarNeverOverlapsBandOrFinalLine() {
        for size in m6ResizeSizeMatrix() {
            let metrics = OverlayLayoutMetrics(size: size)
            XCTAssertFalse(metrics.toolbarFrame.intersects(metrics.readingFrame), "\(size)")
            XCTAssertEqual(
                metrics.readingFrame.height,
                max(0, size.height - metrics.readingTopReserve - metrics.readingBottomReserve)
            )
            let finalLine = CGRect(
                x: metrics.readingFrame.minX,
                y: metrics.readingFrame.minY,
                width: metrics.readingFrame.width,
                height: min(1, metrics.readingFrame.height)
            )
            XCTAssertFalse(metrics.toolbarFrame.intersects(finalLine), "\(size)")
            XCTAssertLessThanOrEqual(metrics.maximumActiveBandHeight, metrics.readingFrame.height)

            let visible = OverlayRootView.chromePresentation(
                focusState: .lockedFocusChromeVisible,
                isLocked: true,
                transitionDuration: 0.18,
                readerGeometryIdentity: metrics.readingFrame.height
            )
            let hidden = OverlayRootView.chromePresentation(
                focusState: .lockedFocusChromeHidden,
                isLocked: true,
                transitionDuration: 0.18,
                readerGeometryIdentity: metrics.readingFrame.height
            )
            XCTAssertEqual(visible.readerGeometryIdentity, hidden.readerGeometryIdentity)
        }
    }

    func testHundredResizesPreserveAnchorAndAvoidTextReplacement() throws {
        let text = (1...240).map { "Stable resize line \($0)" }.joined(separator: "\n")
        let system = ReaderTextSystem(text: text, revision: 0)
        var viewport: ReaderViewportAdapter?
        var pendingAnchor: ReadingAnchor?
        var willChangeCount = 0
        var changedCount = 0
        let container = ReaderTextView.makeReaderView(
            system: system,
            onBoundsWillChange: {
                willChangeCount += 1
                pendingAnchor = viewport?.captureAnchor(viewportFraction: 0.5)
            },
            onBoundsChanged: {
                changedCount += 1
                if let pendingAnchor {
                    _ = viewport?.restore(anchor: pendingAnchor)
                }
            }
        )
        viewport = container.viewportAdapter
        container.frame = NSRect(x: 0, y: 0, width: 700, height: 350)
        container.layoutSubtreeIfNeeded()

        let adapter = try XCTUnwrap(viewport)
        let baselineAnchor = adapter.captureAnchor(viewportFraction: 0.5)
        let storage = system.textStorage
        let replacements = system.fullReplacementCount
        let mutations = system.textMutationCount
        let sizes = m6ResizeSizeMatrix()
        for index in 0..<100 {
            let size = sizes[index % sizes.count]
            container.frame = NSRect(origin: .zero, size: size)
            container.layoutSubtreeIfNeeded()
        }

        let finalAnchor = adapter.captureAnchor(viewportFraction: 0.5)
        XCTAssertTrue(system.textStorage === storage)
        XCTAssertEqual(system.textStorage.string, text)
        XCTAssertEqual(system.fullReplacementCount, replacements)
        XCTAssertEqual(system.textMutationCount, mutations)
        XCTAssertEqual(willChangeCount, 100)
        XCTAssertEqual(changedCount, 100)
        XCTAssertEqual(finalAnchor.utf16Offset, baselineAnchor.utf16Offset)
        XCTAssertEqual(adapter.lastRestoredAnchor?.document, text)
    }

    func testEveryHeaderAndResizeFrameRemainsContainedExactlyOnce() {
        for size in m6ResizeSizeMatrix() {
            let metrics = OverlayLayoutMetrics(size: size)
            let resolver = OverlayHitRegionResolver(metrics: metrics)
            XCTAssertTrue(metrics.cardBounds.contains(metrics.headerFrame))
            XCTAssertEqual(Set(metrics.headerControlRegions.map(\.identifier)).count, 3)
            XCTAssertEqual(Set(metrics.resizeRegions.map(\.edge)).count, 8)

            for region in metrics.headerControlRegions {
                XCTAssertTrue(metrics.cardBounds.contains(region.frame))
                XCTAssertEqual(
                    resolver.resolve(point: CGPoint(x: region.frame.midX, y: region.frame.midY)),
                    .control(region.identifier)
                )
            }
            let titlePoint = CGPoint(
                x: metrics.titleDragFrame.midX, y: metrics.titleDragFrame.midY
            )
            XCTAssertEqual(resolver.resolve(point: titlePoint), .titleDrag)
        }
    }

    func testCompactTierDenseHitGridRoutesEveryControlBeforeResize() {
        let metrics = OverlayLayoutMetrics(size: CGSize(width: 320, height: 180))
        let resolver = OverlayHitRegionResolver(metrics: metrics)
        XCTAssertEqual(metrics.quickControlRegions.count, 7)
        for region in metrics.quickControlRegions {
            for y in Int(region.frame.minY)..<Int(region.frame.maxY) {
                for x in Int(region.frame.minX)..<Int(region.frame.maxX) {
                    XCTAssertEqual(
                        resolver.resolve(
                            point: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                        ),
                        .control(region.identifier),
                        "\(region.identifier) at \(x),\(y)"
                    )
                }
            }
        }
    }

    func testAllEightResizeOperationsRemainReachableOutsideControlsAtEveryTier() {
        let compactExpected: [
            (ClampedPanelInteractionController.ResizeEdge, CGPoint)
        ] = [
            (.bottomLeft, CGPoint(x: 9, y: 9)),
            (.bottom, CGPoint(x: 110, y: 5)),
            (.bottomRight, CGPoint(x: 311, y: 9)),
            (.left, CGPoint(x: 5, y: 105)),
            (.right, CGPoint(x: 315, y: 105)),
            (.topLeft, CGPoint(x: 9, y: 171)),
            (.top, CGPoint(x: 110, y: 175)),
            (.topRight, CGPoint(x: 311, y: 171)),
        ]
        let compactProbes = OverlayHitRegionResolver.frozenResizeProbes(
            size: CGSize(width: 320, height: 180)
        )
        XCTAssertEqual(compactProbes.map(\.edge), compactExpected.map { $0.0 })
        XCTAssertEqual(compactProbes.map(\.point), compactExpected.map { $0.1 })

        for size in m6ResizeSizeMatrix() {
            let resolver = OverlayHitRegionResolver(
                metrics: OverlayLayoutMetrics(size: size)
            )
            let probes = OverlayHitRegionResolver.frozenResizeProbes(size: size)
            XCTAssertEqual(Set(probes.map(\.edge)).count, 8)
            for probe in probes {
                XCTAssertEqual(
                    resolver.resolve(point: probe.point),
                    .resize(probe.edge),
                    "\(size):\(probe.edge)"
                )
            }
        }
    }

    func testHostedQuickControlsUseFullRectangularTargetsWithCircularPaint() {
        let source = try! String(
            contentsOf: sourceURL("OverlayQuickControlsView.swift"), encoding: .utf8
        )
        XCTAssertEqual(source.components(separatedBy: ".contentShape(Rectangle())").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "Circle().fill(fill(configuration:").count - 1, 1)

        for size in M6VisualTestSupport.tierSizes {
            let metrics = OverlayLayoutMetrics(size: size)
            for region in metrics.quickControlRegions {
                let corners = [
                    CGPoint(x: region.frame.minX + 0.5, y: region.frame.minY + 0.5),
                    CGPoint(x: region.frame.maxX - 0.5, y: region.frame.minY + 0.5),
                    CGPoint(x: region.frame.minX + 0.5, y: region.frame.maxY - 0.5),
                    CGPoint(x: region.frame.maxX - 0.5, y: region.frame.maxY - 0.5),
                ]
                for point in corners {
                    let probe = M6VisualTestSupport.HostedRootProbe(size: size)
                    let before = probe.controlState
                    probe.press(at: point)
                    assertQuickControlMutation(
                        region.identifier, before: before, after: probe.controlState
                    )
                }
            }
        }
    }

    func testHostedRootDispatchesEveryControlResizeAndTitleRouteAcrossTiers() {
        for size in M6VisualTestSupport.tierSizes {
            let metrics = OverlayLayoutMetrics(size: size)
            for region in metrics.quickControlRegions {
                let probe = M6VisualTestSupport.HostedRootProbe(size: size)
                let before = probe.controlState
                probe.press(at: CGPoint(x: region.frame.midX, y: region.frame.midY))
                assertQuickControlMutation(
                    region.identifier, before: before, after: probe.controlState
                )
                XCTAssertTrue(probe.resizeChanges.isEmpty, region.identifier)
                XCTAssertTrue(probe.titleChanges.isEmpty, region.identifier)
            }

            for resize in OverlayHitRegionResolver.frozenResizeProbes(size: size) {
                let probe = M6VisualTestSupport.HostedRootProbe(size: size)
                probe.drag(from: resize.point, by: CGSize(width: 7, height: 5))
                XCTAssertEqual(probe.resizeChanges.map(\.edge), [resize.edge])
                XCTAssertEqual(probe.resizeEndCount, 1)
                XCTAssertTrue(probe.titleChanges.isEmpty)
                XCTAssertEqual(probe.titleEndCount, 0)
            }

            let titleProbe = M6VisualTestSupport.HostedRootProbe(size: size)
            let titlePoint = CGPoint(
                x: metrics.titleDragFrame.midX, y: metrics.titleDragFrame.midY
            )
            titleProbe.drag(from: titlePoint, by: CGSize(width: 7, height: 5))
            XCTAssertEqual(titleProbe.titleChanges.count, 1)
            XCTAssertEqual(titleProbe.titleEndCount, 1)
            XCTAssertTrue(titleProbe.resizeChanges.isEmpty)
            XCTAssertEqual(titleProbe.resizeEndCount, 0)

            let headerProbe = M6VisualTestSupport.HostedRootProbe(size: size)
            let playback = metrics.headerControlRegions[0]
            headerProbe.press(at: CGPoint(x: playback.frame.midX, y: playback.frame.midY))
            XCTAssertFalse(headerProbe.controlState.isPaused)
            XCTAssertTrue(headerProbe.titleChanges.isEmpty)
            XCTAssertTrue(headerProbe.resizeChanges.isEmpty)
        }
    }

    func testHostedSettingsPressShowsExistingControllerExactlyOnceWithoutActivation() {
        for size in M6VisualTestSupport.tierSizes {
            let probe = M6VisualTestSupport.HostedRootProbe(size: size)
            let wasActive = NSApp.isActive
            XCTAssertTrue(
                probe.pressAccessibilityControl(
                    identifier: "privatePresenter.headerSettings"
                )
            )
            XCTAssertEqual(probe.showExistingControllerCount, 1)
            XCTAssertEqual(NSApp.isActive, wasActive)
            XCTAssertTrue(probe.titleChanges.isEmpty)
            XCTAssertTrue(probe.resizeChanges.isEmpty)
        }
    }

    func testHostedLockedChromeLeavesAccessibilityAndReaderStateUnchanged() {
        for size in M6VisualTestSupport.tierSizes {
            let probe = M6VisualTestSupport.HostedRootProbe(size: size)
            let baseline = probe.readerEvidence
            XCTAssertEqual(
                probe.accessibilityIdentifiers.intersection(
                    M6VisualTestSupport.HostedRootProbe.chromeIdentifiers
                ),
                M6VisualTestSupport.HostedRootProbe.chromeIdentifiers
            )

            for state in [
                M6VisualTestSupport.RenderState.lockedVisible,
                .lockedFocusHidden,
            ] {
                probe.setRenderState(state)
                XCTAssertTrue(
                    probe.accessibilityIdentifiers.intersection(
                        M6VisualTestSupport.HostedRootProbe.chromeIdentifiers
                    ).isEmpty
                )
                XCTAssertEqual(probe.readerEvidence, baseline)
            }
        }
    }

    func testDefaultUnlockedHostedHeaderOffersLockTeleprompter() {
        for size in M6VisualTestSupport.tierSizes {
            let probe = M6VisualTestSupport.HostedRootProbe(size: size)
            let lock = probe.accessibilityControl(
                identifier: "privatePresenter.headerLock"
            )
            XCTAssertEqual(lock?.label, "Lock teleprompter")
            XCTAssertEqual(lock?.isEnabled, true)
        }
    }

    func testPlaybackTargetsRespectExistingPresentationEligibility() {
        let playbackIdentifiers = [
            "privatePresenter.headerPlayback",
            "privatePresenter.quickPlayback",
        ]
        for scriptText in ["", "  \n\t  "] {
            let probe = M6VisualTestSupport.HostedRootProbe(
                size: CGSize(width: 700, height: 350), scriptText: scriptText
            )
            for identifier in playbackIdentifiers {
                let control = probe.accessibilityControl(identifier: identifier)
                XCTAssertEqual(control?.label, "Start scrolling")
                XCTAssertEqual(control?.isEnabled, false)
            }
        }

        let playing = M6VisualTestSupport.HostedRootProbe(
            size: CGSize(width: 700, height: 350), initiallyPlaying: true
        )
        for identifier in playbackIdentifiers {
            let control = playing.accessibilityControl(identifier: identifier)
            XCTAssertEqual(control?.label, "Pause scrolling")
            XCTAssertEqual(control?.isEnabled, true)
        }

        let source = try! String(
            contentsOf: sourceURL("OverlayQuickControlsView.swift"), encoding: .utf8
        )
        XCTAssertEqual(
            source.components(
                separatedBy: ".opacity(accessibility.isEnabled ? 1 : 0.45)"
            ).count - 1,
            1
        )
    }

    func testCompactActiveBandUsesReservedReadingRectMidpoint() {
        let size = NSSize(width: 480, height: 300)
        let viewport = makeReader(
            text: (1...30).map { "Compact line \($0)" }.joined(separator: "\n"),
            size: size
        )
        let metrics = OverlayLayoutMetrics(size: size)
        XCTAssertEqual(metrics.tier, .compact)
        let expectedMidpoint = metrics.readerViewportFrame.minY
            + metrics.readerViewportFrame.height * 0.5
        XCTAssertEqual(
            viewport.system.activeBandView.frame.midY, expectedMidpoint, accuracy: 1e-9
        )
        XCTAssertNotEqual(
            viewport.system.activeBandView.frame.midY, viewport.container.bounds.midY
        )
    }

    func testAttachedAttributeReconciliationRefreshesCachedBandWithoutReaderMutation() {
        let text = (1...80).map { "Attribute line \($0)" }.joined(separator: "\n")
        let viewport = makeReader(
            text: text, size: NSSize(width: 700, height: 350), fontSize: 42
        )
        let storage = viewport.system.textStorage
        let replacements = viewport.system.fullReplacementCount
        let mutations = viewport.system.textMutationCount
        let resyncs = viewport.system.resyncRequestCount
        let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)
        let initialFrames = viewport.container.resolvedBandFragments.map(\.frame)

        for (fontSize, weight) in [
            (96.0, TeleprompterFontWeight.regular),
            (96.0, .medium),
            (96.0, .semibold),
        ] {
            viewport.system.updateAttributes(
                fontSize: fontSize, fontWeight: weight, alignment: .left
            )
            _ = viewport.adapter.restore(anchor: anchor)
            viewport.system.refreshActiveBandAfterAttributeChange()

            XCTAssertEqual(viewport.container.resolvedBandFragments.count, 2)
            let expectedHeight = ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: viewport.container.resolvedBandFragments,
                fallbackLineHeight: viewport.system.fallbackLineHeight(
                    backingScaleFactor: 2
                ),
                maximumHeight: viewport.container.maximumActiveBandHeight
            )
            XCTAssertEqual(
                viewport.container.resolvedActiveBandHeight, expectedHeight, accuracy: 1
            )
            XCTAssertEqual(
                viewport.system.activeBandView.frame.height, expectedHeight, accuracy: 1
            )
            XCTAssertEqual(viewport.system.effectiveFont.pointSize, fontSize)
            let expectedWeight: NSFont.Weight
            switch weight {
            case .regular: expectedWeight = .regular
            case .medium: expectedWeight = .medium
            case .semibold: expectedWeight = .semibold
            }
            XCTAssertEqual(ReaderTextSystem.appKitWeight(for: weight), expectedWeight)
            XCTAssertTrue(viewport.system.textStorage === storage)
            XCTAssertEqual(viewport.system.textStorage.string, text)
            XCTAssertEqual(viewport.system.fullReplacementCount, replacements)
            XCTAssertEqual(viewport.system.textMutationCount, mutations)
            XCTAssertEqual(viewport.system.resyncRequestCount, resyncs)
            XCTAssertFalse(viewport.system.isAwaitingResync)
            XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, anchor.utf16Offset)
            XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.document, anchor.document)
        }

        XCTAssertNotEqual(viewport.container.resolvedBandFragments.map(\.frame), initialFrames)
    }

    func testClipOriginRefreshUsesExactCachedTargetAndCoalescesAtLineBoundaries() {
        let lines = (1...60).map { "Cached height line \($0)" }
        let text = lines.joined(separator: "\n")
        let viewport = makeReader(
            text: text, size: NSSize(width: 700, height: 350), fontSize: 24
        )
        let nsText = text as NSString
        for (index, line) in lines.enumerated() {
            viewport.system.textStorage.addAttribute(
                .font,
                value: NSFont.systemFont(
                    ofSize: (index + 1).isMultiple(of: 3) ? 60 : 24
                ),
                range: nsText.range(of: line)
            )
        }
        viewport.container.needsLayout = true
        viewport.container.layoutSubtreeIfNeeded()
        viewport.container.refreshActiveBandLayoutFromCachedMetrics(force: true)

        let cached = viewport.adapter.cachedLineFragmentEvidence
        XCTAssertGreaterThan(Set(cached.map { Int($0.frame.height.rounded()) }).count, 1)
        let fraction = 0.5
        let samples = stride(
            from: 0.0, through: floor(viewport.adapter.maximumOffset), by: 1
        ).map { offset -> (Double, [Range<Int>], CGFloat) in
            let target = offset + Double(viewport.adapter.clipSize.height) * fraction
            let selected = ReaderViewportAdapter.selectActiveBandLineFragments(
                from: cached, targetY: target
            )
            return (
                offset, selected.map(\.utf16Range),
                selected.reduce(12) { $0 + $1.frame.height }
            )
        }
        guard let first = samples.first,
            let samePair = samples.dropFirst().first(where: { $0.1 == first.1 }),
            let changedPair = samples.first(where: {
                $0.1 != first.1 && abs($0.2 - first.2) > 0.5
            })
        else {
            XCTFail("Expected cached same-pair and unequal-height boundary samples")
            return
        }

        var completedLayouts = 0
        viewport.system.onLayoutCompleted = { completedLayouts += 1 }
        let storage = viewport.system.textStorage
        let mutations = viewport.system.textMutationCount

        viewport.adapter.setClipOriginY(first.0)
        assertCachedBandMatchesExactTarget(viewport, fraction: fraction)
        let firstFrame = viewport.system.activeBandView.frame
        viewport.adapter.setClipOriginY(samePair.0)
        assertCachedBandMatchesExactTarget(viewport, fraction: fraction)
        XCTAssertEqual(viewport.system.activeBandView.frame, firstFrame)

        viewport.adapter.setClipOriginY(changedPair.0)
        assertCachedBandMatchesExactTarget(viewport, fraction: fraction)
        XCTAssertEqual(
            viewport.container.resolvedBandFragments.map(\.utf16Range), changedPair.1
        )
        XCTAssertNotEqual(viewport.system.activeBandView.frame.height, firstFrame.height)
        XCTAssertEqual(completedLayouts, 0)
        XCTAssertTrue(viewport.system.textStorage === storage)
        XCTAssertEqual(viewport.system.textStorage.string, text)
        XCTAssertEqual(viewport.system.textMutationCount, mutations)

        let source = try! String(
            contentsOf: sourceURL("ReaderViewportAdapter.swift"), encoding: .utf8
        )
        let start = source.range(of: "func setClipOriginY")!.lowerBound
        let end = source.range(of: "func threeCompleteLineStep")!.lowerBound
        let clipRefresh = source[start..<end]
        XCTAssertFalse(clipRefresh.contains("ensureLayout("))
        XCTAssertFalse(clipRefresh.contains("model"))
        XCTAssertFalse(clipRefresh.contains(".send("))
    }

    func testCachedBandSelectionPreservesSortedMetricsAndFollowingTieBreakWithoutResort() {
        let lines = [
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 0..<1, frame: NSRect(x: 0, y: 0, width: 100, height: 20)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 1..<2, frame: NSRect(x: 0, y: 30, width: 100, height: 30)
            ),
            ReaderViewportAdapter.LineFragmentEvidence(
                utf16Range: 2..<3, frame: NSRect(x: 0, y: 70, width: 100, height: 40)
            ),
        ]
        let target = (Double(lines[0].frame.midY) + Double(lines[1].frame.midY)) / 2
        XCTAssertEqual(
            ReaderViewportAdapter.selectActiveBandLineFragments(
                from: lines, targetY: target
            ).map(\.utf16Range),
            [0..<1, 1..<2]
        )

        let source = try! String(
            contentsOf: sourceURL("ReaderViewportAdapter.swift"), encoding: .utf8
        )
        let start = source.range(of: "static func selectActiveBandLineFragments")!.lowerBound
        let end = source.range(of: "func captureAnchor")!.lowerBound
        let selectionSource = source[start..<end]
        XCTAssertFalse(selectionSource.contains(".sorted"))
        XCTAssertTrue(
            selectionSource.contains(
                "candidates[lhs].frame.midY > candidates[rhs].frame.midY"
            )
        )
    }

    func testActualOverlayRenderMatchesIndependentSemanticBaseline() throws {
        let rendered = try M6VisualTestSupport.renderCanonicalOverlay()
        let fragmentHeights = try M6VisualTestSupport.measureSyntheticTextKitFragmentHeights()
        let oracle = try M6VisualTestSupport.makeCanonicalSemanticOracle(
            fragmentHeights: fragmentHeights
        )
        let comparison = M6VisualTestSupport.compare(rendered.image, with: oracle)

        XCTAssertTrue(comparison.interiorAlphaIsExact, comparison.summary)
        XCTAssertTrue(comparison.checkerboardsMatch, comparison.summary)
        XCTAssertTrue(comparison.outsideCornersAreClear, comparison.summary)
        XCTAssertTrue(comparison.gradientProbesPass, comparison.summary)
        XCTAssertTrue(comparison.geometryPasses, comparison.summary)
        XCTAssertTrue(comparison.regionErrorsPass, comparison.summary)
        XCTAssertTrue(comparison.structuralErrorsPass, comparison.summary)
        XCTAssertTrue(comparison.passed, comparison.summary)
    }

    func testSemanticComparatorRejectsEveryNamedCorruption() throws {
        let rendered = try M6VisualTestSupport.renderCanonicalOverlay()
        let fragmentHeights = try M6VisualTestSupport.measureSyntheticTextKitFragmentHeights()
        let oracle = try M6VisualTestSupport.makeCanonicalSemanticOracle(
            fragmentHeights: fragmentHeights
        )
        for corruption in M6VisualTestSupport.Corruption.allCases {
            let corrupted = try M6VisualTestSupport.corrupt(
                rendered.image, corruption: corruption
            )
            let comparison = M6VisualTestSupport.compare(corrupted, with: oracle)
            XCTAssertFalse(comparison.passed, "\(corruption) escaped every metric")
            XCTAssertTrue(
                comparison.failedMetrics.contains(corruption.expectedFailureMetric),
                "\(corruption): \(comparison.summary)"
            )
        }
    }

    func testIndependentContinuousMaskRejectsWrongRadiusAndStyle() throws {
        let canonical = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 30, style: .continuous
        )
        let wrongRadius = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 29, style: .continuous
        )
        let wrongStyle = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 30, style: .circular
        )

        XCTAssertTrue(M6VisualTestSupport.cardMaskMatchesCanonical(canonical))
        XCTAssertFalse(M6VisualTestSupport.cardMaskMatchesCanonical(wrongRadius))
        XCTAssertFalse(M6VisualTestSupport.cardMaskMatchesCanonical(wrongStyle))
    }

    func testRenderMatrixPreservesContainmentOpacityAndFocusGeometry() throws {
        for size in M6VisualTestSupport.renderSizes {
            let scenes = try M6VisualTestSupport.RenderState.allCases.map {
                try M6VisualTestSupport.render(size: size, state: $0)
            }
            for scene in scenes {
                XCTAssertTrue(scene.interiorIsOpaque, "\(size):\(scene.state)")
                XCTAssertTrue(scene.structuresAreContained, "\(size):\(scene.state)")
                XCTAssertEqual(scene.readerGeometry, scenes[0].readerGeometry)
            }
            XCTAssertEqual(scenes[1].readerFingerprint, scenes[2].readerFingerprint)
            XCTAssertFalse(scenes[1].chromeIsAccessibilityNavigable)
            XCTAssertFalse(scenes[2].chromeIsAccessibilityNavigable)
        }
    }

    func testNativeRenderAttributesAndFramesRemainExplicit() throws {
        let rendered = try M6VisualTestSupport.renderCanonicalOverlay()
        XCTAssertEqual(rendered.size, CGSize(width: 1_036, height: 460))
        XCTAssertEqual(rendered.scale, 2)
        XCTAssertEqual(rendered.localeIdentifier, "en_US_POSIX")
        XCTAssertEqual(rendered.layoutDirection, .leftToRight)
        XCTAssertEqual(rendered.appearanceName, .darkAqua)
        XCTAssertEqual(rendered.font.pointSize, 42)
        XCTAssertEqual(rendered.paragraphStyle.lineHeightMultiple, 1.42, accuracy: 0.000_001)
        XCTAssertEqual(rendered.textColor.colorSpace, .sRGB)
        XCTAssertEqual(rendered.readerFrame, CGRect(x: 52, y: 124, width: 932, height: 222))
        XCTAssertEqual(rendered.toolbarFrame, CGRect(x: 324.5, y: 24, width: 387, height: 65))
    }

    func testActualRenderBufferUsesNamedSRGBEightBitPremultipliedRGBA() throws {
        let rendered = try M6VisualTestSupport.renderCanonicalOverlay()
        XCTAssertEqual(rendered.image.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(rendered.image.bitsPerComponent, 8)
        XCTAssertEqual(rendered.image.bitsPerPixel, 32)
        XCTAssertEqual(rendered.image.bytesPerRow, rendered.image.width * 4)
        XCTAssertEqual(rendered.image.alphaInfo, .premultipliedLast)
        XCTAssertFalse(rendered.bitmapUsesNonpremultipliedAlpha)
    }

    func testOffscreenTextKitRenderHostUsesAssertedTwoXBackingScale() throws {
        for size in M6VisualTestSupport.renderSizes {
            let rendered = try M6VisualTestSupport.render(
                size: size, state: .unlocked
            )
            XCTAssertEqual(rendered.scale, 2)
            XCTAssertEqual(rendered.effectiveBackingScale, 2)
            XCTAssertEqual(rendered.textKitBandBackingScale, 2)
            XCTAssertEqual(rendered.image.width, Int(size.width * 2))
            XCTAssertEqual(rendered.image.height, Int(size.height * 2))
        }
    }

    func testSemanticOracleBandUsesTwoIndependentlyMeasuredTextKitFragmentHeights() throws {
        let heights = try M6VisualTestSupport.measureSyntheticTextKitFragmentHeights()
        XCTAssertEqual(heights.count, 2)
        XCTAssertTrue(heights.allSatisfy { $0.isFinite && $0 > 0 })

        let oracle = try M6VisualTestSupport.makeCanonicalSemanticOracle(
            fragmentHeights: heights
        )
        let band = try XCTUnwrap(oracle.regions["band"])
        XCTAssertEqual(band.height, heights[0] + heights[1] + 12, accuracy: 0.001)

        let firstMutation = try M6VisualTestSupport.makeCanonicalSemanticOracle(
            fragmentHeights: [heights[0] + 3, heights[1]]
        )
        let secondMutation = try M6VisualTestSupport.makeCanonicalSemanticOracle(
            fragmentHeights: [heights[0], heights[1] + 5]
        )
        XCTAssertEqual(
            try XCTUnwrap(firstMutation.regions["band"]).height,
            band.height + 3,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(secondMutation.regions["band"]).height,
            band.height + 5,
            accuracy: 0.001
        )
    }

    func testCanonicalFrameworkMaskStaysLiteralIndependentAndMutationSensitive() throws {
        let supportURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("M6VisualTestSupport.swift")
        let support = try String(contentsOf: supportURL, encoding: .utf8)
        let literalPath = "RoundedRectangle(cornerRadius: 30, style: .continuous)"
            + ".path(in: literalBounds).cgPath"
        XCTAssertEqual(support.components(separatedBy: literalPath).count - 1, 1)
        XCTAssertFalse(support.contains("OverlayVisualTokens"))
        XCTAssertFalse(support.contains("OverlayLayoutMetrics"))

        let canonical = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 30, style: .continuous
        )
        let wrongRadius = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 29, style: .continuous
        )
        let wrongStyle = try M6VisualTestSupport.makeLiteralCardMask(
            radius: 30, style: .circular
        )
        XCTAssertTrue(M6VisualTestSupport.cardMaskMatchesCanonical(canonical))
        XCTAssertFalse(M6VisualTestSupport.cardMaskMatchesCanonical(wrongRadius))
        XCTAssertFalse(M6VisualTestSupport.cardMaskMatchesCanonical(wrongStyle))
    }

    private func assertCachedBandMatchesExactTarget(
        _ viewport: (
            system: ReaderTextSystem,
            container: ReaderViewportContainerView,
            adapter: ReaderViewportAdapter
        ),
        fraction: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exactTarget = viewport.adapter.clipOriginY
            + Double(viewport.adapter.clipSize.height) * fraction
        let expected = ReaderViewportAdapter.selectActiveBandLineFragments(
            from: viewport.adapter.cachedLineFragmentEvidence, targetY: exactTarget
        )
        XCTAssertEqual(
            viewport.container.resolvedBandFragments.map(\.utf16Range),
            expected.map(\.utf16Range),
            file: file, line: line
        )
        XCTAssertEqual(
            viewport.container.resolvedActiveBandHeight,
            ReaderViewportContainerView.resolvedActiveBandHeight(
                fragments: expected,
                fallbackLineHeight: viewport.system.fallbackLineHeight(
                    backingScaleFactor: 2
                ),
                maximumHeight: viewport.container.maximumActiveBandHeight
            ),
            accuracy: 1,
            file: file, line: line
        )
    }

    private func assertQuickControlMutation(
        _ identifier: String,
        before: M6VisualTestSupport.HostedControlState,
        after: M6VisualTestSupport.HostedControlState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var expected = before
        switch identifier {
        case "privatePresenter.quickSmaller":
            expected.fontSizePoints -= PresenterAccessibility.fontSizeStep
        case "privatePresenter.quickLarger":
            expected.fontSizePoints += PresenterAccessibility.fontSizeStep
        case "privatePresenter.quickAlignment":
            expected.alignment = before.alignment == .left ? .center : .left
        case "privatePresenter.quickSlower":
            expected.speedPointsPerSecond -= PresenterAccessibility.speedStep
        case "privatePresenter.quickPlayback":
            expected.isPaused.toggle()
        case "privatePresenter.quickFaster":
            expected.speedPointsPerSecond += PresenterAccessibility.speedStep
        case "privatePresenter.quickFocus":
            expected.isFocusModeEnabled.toggle()
        default:
            XCTFail("Unexpected quick control: \(identifier)", file: file, line: line)
        }
        XCTAssertEqual(after, expected, identifier, file: file, line: line)
    }

    private func assertColor(
        _ color: NSColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let converted = try XCTUnwrap(color.usingColorSpace(.sRGB), file: file, line: line)
        XCTAssertEqual(converted.redComponent, red / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.greenComponent, green / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.blueComponent, blue / 255, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(converted.alphaComponent, alpha, accuracy: 0.000_001, file: file, line: line)
    }

    private func assertPixelSubset(
        _ rect: CGRect,
        inside path: CGPath,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for y in Int(floor(rect.minY))..<Int(ceil(rect.maxY)) {
            for x in Int(floor(rect.minX))..<Int(ceil(rect.maxX)) {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                guard point.x >= rect.minX, point.x < rect.maxX,
                    point.y >= rect.minY, point.y < rect.maxY
                else { continue }
                XCTAssertTrue(path.contains(point), "\(rect) excludes \(point)", file: file, line: line)
            }
        }
    }

    private func m6ResizeSizeMatrix() -> [CGSize] {
        let fixed = [
            CGSize(width: 320, height: 180),
            CGSize(width: 700, height: 350),
            CGSize(width: 1_036, height: 460),
            CGSize(width: 1_440, height: 460),
        ]
        let policy = PanelFramePolicy()
        let controlledDisplays = [
            DisplayRect(x: 0, y: 0, width: 1_920, height: 1_080),
            DisplayRect(x: -2_560, y: 0, width: 2_560, height: 1_440),
        ]
        let defaults = controlledDisplays.map { display -> CGSize in
            let frame = policy.defaultFrame(in: display)
            XCTAssertEqual(frame.width, display.width * 0.70)
            XCTAssertEqual(frame.height, display.height * 0.35)
            return CGSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
        }
        return fixed + defaults
    }

    private func composite(
        _ foreground: NSColor,
        over background: NSColor
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let alpha = foreground.alphaComponent
        return (
            foreground.redComponent * alpha + background.redComponent * (1 - alpha),
            foreground.greenComponent * alpha + background.greenComponent * (1 - alpha),
            foreground.blueComponent * alpha + background.blueComponent * (1 - alpha)
        )
    }

    private func makeReader(
        text: String,
        size: NSSize,
        fontSize: Double = 42,
        fontWeight: TeleprompterFontWeight = .regular
    ) -> (
        system: ReaderTextSystem,
        container: ReaderViewportContainerView,
        adapter: ReaderViewportAdapter
    ) {
        let system = ReaderTextSystem(text: text, revision: 0)
        system.updateAttributes(
            fontSize: fontSize, fontWeight: fontWeight, alignment: .left
        )
        let container = ReaderTextView.makeReaderView(system: system)
        container.frame = NSRect(origin: .zero, size: size)
        container.layoutSubtreeIfNeeded()
        return (system, container, container.viewportAdapter)
    }

    private func m6AccessibilityState() -> PresenterAccessibility.State {
        PresenterAccessibility.State(
            scriptTitle: "Lecture Teleprompter",
            scriptText: "Synthetic script",
            displayName: "Synthetic private display",
            fontSizePoints: 42,
            speedPointsPerSecond: 60,
            alignment: .left,
            isActiveBandEnabled: true,
            isPlaying: false,
            isVisible: true,
            isLocked: false,
            isFocusModeEnabled: false,
            retryShortcutsVisible: false,
            topologyStatus: .extended
        )
    }

    private func sourceURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Overlay")
            .appendingPathComponent(file)
    }

    private func contrast(
        _ lhs: (Double, Double, Double),
        _ rhs: (Double, Double, Double)
    ) -> Double {
        let first = luminance(lhs)
        let second = luminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func luminance(_ color: (Double, Double, Double)) -> Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.0) + 0.7152 * linear(color.1)
            + 0.0722 * linear(color.2)
    }
}
