import AppKit
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class ScrollSessionControllerTests: XCTestCase {
    func testReaderHidesScrollerAndClips() {
        let viewport = makeViewport(text: longText)

        XCTAssertFalse(viewport.container.scrollView.hasVerticalScroller)
        XCTAssertFalse(viewport.container.scrollView.hasHorizontalScroller)
        XCTAssertEqual(viewport.container.scrollView.verticalScrollElasticity, .none)
        XCTAssertEqual(viewport.container.scrollView.horizontalScrollElasticity, .none)
        XCTAssertTrue(viewport.container.scrollView.contentView is ReaderClipView)
        XCTAssertTrue(viewport.container.scrollView.documentView === viewport.system.textView)
        XCTAssertTrue(ReaderScrollView.userScrollingIsDisabled)
        XCTAssertNotNil(viewport.system.textView.textLayoutManager)
    }

    func testMaximumOffsetAccountsForToolbarInset() {
        let viewport = makeViewport(text: longText, size: NSSize(width: 420, height: 220))
        let expected = max(
            0,
            viewport.adapter.laidOutTextBottom
                + ReaderViewportAdapter.documentBottomPadding
                - Double(viewport.adapter.clipSize.height)
        )

        XCTAssertEqual(viewport.adapter.maximumOffset, expected, accuracy: 1e-9)
    }

    func testBandDoesNotBecomeTextSelection() {
        let viewport = makeViewport(text: longText)

        XCTAssertFalse(viewport.system.textView.isSelectable)
        XCTAssertFalse(viewport.system.textView.isEditable)
        XCTAssertEqual(viewport.system.textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(viewport.system.activeBandView is NSTextView)
    }

    func testRestorePlacesAnchorAtBand() throws {
        let viewport = makeViewport(text: longText, viewportFraction: 0.4)
        let anchor = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Line 12", in: longText),
            viewportFraction: 0.4,
            document: longText
        )

        _ = viewport.adapter.restore(anchor: anchor)
        let anchorY = try XCTUnwrap(
            viewport.adapter.anchorY(forUTF16Offset: anchor.utf16Offset)
        )

        XCTAssertEqual(
            anchorY - viewport.adapter.clipOriginY,
            Double(viewport.adapter.clipSize.height) * 0.4,
            accuracy: 1
        )
        let captured = viewport.adapter.captureAnchor(viewportFraction: 0.4)
        XCTAssertTrue(isScalarBoundary(captured.utf16Offset, in: longText))
        XCTAssertEqual(captured.viewportFraction, 0.4)
    }

    func testScrollTickPerformsNoTextMutation() {
        let viewport = makeViewport(text: longText)
        let originalText = viewport.system.textStorage.string
        let originalMutationCount = viewport.adapter.textMutationCount

        viewport.adapter.setClipOriginY(min(40, viewport.adapter.maximumOffset))

        XCTAssertEqual(viewport.system.textStorage.string, originalText)
        XCTAssertEqual(viewport.adapter.textMutationCount, originalMutationCount)
    }

    func testReaderLayerOrderIsBackgroundBandThenTransparentClip() {
        let viewport = makeViewport(text: "Layer order")

        XCTAssertEqual(viewport.container.subviews.count, 3)
        XCTAssertTrue(viewport.container.subviews[0] === viewport.container.backgroundView)
        XCTAssertTrue(viewport.container.subviews[1] === viewport.system.activeBandView)
        XCTAssertTrue(viewport.container.subviews[2] === viewport.container.scrollView)
        XCTAssertFalse(viewport.container.scrollView.drawsBackground)
        XCTAssertFalse(viewport.container.scrollView.contentView.drawsBackground)
        XCTAssertFalse(viewport.system.textView.drawsBackground)
        XCTAssertEqual(viewport.container.backgroundView.layer?.backgroundColor?.alpha, 1)
    }

    func testBottomDocumentPaddingIsExactlySixtyFourPoints() {
        let viewport = makeViewport(text: longText, size: NSSize(width: 420, height: 220))

        XCTAssertEqual(ReaderViewportAdapter.documentBottomPadding, 64)
        XCTAssertEqual(
            Double(viewport.system.textView.frame.height),
            max(
                Double(viewport.adapter.clipSize.height),
                viewport.adapter.laidOutTextBottom + 64
            ),
            accuracy: 1
        )
    }

    func testExistingHeaderIsNotDoubleCountedInMaximumOffset() {
        let viewport = makeViewport(text: longText, size: NSSize(width: 420, height: 220))
        let expected = max(
            0,
            viewport.adapter.laidOutTextBottom
                + 64
                - Double(viewport.adapter.clipSize.height)
        )

        XCTAssertEqual(viewport.adapter.maximumOffset, expected, accuracy: 1e-9)
        XCTAssertNotEqual(viewport.adapter.maximumOffset, expected + 36, accuracy: 1e-9)
    }

    func testBandUsesPersistedViewportFractionAndFixedHeight() {
        let viewport = makeViewport(text: "Band", viewportFraction: 0.3)

        XCTAssertEqual(viewport.system.activeBandView.frame.height, 84, accuracy: 1e-9)
        XCTAssertEqual(
            viewport.system.activeBandView.frame.midY,
            viewport.container.bounds.height * 0.3,
            accuracy: 1e-9
        )

        viewport.adapter.setClipOriginY(min(20, viewport.adapter.maximumOffset))

        XCTAssertEqual(viewport.system.activeBandView.frame.height, 84, accuracy: 1e-9)
        XCTAssertEqual(
            viewport.system.activeBandView.frame.midY,
            viewport.container.bounds.height * 0.3,
            accuracy: 1e-9
        )
    }

    func testBandIsNonHitTestingAndAccessibilityIgnored() {
        let viewport = makeViewport(text: "Band")
        let band = viewport.system.activeBandView

        XCTAssertNil(band.hitTest(NSPoint(x: band.bounds.midX, y: band.bounds.midY)))
        XCTAssertFalse(band.isAccessibilityElement())
    }

    func testIncrementalEditRestoresMappedAnchor() throws {
        let preEdit = longText
        let viewport = makeViewport(text: preEdit)
        let seed = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Line 10", in: preEdit),
            viewportFraction: 0.5,
            document: preEdit
        )
        _ = viewport.adapter.restore(anchor: seed)
        let priorAnchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)
        XCTAssertTrue(isScalarBoundary(priorAnchor.utf16Offset, in: preEdit))
        let edit = try ScriptTextEdit.replacing(
            in: preEdit,
            range: UTF16TextRange(location: 0, length: 0),
            with: "Preface\n",
            baseRevision: 0
        )
        let postEdit = try edit.applying(to: preEdit, revision: 0)
        let mapping = ReadingPositionMapper.map(
            anchor: priorAnchor,
            editedRangeUTF16: NSRange(location: edit.range.location, length: edit.range.length),
            replacement: edit.replacement,
            preEditDocument: preEdit,
            postEditDocument: postEdit
        )

        viewport.system.apply(edit)
        viewport.adapter.ensureLayout()
        _ = viewport.adapter.restore(anchor: mapping.anchor)

        XCTAssertFalse(mapping.requiresPause)
        XCTAssertEqual(viewport.system.incrementalMutationCount, 1)
        XCTAssertEqual(viewport.system.textStorage.string, postEdit)
        XCTAssertEqual(
            mapping.anchor.utf16Offset,
            priorAnchor.utf16Offset + "Preface\n".utf16.count
        )
        XCTAssertTrue(isScalarBoundary(mapping.anchor.utf16Offset, in: postEdit))
        XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, mapping.anchor.utf16Offset)
        try assert(anchor: mapping.anchor, isAtBandIn: viewport.adapter)
    }

    func testInsertionAtAnchorPausesAndRestoresBoundary() throws {
        let text = "Alpha\nBravo\nCharlie"
        let viewport = makeViewport(
            text: text,
            size: NSSize(width: 260, height: 80)
        )
        let seed = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Bravo", in: text),
            viewportFraction: 0.5,
            document: text
        )
        _ = viewport.adapter.restore(anchor: seed)
        let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)
        let anchorOffset = anchor.utf16Offset
        XCTAssertTrue(isScalarBoundary(anchorOffset, in: text))
        let edit = try ScriptTextEdit.replacing(
            in: text,
            range: UTF16TextRange(location: anchorOffset, length: 0),
            with: "Inserted\n",
            baseRevision: 0
        )
        let postEdit = try edit.applying(to: text, revision: 0)
        let mapping = ReadingPositionMapper.map(
            anchor: anchor,
            editedRangeUTF16: NSRange(location: edit.range.location, length: edit.range.length),
            replacement: edit.replacement,
            preEditDocument: text,
            postEditDocument: postEdit
        )

        viewport.system.apply(edit)
        viewport.adapter.ensureLayout()
        _ = viewport.adapter.restore(anchor: mapping.anchor)

        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.anchor.utf16Offset, anchorOffset)
        XCTAssertTrue(isScalarBoundary(mapping.anchor.utf16Offset, in: postEdit))
        XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, anchorOffset)
        try assert(anchor: mapping.anchor, isAtBandIn: viewport.adapter)
    }

    func testRevisionGapResyncIsSynchronousAndSingle() throws {
        var callbackOrder: [String] = []
        let reader = ReaderTextSystem(text: "a", revision: 0) { _ in
            callbackOrder.append("callback")
        }
        let gap = try ScriptTextEdit.replacing(
            in: "ab",
            range: UTF16TextRange(location: 2, length: 0),
            with: "c",
            baseRevision: 1
        )

        callbackOrder.append("before")
        reader.apply(gap)
        callbackOrder.append("after")
        reader.apply(gap)

        XCTAssertEqual(callbackOrder, ["before", "callback", "after"])
        XCTAssertEqual(reader.resyncRequestCount, 1)
        XCTAssertTrue(reader.isAwaitingResync)
    }

    func testResizeRestoresAnchorAtBand() throws {
        let viewport = makeViewport(text: longText)
        let seed = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Line 8", in: longText),
            viewportFraction: 0.5,
            document: longText
        )
        _ = viewport.adapter.restore(anchor: seed)
        let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)

        viewport.container.frame.size = NSSize(width: 500, height: 260)
        viewport.container.layoutSubtreeIfNeeded()
        viewport.adapter.ensureLayout()
        _ = viewport.adapter.restore(anchor: anchor)

        XCTAssertTrue(isScalarBoundary(anchor.utf16Offset, in: longText))
        XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, anchor.utf16Offset)
        try assert(anchor: anchor, isAtBandIn: viewport.adapter)
    }

    func testFontChangeRestoresAnchorAtBand() throws {
        let viewport = makeViewport(text: longText)
        let seed = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Line 8", in: longText),
            viewportFraction: 0.5,
            document: longText
        )
        _ = viewport.adapter.restore(anchor: seed)
        let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)

        viewport.system.updateAttributes(fontSize: 54, alignment: .left)
        viewport.adapter.ensureLayout()
        _ = viewport.adapter.restore(anchor: anchor)

        XCTAssertTrue(isScalarBoundary(anchor.utf16Offset, in: longText))
        XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, anchor.utf16Offset)
        try assert(anchor: anchor, isAtBandIn: viewport.adapter)
    }

    func testAlignmentChangeRestoresAnchorAtBand() throws {
        let viewport = makeViewport(text: longText)
        let seed = ReadingAnchor(
            utf16Offset: utf16Offset(of: "Line 8", in: longText),
            viewportFraction: 0.5,
            document: longText
        )
        _ = viewport.adapter.restore(anchor: seed)
        let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)

        viewport.system.updateAttributes(fontSize: 30, alignment: .center)
        viewport.adapter.ensureLayout()
        _ = viewport.adapter.restore(anchor: anchor)

        XCTAssertTrue(isScalarBoundary(anchor.utf16Offset, in: longText))
        XCTAssertEqual(viewport.adapter.lastRestoredAnchor?.utf16Offset, anchor.utf16Offset)
        try assert(anchor: anchor, isAtBandIn: viewport.adapter)
    }

    func testThreeCompleteLinesPreferredForManualStep() {
        let viewport = makeViewport(text: longText, size: NSSize(width: 480, height: 300))
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 12
        viewport.system.textStorage.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: viewport.system.textStorage.length)
        )
        viewport.adapter.ensureLayout()
        let fragments = viewport.adapter.completeLineFragmentEvidenceInViewport()
        guard fragments.count >= 3 else {
            XCTFail("Expected three complete TextKit 2 line fragments")
            return
        }
        let firstThree = Array(fragments.prefix(3))
        let geometricSpan = Double(firstThree[2].frame.maxY - firstThree[0].frame.minY)
        let heightSum = firstThree.reduce(0.0) { $0 + Double($1.frame.height) }

        XCTAssertNotEqual(geometricSpan, heightSum, accuracy: 0.5)
        XCTAssertEqual(
            viewport.adapter.threeCompleteLineStep(),
            geometricSpan,
            accuracy: 1e-9
        )

        let trailing = makeViewport(
            text: "One\nTwo\nThree\n",
            size: NSSize(width: 480, height: 300)
        )
        let trailingFragments = trailing.adapter.completeLineFragmentEvidenceInViewport()
        XCTAssertTrue(trailingFragments.allSatisfy { !$0.utf16Range.isEmpty })
        XCTAssertTrue(
            trailingFragments.allSatisfy {
                $0.utf16Range.upperBound <= trailing.system.textStorage.length
            }
        )
    }

    func testManualStepFallsBackToClampedViewportFraction() {
        let viewport = makeViewport(text: "One line", size: NSSize(width: 480, height: 300))

        XCTAssertLessThan(
            viewport.adapter.completeLineFragmentEvidenceInViewport().count,
            3
        )
        XCTAssertEqual(viewport.adapter.threeCompleteLineStep(), 80, accuracy: 1e-9)
        XCTAssertEqual(ReaderViewportAdapter.fallbackManualStep(clipHeight: 2_000), 240)
    }

    private let longText = (1...40).map { "Line \($0) synthetic rehearsal text" }.joined(separator: "\n")

    private func makeViewport(
        text: String,
        size: NSSize = NSSize(width: 480, height: 300),
        viewportFraction: Double = 0.5
    ) -> (
        system: ReaderTextSystem,
        container: ReaderViewportContainerView,
        adapter: ReaderViewportAdapter
    ) {
        let system = ReaderTextSystem(text: text, revision: 0)
        system.updateAttributes(fontSize: 30, alignment: .left)
        let container = ReaderTextView.makeReaderView(
            system: system,
            viewportFraction: viewportFraction
        )
        container.frame = NSRect(origin: .zero, size: size)
        container.layoutSubtreeIfNeeded()
        container.viewportAdapter.ensureLayout()
        return (system, container, container.viewportAdapter)
    }

    private func assert(anchor: ReadingAnchor, isAtBandIn adapter: ReaderViewportAdapter) throws {
        let anchorY = try XCTUnwrap(adapter.anchorY(forUTF16Offset: anchor.utf16Offset))
        XCTAssertEqual(
            anchorY - adapter.clipOriginY,
            Double(adapter.clipSize.height) * anchor.viewportFraction,
            accuracy: 1
        )
    }

    private func utf16Offset(of needle: String, in text: String) -> Int {
        let range = text.range(of: needle)!
        return text[..<range.lowerBound].utf16.count
    }

    private func isScalarBoundary(_ offset: Int, in text: String) -> Bool {
        let units = Array(text.utf16)
        guard (0...units.count).contains(offset), offset < units.count else {
            return offset == units.count
        }
        return !(0xDC00...0xDFFF).contains(units[offset])
    }
}

// MARK: - M3.4 transient session and generation integration

extension ScrollSessionControllerTests {
    func testFakeTicksDriveViewport() {
        let h = makeM3Session(maximumOffset: 1_000)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 10)
        h.factory.latest?.fire(at: 10.5)
        XCTAssertEqual(h.viewport.clipOriginY, 30, accuracy: 1e-9)
        XCTAssertEqual(h.viewport.setOriginCount, 1)
    }

    func testPauseStopsClock() {
        let h = makeM3Session()
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 1)
        _ = h.session.stopAndCapture(
            retiring: generation,
            replacement: replacementM3Generation(after: generation),
            reason: .commandPause
        )
        XCTAssertEqual(h.factory.latest?.invalidationCount, 1)
        XCTAssertFalse(h.session.isPlaying)
    }

    func testHiddenPanelStopsClock() {
        let h = makeM3Model()
        h.model.send(.start)
        h.effects.removeAll()
        h.model.send(.hideOverlay)
        XCTAssertEqual(Array(h.effectNames.prefix(2)), ["stop", "hide"])
        XCTAssertEqual(h.model.overlaySession.playbackPhase, .paused)
    }

    func testStaleGenerationCallbackIsIgnored() {
        let h = makeM3Model()
        h.model.send(.start)
        let stale = h.model.currentScrollGeneration
        h.model.send(.pause)
        h.model.send(.scrollCheckpoint(.init(
            generation: stale,
            anchor: ReadingAnchor(utf16Offset: 7),
            pixelOffset: 700,
            uptime: 20
        )))
        XCTAssertNotEqual(h.model.overlaySession.pixelOffset, 700)
    }

    func testTickDoesNotPublishSwiftUIStatePerFrame() {
        let h = makeM3Session(maximumOffset: 1_000)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        h.factory.latest?.fire(at: 0.1)
        h.factory.latest?.fire(at: 0.2)
        XCTAssertEqual(h.viewport.clipOriginY, 12, accuracy: 1e-9)
        XCTAssertTrue(h.events.isEmpty)
    }

    func testEndPublishesOnePausedTransition() {
        let h = makeM3Session(maximumOffset: 10)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        h.factory.latest?.fire(at: 0.5)
        h.factory.latest?.fire(at: 1)
        XCTAssertEqual(h.terminals.map(\.reason), [.reachedEnd])
    }

    func testClockRequiresAttachedReaderView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(view.window)
        XCTAssertNil(DisplayLinkFrameClock.make(attachedTo: view, onTick: { _ in }))
    }

    func testDisplayLinkUsesCommonModeAndTimestamp() throws {
        let source = try String(contentsOfFile: m3OverlaySource("DisplayLinkFrameClock.swift"))
        XCTAssertTrue(source.contains("displayLink(target:selector:)"))
        XCTAssertTrue(source.contains("@objc func displayLinkDidFire(_ link: CADisplayLink)"))
        XCTAssertTrue(source.contains("link.timestamp"))
        XCTAssertTrue(source.contains("RunLoop.main"))
        XCTAssertTrue(source.contains(".common"))
        XCTAssertFalse(source.contains("targetTimestamp"))
        XCTAssertFalse(source.contains("Date()"))
    }

    func testDetachInvalidatesClockBeforeReplacement() {
        let log = M3OperationLog()
        let h = makeM3Session(log: log)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        log.values.removeAll()
        h.session.attachmentDidChange(generation: generation)
        XCTAssertFalse(h.session.isPlaying)
        h.session.start(
            generation: replacementM3Generation(after: generation),
            offset: 0,
            speed: 60,
            uptime: 1
        )
        XCTAssertEqual(Array(log.values.prefix(2)), ["invalidate", "clock"])
    }

    func testScreenMoveInvalidatesAndRecreatesWithoutAutoResume() {
        let h = makeM3Session()
        let first = issuedM3Generation()
        h.session.start(generation: first, offset: 0, speed: 60, uptime: 0)
        h.session.screenDidChange(generation: first)
        XCTAssertEqual(h.factory.clocks.count, 1)
        XCTAssertEqual(h.factory.clocks[0].invalidationCount, 1)
        XCTAssertFalse(h.session.isPlaying)
        h.session.start(
            generation: replacementM3Generation(after: first),
            offset: 0,
            speed: 60,
            uptime: 2
        )
        XCTAssertEqual(h.factory.clocks.count, 2)
    }

    func testTeardownInvalidatesClockAndReleasesOwners() {
        let factory = M3FakeFrameClockFactory()
        weak var weakViewport: M3FakeReaderViewport?
        weak var weakSession: ScrollSessionController?
        autoreleasepool {
            var viewport: M3FakeReaderViewport? = M3FakeReaderViewport()
            var session: ScrollSessionController? = ScrollSessionController(
                viewport: viewport!,
                clockFactory: factory.make,
                onEvent: { _ in }
            )
            weakViewport = viewport
            weakSession = session
            let generation = issuedM3Generation()
            session?.start(generation: generation, offset: 0, speed: 60, uptime: 0)
            session?.teardown(generation: generation)
            XCTAssertEqual(factory.latest?.invalidationCount, 1)
            session = nil
            viewport = nil
        }
        XCTAssertNil(weakSession)
        XCTAssertNil(weakViewport)
    }

    func testAppModelIsSoleSessionGenerationIssuer() throws {
        let model = try String(contentsOfFile: m3AppSource("AppModel.swift"))
        let session = try String(contentsOfFile: m3OverlaySource("ScrollSessionController.swift"))
        let start = try XCTUnwrap(model.range(of: "struct ScrollSessionGeneration"))
        XCTAssertTrue(model[start.lowerBound...].contains("fileprivate init"))
        XCTAssertTrue(model.contains("ScrollSessionGeneration()"))
        XCTAssertFalse(session.contains("ScrollSessionGeneration()"))
        XCTAssertFalse(session.contains("UUID()"))
    }

    func testSpeedChangeDoesNotAdvanceGeneration() {
        let h = makeM3Model()
        h.model.send(.start)
        let generation = h.model.currentScrollGeneration
        h.model.send(.setSpeed(95))
        XCTAssertEqual(h.model.currentScrollGeneration, generation)
        XCTAssertEqual(h.model.preferences.speedPointsPerSecond, 95)
        XCTAssertTrue(h.effects.contains {
            if case .updateScrollSpeed(let value, 95, _) = $0 { return value == generation }
            return false
        })
    }

    func testPauseInvalidatesGenerationBeforeStopEffect() {
        let reference = M3ModelReference()
        var observed: ScrollSessionGeneration?
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "Private rehearsal"),
            effectHandler: { effect in
                guard case .stopScrollSession(let old, let new, _, _, _) = effect else { return }
                XCTAssertNotEqual(old, new)
                XCTAssertEqual(reference.value?.currentScrollGeneration, new)
                observed = new
            }
        )
        reference.value = model
        model.send(.start)
        model.send(.pause)
        XCTAssertEqual(observed, model.currentScrollGeneration)
    }

    func testHideStopsAndCapturesBeforeOrderOut() {
        let h = makeM3Model()
        h.model.send(.start)
        h.effects.removeAll()
        h.model.send(.hideOverlay)
        XCTAssertEqual(Array(h.effectNames.prefix(2)), ["stop", "hide"])
    }

    func testPrivacyLossStopsBeforeShieldMove() {
        let h = makeM3Model()
        h.model.send(.start)
        h.effects.removeAll()
        h.model.send(.topologyWillChange)
        XCTAssertEqual(h.effectNames.first, "stop")
        XCTAssertLessThan(
            try! XCTUnwrap(h.effectNames.firstIndex(of: "stop")),
            try! XCTUnwrap(h.effectNames.firstIndex(of: "query"))
        )
    }

    func testClockUnavailablePublishesExactlyOnePausedTransition() {
        let viewport = M3FakeReaderViewport()
        var events: [ScrollSessionEvent] = []
        let session = ScrollSessionController(
            viewport: viewport,
            clockFactory: { _, _ in nil },
            onEvent: { events.append($0) }
        )
        let generation = issuedM3Generation()
        session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        session.start(generation: generation, offset: 0, speed: 60, uptime: 1)
        let terminals = events.compactMap { event -> ScrollTerminalResult? in
            guard case .terminal(let value) = event else { return nil }
            return value
        }
        XCTAssertEqual(terminals.map(\.reason), [.clockUnavailable])
        XCTAssertFalse(session.isPlaying)
    }

    func testOnlyAuthorizedRetiringGenerationTerminalCaptureIsAccepted() {
        let h = makeM3Model()
        h.model.send(.start)
        h.effects.removeAll()
        h.model.send(.pause)
        guard case .stopScrollSession(let old, let new, let reason, _, _)? = h.effects.first else {
            return XCTFail("Expected authorized retirement pair")
        }
        let capture = ScrollTerminalCapture(
            retiringGeneration: old,
            replacementGeneration: new,
            reason: reason,
            anchor: ReadingAnchor(utf16Offset: 7),
            pixelOffset: 44
        )
        h.model.send(.scrollTerminalCapture(capture))
        let revision = h.model.snapshotRevision
        h.model.send(.scrollTerminalCapture(capture))
        XCTAssertEqual(h.model.overlaySession.readingAnchor.utf16Offset, 7)
        XCTAssertEqual(h.model.overlaySession.pixelOffset, 44)
        XCTAssertEqual(h.model.snapshotRevision, revision)
    }

    func testArbitraryStaleTerminalCaptureIsRejected() {
        let h = makeM3Model()
        h.model.send(.start)
        h.effects.removeAll()
        h.model.send(.pause)
        guard case .stopScrollSession(let old, let new, let reason, _, _)? = h.effects.first else {
            return XCTFail("Expected retirement pair")
        }
        h.model.send(.start)
        h.model.send(.scrollTerminalCapture(.init(
            retiringGeneration: old,
            replacementGeneration: new,
            reason: reason,
            anchor: ReadingAnchor(utf16Offset: 9),
            pixelOffset: 900
        )))
        XCTAssertNotEqual(h.model.overlaySession.pixelOffset, 900)
    }

    func testSemanticCheckpointsAreAtMostOncePerSecond() {
        let h = makeM3Session(maximumOffset: 10_000)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        [0.2, 0.5, 1.0, 1.5, 2.0].forEach { h.factory.latest?.fire(at: $0) }
        let values = h.events.compactMap { event -> ScrollCheckpoint? in
            guard case .checkpoint(let value) = event else { return nil }
            return value
        }
        XCTAssertEqual(values.map(\.uptime), [1, 2])
    }

    func testBackForwardBindPausedSessionBeforeFirstStart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-paused-manual-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let overlay = OverlayPanelController()
        let factory = M3FakeFrameClockFactory()
        let adapter = AppEffectAdapter(
            snapshotStore: SnapshotStore(rootURL: root),
            overlayController: overlay,
            frameClockFactory: factory.make
        )
        let model = AppModel(
            overlayController: overlay,
            document: ScriptDocument(
                text: (1...100).map { "Line \($0) private rehearsal" }.joined(separator: "\n")
            ),
            effectHandler: { adapter.handle($0) }
        )
        let controller = ControllerWindowController(model: model)
        adapter.connect(model: model, controller: controller)
        let viewport = try XCTUnwrap(overlay.readerTextSystem.viewportAdapter)

        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(viewport.clipOriginY, 0, accuracy: 1e-9)
        model.send(.moveForward)
        let forwardOffset = viewport.clipOriginY
        model.send(.moveBackward)
        let pausedOffsetBeforeStart = viewport.clipOriginY

        XCTAssertGreaterThan(forwardOffset, 0)
        XCTAssertLessThan(pausedOffsetBeforeStart, forwardOffset)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertTrue(factory.clocks.isEmpty)

        model.send(.start)

        XCTAssertEqual(viewport.clipOriginY, pausedOffsetBeforeStart, accuracy: 1e-9)
        XCTAssertEqual(factory.clocks.count, 1)
    }

    func testViewportReplacementDropsOldSessionAndRestoresAuthorizedCapture() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-viewport-replacement-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let overlay = OverlayPanelController()
        let factory = M3FakeFrameClockFactory()
        var firstViewport: M3FakeReaderViewport? = M3FakeReaderViewport()
        var currentViewport = firstViewport
        let adapter = AppEffectAdapter(
            snapshotStore: SnapshotStore(rootURL: root),
            overlayController: overlay,
            readerViewportProvider: { currentViewport },
            frameClockFactory: factory.make
        )
        let model = AppModel(
            overlayController: overlay,
            document: ScriptDocument(text: "Private rehearsal attachment replacement"),
            effectHandler: { adapter.handle($0) }
        )
        let controller = ControllerWindowController(model: model)
        adapter.connect(model: model, controller: controller)

        model.send(.readerAttachmentChanged(isAttached: true))
        model.send(.start)
        let oldClock = try XCTUnwrap(factory.latest)
        firstViewport?.setClipOriginY(37)
        let expectedAnchor = firstViewport?.captureAnchor(viewportFraction: 0.5)
        weak var oldSession: ScrollSessionController? = adapter.scrollSessionForTesting
        weak var oldViewport: M3FakeReaderViewport? = firstViewport

        let replacementViewport = M3FakeReaderViewport()
        replacementViewport.semanticRestoreOffset = 180
        currentViewport = replacementViewport
        firstViewport = nil
        XCTAssertNotNil(oldSession)
        XCTAssertNotNil(oldViewport)

        model.send(.readerAttachmentChanged(isAttached: true))

        XCTAssertEqual(oldClock.invalidationCount, 1)
        XCTAssertNil(oldSession)
        XCTAssertNil(oldViewport)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(replacementViewport.restoredAnchors.last, expectedAnchor)
        XCTAssertEqual(replacementViewport.clipOriginY, 180, accuracy: 1e-9)
        XCTAssertEqual(adapter.scrollSessionConstructionCount, 2)
        XCTAssertEqual(adapter.activeScrollSessionCount, 1)
        XCTAssertEqual(factory.clocks.count, 1)

        model.send(.moveForward)
        XCTAssertEqual(replacementViewport.clipOriginY, 270, accuracy: 1e-9)
        model.send(.start)
        let replacementClock = try XCTUnwrap(factory.latest)
        replacementClock.fire(at: ProcessInfo.processInfo.systemUptime + 0.5)

        XCTAssertEqual(factory.clocks.count, 2)
        XCTAssertTrue(replacementClock !== oldClock)
        XCTAssertGreaterThan(replacementViewport.clipOriginY, 180)
        XCTAssertEqual(adapter.activeScrollSessionCount, 1)
    }

    func testTwoPhaseAttachmentReusesOneRetirementAndRetainsCapture() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-two-phase-attachment-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let overlay = OverlayPanelController()
        let factory = M3FakeFrameClockFactory()
        var firstViewport: M3FakeReaderViewport? = M3FakeReaderViewport()
        var currentViewport = firstViewport
        let adapter = AppEffectAdapter(
            snapshotStore: SnapshotStore(rootURL: root),
            overlayController: overlay,
            readerViewportProvider: { currentViewport },
            frameClockFactory: factory.make
        )
        let model = AppModel(
            overlayController: overlay,
            document: ScriptDocument(text: "Synthetic two phase attachment rehearsal"),
            effectHandler: { adapter.handle($0) }
        )
        let controller = ControllerWindowController(model: model)
        adapter.connect(model: model, controller: controller)

        let initialGeneration = model.currentScrollGeneration
        model.send(.readerAttachmentChanged(isAttached: true))
        XCTAssertEqual(model.currentScrollGeneration, initialGeneration)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(adapter.activeScrollSessionCount, 1)
        XCTAssertTrue(factory.clocks.isEmpty)

        model.send(.start)
        let playingGeneration = model.currentScrollGeneration
        let oldClock = try XCTUnwrap(factory.latest)
        firstViewport?.setClipOriginY(43)
        let capturedAnchor = firstViewport?.captureAnchor(viewportFraction: 0.5)
        weak var oldSession: ScrollSessionController? = adapter.scrollSessionForTesting
        weak var oldViewport: M3FakeReaderViewport? = firstViewport

        model.send(.readerAttachmentChanged(isAttached: false))
        let detachedGeneration = model.currentScrollGeneration

        XCTAssertNotEqual(detachedGeneration, playingGeneration)
        XCTAssertEqual(oldClock.invalidationCount, 1)
        XCTAssertNil(oldSession)
        XCTAssertEqual(adapter.activeScrollSessionCount, 0)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)

        currentViewport = nil
        firstViewport = nil
        XCTAssertNil(oldViewport)
        model.send(.readerAttachmentChanged(isAttached: false))
        XCTAssertEqual(model.currentScrollGeneration, detachedGeneration)
        XCTAssertEqual(adapter.activeScrollSessionCount, 0)

        let replacementViewport = M3FakeReaderViewport()
        replacementViewport.semanticRestoreOffset = 170
        currentViewport = replacementViewport
        model.send(.readerAttachmentChanged(isAttached: true))

        XCTAssertEqual(model.currentScrollGeneration, detachedGeneration)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(replacementViewport.restoredAnchors.last, capturedAnchor)
        XCTAssertEqual(replacementViewport.clipOriginY, 170, accuracy: 1e-9)
        XCTAssertEqual(adapter.scrollSessionConstructionCount, 2)
        XCTAssertEqual(adapter.activeScrollSessionCount, 1)
        XCTAssertEqual(factory.clocks.count, 1)

        model.send(.moveForward)
        XCTAssertEqual(replacementViewport.clipOriginY, 260, accuracy: 1e-9)
        XCTAssertEqual(model.currentScrollGeneration, detachedGeneration)
        XCTAssertEqual(model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(adapter.activeScrollSessionCount, 1)
    }

    func testPausedReconcileRestoresSemanticAnchorBeforeFirstStartWithoutJump() {
        let h = makeM3Session(maximumOffset: 1_000)
        let anchor = ReadingAnchor(utf16Offset: 25, viewportFraction: 0.4)
        let pausedGeneration = issuedM3Generation()
        h.viewport.attachmentView = nil
        h.viewport.semanticRestoreOffset = 180

        let paused = h.session.reconcilePaused(
            generation: pausedGeneration,
            anchor: anchor,
            offset: 900,
            speed: 60
        )

        XCTAssertEqual(paused.offset, 180, accuracy: 1e-9)
        XCTAssertEqual(h.viewport.clipOriginY, 180, accuracy: 1e-9)
        XCTAssertEqual(h.viewport.restoredAnchors, [anchor])
        XCTAssertFalse(h.session.isPlaying)
        XCTAssertTrue(h.factory.clocks.isEmpty)

        h.viewport.semanticRestoreOffset = 240
        let bounds = h.session.reconcilePaused(
            generation: pausedGeneration,
            anchor: anchor,
            offset: paused.offset,
            speed: 60
        )
        XCTAssertEqual(bounds.offset, 240, accuracy: 1e-9)
        XCTAssertEqual(h.viewport.clipOriginY, 240, accuracy: 1e-9)

        h.viewport.attachmentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 480, height: 300)
        )
        let playingGeneration = replacementM3Generation(after: pausedGeneration)
        h.session.start(
            generation: playingGeneration,
            offset: bounds.offset,
            speed: 60,
            uptime: 10,
            anchor: anchor
        )
        XCTAssertEqual(h.viewport.clipOriginY, 240, accuracy: 1e-9)
        h.factory.latest?.fire(at: 10.5)
        XCTAssertEqual(h.viewport.clipOriginY, 270, accuracy: 1e-9)
    }

    func testPausedManualMovesPublishAtMostOncePerSecond() {
        let h = makeM3Session(maximumOffset: 1_000)
        let generation = issuedM3Generation()
        _ = h.session.reconcilePaused(
            generation: generation,
            anchor: ReadingAnchor(),
            offset: 0,
            speed: 60
        )

        h.session.move(generation: generation, direction: .forward, uptime: 10)
        h.session.move(generation: generation, direction: .forward, uptime: 10.2)
        h.session.move(generation: generation, direction: .forward, uptime: 10.9)
        h.session.move(generation: generation, direction: .forward, uptime: 11)

        let checkpoints = h.events.compactMap { event -> ScrollCheckpoint? in
            guard case .checkpoint(let checkpoint) = event else { return nil }
            return checkpoint
        }
        XCTAssertEqual(checkpoints.map(\.uptime), [10, 11])
        XCTAssertEqual(h.viewport.clipOriginY, 360, accuracy: 1e-9)
        XCTAssertFalse(h.session.isPlaying)
    }

    func testReaderResyncHasNoTaskYieldOrRecursiveEffectHandling() throws {
        let adapter = try String(contentsOfFile: m3AppSource("DependencyContainer.swift"))
        let reader = try String(contentsOfFile: m3OverlaySource("ReaderTextSystem.swift"))
        let model = try String(contentsOfFile: m3AppSource("AppModel.swift"))
        XCTAssertFalse(reader.contains("Task"))
        XCTAssertFalse(reader.contains("DispatchQueue"))
        XCTAssertTrue(model.contains("pendingCommands"))
        XCTAssertTrue(model.contains("isDrainingCommands"))
        let resync = try XCTUnwrap(adapter.range(of: "readerResyncRequested"))
        let tail = adapter[resync.lowerBound...]
        XCTAssertFalse(tail.prefix(300).contains("Task.yield"))
    }

    func testEndInvalidatesClockBeforeOnePausedTransition() {
        let log = M3OperationLog()
        let h = makeM3Session(maximumOffset: 1, log: log)
        let generation = issuedM3Generation()
        h.session.start(generation: generation, offset: 0, speed: 60, uptime: 0)
        log.values.removeAll()
        h.factory.latest?.fire(at: 0.5)
        XCTAssertEqual(Array(log.values.prefix(2)), ["origin", "invalidate"])
        XCTAssertEqual(h.terminals.count, 1)
        XCTAssertFalse(h.session.isPlaying)
    }

    func testControllerExposesBackAndForwardWithoutM4GlobalInput() throws {
        let presentation = ControllerPresentation(
            scriptText: "Private rehearsal",
            isPanelVisible: true,
            isClearConfirmationRequired: false
        )
        let controller = try String(contentsOfFile: m3ControllerSource("ControllerView.swift"))
        let sources = try m3ProductSources()
        XCTAssertTrue(presentation.isEnabled(.back))
        XCTAssertTrue(presentation.isEnabled(.forward))
        if case .moveBackward? = presentation.productCommand(for: .back) {} else {
            XCTFail("Back must dispatch through AppModel")
        }
        if case .moveForward? = presentation.productCommand(for: .forward) {} else {
            XCTFail("Forward must dispatch through AppModel")
        }
        XCTAssertTrue(controller.contains("Button(\"Back\")"))
        XCTAssertTrue(controller.contains("Button(\"Forward\")"))
        XCTAssertFalse(presentation.isEnabled(.focusMode))
        for prohibited in ["NSEvent.addGlobalMonitor", "CGEventTapCreate", "AXUIElement"] {
            XCTAssertFalse(sources.contains(prohibited))
        }
    }

    func testDisconnectDuringTickPersistsAnchorThenHides() throws {
        let observation = try m5DisconnectObservation()

        XCTAssertEqual(Array(observation.events.prefix(3)), ["stop", "enqueue", "orderOut"])
        XCTAssertEqual(observation.snapshot.readingAnchor.utf16Offset, 7)
        XCTAssertEqual(observation.snapshot.revision, observation.revisionAfterDisconnect)
        XCTAssertEqual(observation.model.overlaySession.playbackPhase, .paused)
        XCTAssertEqual(observation.model.overlaySession.visibility, .hidden)
        XCTAssertTrue(observation.model.isShielded)
    }

    func testDisconnectEnqueuesCapturedAnchorBeforeOrderOutWithoutAwaitingDisk() throws {
        let observation = try m5DisconnectObservation()
        let enqueue = try XCTUnwrap(observation.events.firstIndex(of: "enqueue"))
        let orderOut = try XCTUnwrap(observation.events.firstIndex(of: "orderOut"))

        XCTAssertLessThan(enqueue, orderOut)
        XCTAssertTrue(observation.persistenceWriteIsStillPending)
        XCTAssertTrue(observation.didOrderOutWhilePersistenceWasPending)
        XCTAssertEqual(observation.snapshot.readingAnchor.utf16Offset, 7)
        XCTAssertGreaterThan(
            observation.revisionAfterDisconnect,
            observation.revisionBeforeDisconnect
        )
    }

    private func issuedM3Generation() -> ScrollSessionGeneration {
        AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "Generation seed")
        ).currentScrollGeneration
    }

    private func replacementM3Generation(
        after generation: ScrollSessionGeneration
    ) -> ScrollSessionGeneration {
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "Generation seed")
        )
        model.send(.start)
        if model.currentScrollGeneration == generation { model.send(.pause) }
        return model.currentScrollGeneration
    }

    private func makeM3Session(
        maximumOffset: Double = 1_000,
        log: M3OperationLog = M3OperationLog()
    ) -> M3SessionHarness {
        let viewport = M3FakeReaderViewport(maximumOffset: maximumOffset, log: log)
        let factory = M3FakeFrameClockFactory(log: log)
        let h = M3SessionHarness(viewport: viewport, factory: factory)
        h.session = ScrollSessionController(
            viewport: viewport,
            clockFactory: factory.make,
            onEvent: { [weak h] event in h?.events.append(event) }
        )
        return h
    }

    private func makeM3Model() -> M3ModelHarness {
        let h = M3ModelHarness()
        h.model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "Private rehearsal"),
            effectHandler: { [weak h] effect in h?.effects.append(effect) }
        )
        return h
    }

    private func m5DisconnectObservation() throws -> M5DisconnectObservation {
        let reference = M5ScrollModelReference()
        var shouldCaptureDisconnect = false
        var events: [String] = []
        var enqueuedSnapshot: PersistedSnapshot?
        var persistenceWriteIsStillPending = false
        var didOrderOutWhilePersistenceWasPending = false
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(text: "synthetic disconnect fixture"),
            effectHandler: { effect in
                switch effect {
                case .stopScrollSession(
                    let retiring,
                    let replacement,
                    let reason,
                    _,
                    _
                ):
                    guard shouldCaptureDisconnect else { return }
                    events.append("stop")
                    shouldCaptureDisconnect = false
                    reference.value?.send(
                        .scrollTerminalCapture(
                            ScrollTerminalCapture(
                                retiringGeneration: retiring,
                                replacementGeneration: replacement,
                                reason: reason,
                                anchor: ReadingAnchor(
                                    utf16Offset: 7,
                                    viewportFraction: 0.4,
                                    document: "synthetic disconnect fixture"
                                ),
                                pixelOffset: 91
                            )
                        )
                    )
                case .scheduleSnapshot(let snapshot):
                    guard events.contains("stop") else { return }
                    events.append("enqueue")
                    enqueuedSnapshot = snapshot
                    persistenceWriteIsStillPending = true
                case .hidePanel:
                    guard events.contains("stop") else { return }
                    events.append("orderOut")
                    didOrderOutWhilePersistenceWasPending = persistenceWriteIsStillPending
                default:
                    break
                }
            }
        )
        reference.value = model
        let privateDisplay = m5Display(id: 1, builtIn: true, x: 0)
        let audience = m5Display(id: 2, builtIn: false, x: 1_440)
        model.refreshDisplays(.success([privateDisplay, audience]))
        model.selectDisplay(privateDisplay.id)
        model.confirmSelectedDisplay()
        model.send(.completeShieldedMove(screenID: privateDisplay.id))
        model.showOverlay()
        model.send(.start)
        model.send(
            .scrollCheckpoint(
                ScrollCheckpoint(
                    generation: model.currentScrollGeneration,
                    anchor: ReadingAnchor(
                        utf16Offset: 5,
                        viewportFraction: 0.4,
                        document: model.document.text
                    ),
                    pixelOffset: 75,
                    uptime: 1
                )
            )
        )
        events.removeAll()
        enqueuedSnapshot = nil
        persistenceWriteIsStillPending = false
        let revisionBeforeDisconnect = model.snapshotRevision
        shouldCaptureDisconnect = true

        model.topologyWillChange()

        return M5DisconnectObservation(
            model: model,
            events: events,
            snapshot: try XCTUnwrap(enqueuedSnapshot),
            revisionBeforeDisconnect: revisionBeforeDisconnect,
            revisionAfterDisconnect: model.snapshotRevision,
            persistenceWriteIsStillPending: persistenceWriteIsStillPending,
            didOrderOutWhilePersistenceWasPending: didOrderOutWhilePersistenceWasPending
        )
    }

    private func m5Display(id: UInt32, builtIn: Bool, x: CGFloat) -> RuntimeDisplay {
        RuntimeDisplay(
            id: id,
            localizedName: builtIn ? "Built-in Display" : "Audience Display",
            isBuiltIn: builtIn,
            isMain: builtIn,
            isOnline: true,
            frame: NSRect(x: x, y: 0, width: 1_440, height: 900),
            visibleFrame: NSRect(x: x, y: 0, width: 1_440, height: 860),
            scale: 2,
            persistentUUID: "m5-display-\(id)",
            mirrorSourceID: nil,
            isInMirrorSet: false,
            vendorID: 1,
            modelID: id,
            serialNumber: id
        )
    }

    private func m3OverlaySource(_ name: String) -> String { m3Source("Overlay/\(name)") }
    private func m3AppSource(_ name: String) -> String { m3Source("App/\(name)") }
    private func m3ControllerSource(_ name: String) -> String { m3Source("Controller/\(name)") }
    private func m3Source(_ suffix: String) -> String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/\(suffix)").path
    }

    private func m3ProductSources() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("PrivatePresenterApp")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var result = ""
        while let url = files?.nextObject() as? URL {
            if url.pathExtension == "swift" { result += try String(contentsOf: url) }
        }
        return result
    }
}

@MainActor
private struct M5DisconnectObservation {
    let model: AppModel
    let events: [String]
    let snapshot: PersistedSnapshot
    let revisionBeforeDisconnect: UInt64
    let revisionAfterDisconnect: UInt64
    let persistenceWriteIsStillPending: Bool
    let didOrderOutWhilePersistenceWasPending: Bool
}

@MainActor
private final class M5ScrollModelReference {
    weak var value: AppModel?
}

@MainActor
private final class M3SessionHarness {
    let viewport: M3FakeReaderViewport
    let factory: M3FakeFrameClockFactory
    var session: ScrollSessionController!
    var events: [ScrollSessionEvent] = []
    init(viewport: M3FakeReaderViewport, factory: M3FakeFrameClockFactory) {
        self.viewport = viewport
        self.factory = factory
    }
    var terminals: [ScrollTerminalResult] {
        events.compactMap { if case .terminal(let value) = $0 { value } else { nil } }
    }
}

@MainActor
private final class M3FakeReaderViewport: ReaderViewport {
    var attachmentView: NSView? = NSView(
        frame: NSRect(x: 0, y: 0, width: 480, height: 300)
    )
    var clipSize = NSSize(width: 480, height: 300)
    var clipOriginY = 0.0
    var maximumOffset: Double
    var textMutationCount = 0
    var semanticRestoreOffset: Double?
    private(set) var restoredAnchors: [ReadingAnchor] = []
    private(set) var setOriginCount = 0
    private let log: M3OperationLog
    init(maximumOffset: Double = 1_000, log: M3OperationLog = M3OperationLog()) {
        self.maximumOffset = maximumOffset
        self.log = log
    }
    func ensureLayout() {}
    func captureAnchor(viewportFraction: Double) -> ReadingAnchor {
        ReadingAnchor(utf16Offset: Int(clipOriginY), viewportFraction: viewportFraction)
    }
    @discardableResult func restore(anchor: ReadingAnchor) -> Double {
        restoredAnchors.append(anchor)
        if let semanticRestoreOffset {
            clipOriginY = min(max(semanticRestoreOffset, 0), maximumOffset)
        }
        return clipOriginY
    }
    func setClipOriginY(_ offset: Double) {
        clipOriginY = min(max(offset, 0), maximumOffset)
        setOriginCount += 1
        log.values.append("origin")
    }
    func threeCompleteLineStep() -> Double { 90 }
}

@MainActor
private final class M3FakeFrameClockFactory {
    private let log: M3OperationLog
    private(set) var clocks: [M3FakeFrameClock] = []
    init(log: M3OperationLog = M3OperationLog()) { self.log = log }
    var latest: M3FakeFrameClock? { clocks.last }
    func make(
        attachedView: NSView,
        onTick: @escaping @MainActor (TimeInterval) -> Void
    ) -> FrameClock? {
        let clock = M3FakeFrameClock(onTick: onTick, log: log)
        clocks.append(clock)
        log.values.append("clock")
        return clock
    }
}

@MainActor
private final class M3FakeFrameClock: FrameClock {
    private let onTick: @MainActor (TimeInterval) -> Void
    private let log: M3OperationLog
    private(set) var invalidationCount = 0
    init(onTick: @escaping @MainActor (TimeInterval) -> Void, log: M3OperationLog) {
        self.onTick = onTick
        self.log = log
    }
    func fire(at uptime: TimeInterval) {
        guard invalidationCount == 0 else { return }
        onTick(uptime)
    }
    func invalidate() {
        guard invalidationCount == 0 else { return }
        invalidationCount = 1
        log.values.append("invalidate")
    }
}

@MainActor private final class M3ModelHarness {
    var model: AppModel!
    var effects: [AppEffect] = []
    var effectNames: [String] {
        effects.map {
            switch $0 {
            case .stopScrollSession: "stop"
            case .hidePanel: "hide"
            case .queryTopology: "query"
            case .moveControllerWhileShielded: "move"
            default: "other"
            }
        }
    }
}
@MainActor private final class M3ModelReference { weak var value: AppModel? }
@MainActor private final class M3OperationLog { var values: [String] = [] }
