import AppKit
import TeleprompterCore
import XCTest

@testable import PrivatePresenter

@MainActor
final class ReaderTextSystemTests: XCTestCase {
    func testIncrementalEditDoesNotReplaceReaderStorage() throws {
        let reader = ReaderTextSystem(text: "abc", revision: 0)
        let storage = reader.textStorage

        reader.apply(try edit(in: "abc", range: .init(location: 1, length: 1), with: "X"))

        XCTAssertTrue(reader.textStorage === storage)
        XCTAssertEqual(reader.textStorage.string, "aXc")
        XCTAssertEqual(reader.incrementalMutationCount, 1)
        XCTAssertEqual(reader.fullReplacementCount, 0)
    }

    func testRevisionGapPerformsOneResync() throws {
        var requests: [UInt64] = []
        let reader = ReaderTextSystem(text: "a", revision: 0) { requests.append($0) }
        let gap = try ScriptTextEdit.replacing(
            in: "ab",
            range: .init(location: 2, length: 0),
            with: "c",
            baseRevision: 1
        )

        reader.apply(gap)

        XCTAssertEqual(requests, [0])
        XCTAssertTrue(reader.isAwaitingResync)
    }

    func testMultipleUpdatesDuringGapRequestOnlyOneResync() throws {
        var requests: [UInt64] = []
        let reader = ReaderTextSystem(text: "a", revision: 0) { requests.append($0) }
        let gap = try ScriptTextEdit.replacing(
            in: "ab",
            range: .init(location: 2, length: 0),
            with: "c",
            baseRevision: 1
        )

        reader.apply(gap)
        reader.apply(gap)

        XCTAssertEqual(requests, [0])
    }

    func testDuplicateAndStaleReaderUpdatesAreIgnored() throws {
        let reader = ReaderTextSystem(text: "a", revision: 1)
        let stale = try ScriptTextEdit.replacing(
            in: "",
            range: .init(location: 0, length: 0),
            with: "a",
            baseRevision: 0
        )

        reader.apply(stale)
        reader.apply(stale)

        XCTAssertEqual(reader.textStorage.string, "a")
        XCTAssertEqual(reader.incrementalMutationCount, 0)
        XCTAssertFalse(reader.isAwaitingResync)
    }

    func testContiguousInvalidRangePerformsOneAuthoritativeResync() throws {
        var requests = 0
        let reader = ReaderTextSystem(text: "A👍B", revision: 0) { _ in requests += 1 }
        let invalid = ScriptTextEdit(
            range: .init(location: 2, length: 1),
            replacement: "x",
            changeInLength: 0,
            baseUTF16Length: 4,
            resultUTF16Length: 4,
            baseRevision: 0,
            revision: 1
        )

        reader.apply(invalid)
        reader.apply(invalid)
        reader.replaceAuthoritatively(text: "fixed", revision: 1, reason: .resync)

        XCTAssertEqual(requests, 1)
        XCTAssertEqual(reader.fullReplacementCount, 1)
        XCTAssertEqual(reader.textStorage.string, "fixed")
        XCTAssertEqual(reader.appliedRevision, 1)
    }

    func testStorageLengthDivergencePerformsOneAuthoritativeResync() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "private-presenter-reader-resync-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let overlay = OverlayPanelController()
        let adapter = AppEffectAdapter(
            snapshotStore: SnapshotStore(rootURL: root),
            overlayController: overlay
        )
        let model = AppModel(
            overlayController: overlay,
            effectHandler: { adapter.handle($0) }
        )
        let controller = ControllerWindowController(model: model)
        adapter.connect(model: model, controller: controller)
        let initialFullReplacements = overlay.readerTextSystem.fullReplacementCount
        model.send(.applyScriptEdit(try edit(in: "", range: .init(location: 0, length: 0), with: "a")))
        overlay.readerTextSystem.replaceStorageForTesting("diverged")

        model.send(
            .applyScriptEdit(
                try ScriptTextEdit.replacing(
                    in: "a",
                    range: .init(location: 1, length: 0),
                    with: "b",
                    baseRevision: 1
                )))

        XCTAssertEqual(overlay.readerTextSystem.resyncRequestCount, 1)
        XCTAssertEqual(
            overlay.readerTextSystem.fullReplacementCount,
            initialFullReplacements + 1
        )
        XCTAssertEqual(overlay.readerTextSystem.textStorage.string, model.document.text)
        XCTAssertEqual(overlay.readerTextSystem.appliedRevision, model.document.revision)
        XCTAssertFalse(overlay.readerTextSystem.isAwaitingResync)
        XCTAssertEqual(adapter.maximumHandleDepth, 1)
    }

    func testResyncToLatestRevisionRestoresIncrementalDelivery() throws {
        let reader = ReaderTextSystem(text: "a", revision: 0)
        let gap = try ScriptTextEdit.replacing(
            in: "ab",
            range: .init(location: 2, length: 0),
            with: "c",
            baseRevision: 1
        )
        reader.apply(gap)
        reader.replaceAuthoritatively(text: "abc", revision: 2, reason: .resync)

        let next = try ScriptTextEdit.replacing(
            in: "abc",
            range: .init(location: 3, length: 0),
            with: "d",
            baseRevision: 2
        )
        reader.apply(next)

        XCTAssertEqual(reader.textStorage.string, "abcd")
        XCTAssertEqual(reader.incrementalMutationCount, 1)
        XCTAssertFalse(reader.isAwaitingResync)
    }

    func testInitialRestoreClearAndLatchedGapOrApplicationFailureAreOnlyFullReplacementReasons() {
        XCTAssertEqual(Set(ReaderFullReplacementReason.allCases), [.initial, .restore, .clear, .resync])
    }

    func testReaderResyncCallbackIsMainActorIsolated() throws {
        var callbackWasOnMainThread = false
        let reader = ReaderTextSystem(text: "a", revision: 0) { _ in
            callbackWasOnMainThread = Thread.isMainThread
        }
        let gap = try ScriptTextEdit.replacing(
            in: "ab",
            range: .init(location: 2, length: 0),
            with: "c",
            baseRevision: 1
        )

        reader.apply(gap)

        XCTAssertTrue(callbackWasOnMainThread)
    }

    func testReaderUsesTextKit2WithoutLegacyLayoutManager() throws {
        let reader = ReaderTextSystem(text: "", revision: 0)
        let source = try String(contentsOfFile: sourcePath("ReaderTextSystem.swift"))

        XCTAssertNotNil(reader.textView.textLayoutManager)
        XCTAssertFalse(source.contains(".layoutManager"))
    }

    func testFontAndAlignmentUpdatesDoNotMutateReaderText() {
        let reader = ReaderTextSystem(text: "immutable", revision: 0)
        reader.updateAttributes(fontSize: 72, alignment: .center)

        XCTAssertEqual(reader.textStorage.string, "immutable")
        XCTAssertEqual(reader.fullReplacementCount, 0)
    }

    func testFirstIncrementalInsertionReceivesConfiguredAppearance() throws {
        let reader = ReaderTextSystem(text: "", revision: 0)
        reader.updateAttributes(fontSize: 72, alignment: .center)

        reader.apply(try edit(in: "", range: .init(location: 0, length: 0), with: "First"))

        let attributes = reader.textStorage.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual((attributes[.font] as? NSFont)?.pointSize, 72)
        XCTAssertEqual(attributes[.foregroundColor] as? NSColor, NSColor.white)
        XCTAssertEqual(
            (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment,
            .center
        )
    }

    func testReaderDocumentViewStartsUsableAndTracksClipWidth() {
        let reader = ReaderTextSystem(text: "Generated text", revision: 0)

        XCTAssertGreaterThan(reader.textView.frame.width, 0)
        XCTAssertGreaterThan(reader.textView.frame.height, 0)
        XCTAssertTrue(reader.textView.isVerticallyResizable)
        XCTAssertFalse(reader.textView.isHorizontallyResizable)
        XCTAssertTrue(reader.textView.textContainer?.widthTracksTextView == true)
        XCTAssertGreaterThan(reader.textView.textContainer?.containerSize.height ?? 0, 10_000)
    }

    func testStaticReaderClipRejectsViewportMovement() {
        let clipView = ReaderClipView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 360)
        )
        clipView.documentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 2_000)
        )
        clipView.scroll(to: NSPoint(x: 0, y: 200))

        // Preserve the M2 lockout: arbitrary callers cannot move the clip.
        XCTAssertTrue(ReaderScrollView.userScrollingIsDisabled)
        XCTAssertEqual(clipView.bounds.origin, .zero)
    }

    func testReaderAdapterProgrammaticMotionIsTheOnlyAcceptedPath() {
        let clipView = ReaderClipView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 360)
        )
        clipView.documentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 2_000)
        )

        clipView.setProgrammaticOriginY(200, maximumOffset: 1_640)

        XCTAssertEqual(clipView.bounds.origin, NSPoint(x: 0, y: 200))
    }

    func testActiveBandToggleDoesNotMutateReaderText() {
        let reader = ReaderTextSystem(text: "immutable", revision: 0)
        reader.setActiveBandEnabled(false)

        XCTAssertEqual(reader.textStorage.string, "immutable")
        XCTAssertFalse(reader.isActiveBandEnabled)
        XCTAssertEqual(reader.fullReplacementCount, 0)
    }

    private func edit(
        in text: String,
        range: UTF16TextRange,
        with replacement: String
    ) throws -> ScriptTextEdit {
        try ScriptTextEdit.replacing(
            in: text,
            range: range,
            with: replacement,
            baseRevision: 0
        )
    }

    private func sourcePath(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Overlay/\(name)")
            .path
    }
}
