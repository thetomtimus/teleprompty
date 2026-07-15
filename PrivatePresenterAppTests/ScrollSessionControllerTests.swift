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
