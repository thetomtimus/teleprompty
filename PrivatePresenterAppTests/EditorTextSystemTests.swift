import AppKit
import XCTest

@testable import PrivatePresenter

@MainActor
final class EditorTextSystemTests: XCTestCase {
    func testEditorReportsEditedRangeAndDelta() throws {
        let edit = try EditorTextSystem.deriveEdit(
            postEditText: "A👍B",
            processedRange: NSRange(location: 1, length: 2),
            changeInLength: 2,
            baseText: "AB",
            baseRevision: 4
        )

        XCTAssertEqual(edit.range, UTF16TextRange(location: 1, length: 0))
        XCTAssertEqual(edit.replacement, "👍")
        XCTAssertEqual(edit.changeInLength, 2)
        XCTAssertEqual(edit.baseUTF16Length, 2)
        XCTAssertEqual(edit.resultUTF16Length, 4)
        XCTAssertEqual(edit.baseRevision, 4)
        XCTAssertEqual(edit.revision, 5)
    }

    func testEditorRejectsProcessedRangeEndOverflow() {
        XCTAssertThrowsError(
            try EditorTextSystem.deriveEdit(
                postEditText: "",
                processedRange: NSRange(location: Int.max, length: 1),
                changeInLength: 0,
                baseText: "",
                baseRevision: 0
            )
        ) { error in
            XCTAssertEqual(error as? ScriptTextEditError, .arithmeticOverflow)
        }
    }

    func testScriptTextEditValidatesBaseAndResultRevision() throws {
        let edit = try ScriptTextEdit.replacing(
            in: "abc",
            range: UTF16TextRange(location: 1, length: 1),
            with: "XYZ",
            baseRevision: 9
        )

        XCTAssertEqual(try edit.applying(to: "abc", revision: 9), "aXYZc")
        XCTAssertThrowsError(try edit.applying(to: "abc", revision: 8))
        XCTAssertEqual(edit.revision, 10)
    }

    func testScriptTextEditIsSendableAcrossActorBoundary() async throws {
        let edit = try ScriptTextEdit.replacing(
            in: "base",
            range: UTF16TextRange(location: 4, length: 0),
            with: " text",
            baseRevision: 0
        )
        let received = await Task.detached { edit }.value

        XCTAssertEqual(received, edit)
    }

    func testUTF16EmojiEditBoundaries() throws {
        XCTAssertThrowsError(
            try ScriptTextEdit.replacing(
                in: "A👍B",
                range: UTF16TextRange(location: 2, length: 1),
                with: "x",
                baseRevision: 0
            )
        )
        let valid = try ScriptTextEdit.replacing(
            in: "A👍B",
            range: UTF16TextRange(location: 1, length: 2),
            with: "🙂",
            baseRevision: 0
        )
        XCTAssertEqual(try valid.applying(to: "A👍B", revision: 0), "A🙂B")
    }

    func testCombiningCharacterEditUsesUTF16DeltaWithoutCorruption() throws {
        let base = "Cafe\u{301}"
        let edit = try ScriptTextEdit.replacing(
            in: base,
            range: UTF16TextRange(location: 4, length: 1),
            with: "",
            baseRevision: 2
        )

        XCTAssertEqual(try edit.applying(to: base, revision: 2), "Cafe")
        XCTAssertEqual(edit.changeInLength, -1)
    }

    func testProgrammaticEditorSyncDoesNotEmitUserEdit() {
        var edits: [ScriptTextEdit] = []
        let system = EditorTextSystem(text: "one", revision: 1) { edits.append($0) }

        system.synchronize(text: "two", revision: 2)

        XCTAssertEqual(system.textStorage.string, "two")
        XCTAssertTrue(edits.isEmpty)
    }

    func testEditorCallbackIsMainActorIsolated() {
        var callbackWasOnMainThread = false
        let system = EditorTextSystem(text: "", revision: 0) { _ in
            callbackWasOnMainThread = Thread.isMainThread
        }

        system.replaceCharactersForTesting(
            in: NSRange(location: 0, length: 0),
            with: "a"
        )

        XCTAssertTrue(callbackWasOnMainThread)
    }

    func testEditorUsesTextKit2WithoutLegacyLayoutManager() throws {
        let system = EditorTextSystem(text: "", revision: 0) { _ in }
        let source = try String(contentsOfFile: sourcePath("EditorTextSystem.swift"))

        XCTAssertNotNil(system.textView.textLayoutManager)
        XCTAssertFalse(source.contains(".layoutManager"))
    }

    func testEditorDocumentViewStartsUsableAndTracksClipWidth() {
        let system = EditorTextSystem(text: "Generated text", revision: 0) { _ in }

        XCTAssertGreaterThan(system.textView.frame.width, 0)
        XCTAssertGreaterThan(system.textView.frame.height, 0)
        XCTAssertTrue(system.textView.isVerticallyResizable)
        XCTAssertFalse(system.textView.isHorizontallyResizable)
        XCTAssertTrue(system.textView.textContainer?.widthTracksTextView == true)
        XCTAssertGreaterThan(system.textView.textContainer?.containerSize.height ?? 0, 10_000)
    }

    private func sourcePath(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PrivatePresenterApp/Controller/\(name)")
            .path
    }
}
