import Foundation
import XCTest

@testable import TeleprompterCore

final class ReadingPositionMapperTests: XCTestCase {
    func testInsertionBeforeAnchorShiftsOffset() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 1, length: 0),
            replacement: "ZZ",
            preEditDocument: "abcDEF",
            postEditDocument: "aZZbcDEF"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 5)
        XCTAssertFalse(mapping.requiresPause)
        XCTAssertNil(mapping.reason)

        let positiveReplacementDelta = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 4),
            editedRangeUTF16: NSRange(location: 1, length: 1),
            replacement: "WXYZ",
            preEditDocument: "abcDEF",
            postEditDocument: "aWXYZcDEF"
        )

        XCTAssertEqual(positiveReplacementDelta.anchor.utf16Offset, 7)
        XCTAssertFalse(positiveReplacementDelta.requiresPause)
    }

    func testDeletionBeforeAnchorShiftsOffset() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 6),
            editedRangeUTF16: NSRange(location: 1, length: 2),
            replacement: "",
            preEditDocument: "abcDEF",
            postEditDocument: "aDEF"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 4)
        XCTAssertFalse(mapping.requiresPause)
        XCTAssertNil(mapping.reason)

        let endingExactlyAtAnchor = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 1, length: 2),
            replacement: "Z",
            preEditDocument: "abcDEF",
            postEditDocument: "aZDEF"
        )

        XCTAssertEqual(endingExactlyAtAnchor.anchor.utf16Offset, 2)
        XCTAssertFalse(endingExactlyAtAnchor.requiresPause)
    }

    func testEditAfterAnchorDoesNotMove() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 4, length: 2),
            replacement: "xy",
            preEditDocument: "abcDEF",
            postEditDocument: "abcDxy"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 2)
        XCTAssertFalse(mapping.requiresPause)

        let insertionAtDocumentEnd = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 6, length: 0),
            replacement: "👍",
            preEditDocument: "abcDEF",
            postEditDocument: "abcDEF👍"
        )
        let editEndingAtDocumentEnd = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 3, length: 3),
            replacement: "Z",
            preEditDocument: "abcDEF",
            postEditDocument: "abcZ"
        )

        XCTAssertEqual(insertionAtDocumentEnd.anchor.utf16Offset, 2)
        XCTAssertFalse(insertionAtDocumentEnd.requiresPause)
        XCTAssertEqual(editEndingAtDocumentEnd.anchor.utf16Offset, 2)
        XCTAssertFalse(editEndingAtDocumentEnd.requiresPause)
    }

    func testOverlapClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 2, length: 3),
            replacement: "X",
            preEditDocument: "abcDEF",
            postEditDocument: "abXF"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 2)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .editTouchesAnchor)

        let touchingStart = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 2, length: 1),
            replacement: "ZZ",
            preEditDocument: "abcDEF",
            postEditDocument: "abZZDEF"
        )

        XCTAssertEqual(touchingStart.anchor.utf16Offset, 2)
        XCTAssertTrue(touchingStart.requiresPause)
        XCTAssertEqual(touchingStart.reason, .editTouchesAnchor)
    }

    func testEmojiOffsetsAreUTF16Safe() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 1, length: 0),
            replacement: "Z",
            preEditDocument: "A👍B",
            postEditDocument: "AZ👍B"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 4)
        XCTAssertTrue(isScalarBoundary(mapping.anchor.utf16Offset, in: "AZ👍B"))
        XCTAssertLessThanOrEqual(
            mapping.anchor.contextBefore.utf16.count,
            ReadingAnchor.maximumContextUTF16Length
        )
        XCTAssertLessThanOrEqual(
            mapping.anchor.contextAfter.utf16.count,
            ReadingAnchor.maximumContextUTF16Length
        )
    }

    func testLayoutChangeRestoresViewportFraction() {
        XCTAssertEqual(
            ReadingPositionMapper.restoredOffset(
                anchorY: 400,
                clipHeight: 200,
                viewportFraction: 0.5,
                maximumOffset: 500
            ),
            300
        )
        XCTAssertEqual(
            ReadingPositionMapper.restoredOffset(
                anchorY: 20,
                clipHeight: 200,
                viewportFraction: 0.5,
                maximumOffset: 500
            ),
            0
        )
        XCTAssertEqual(
            ReadingPositionMapper.restoredOffset(
                anchorY: 900,
                clipHeight: 200,
                viewportFraction: 0.5,
                maximumOffset: 500
            ),
            500
        )
    }

    func testInsertionExactlyAtAnchorClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 3, length: 0),
            replacement: "ZZ",
            preEditDocument: "abcDEF",
            postEditDocument: "abcZZDEF"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 3)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .editTouchesAnchor)
    }

    func testInvalidRangeOverflowClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: Int.max, length: 1),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "abc"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 2)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .invalidEdit)

        let negativeLocation = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: -1, length: 1),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "abc"
        )
        let negativeLength = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 0, length: -1),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "abc"
        )
        let outsideDocument = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 2, length: 2),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "abc"
        )

        for invalid in [negativeLocation, negativeLength, outsideDocument] {
            XCTAssertEqual(invalid.anchor.utf16Offset, 2)
            XCTAssertTrue(invalid.requiresPause)
            XCTAssertEqual(invalid.reason, .invalidEdit)
        }
    }

    func testSplitSurrogateRangeClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 3),
            editedRangeUTF16: NSRange(location: 2, length: 0),
            replacement: "X",
            preEditDocument: "A👍B",
            postEditDocument: "A👍B"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 3)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .invalidEdit)
        XCTAssertTrue(isScalarBoundary(mapping.anchor.utf16Offset, in: "A👍B"))

        let crossDocumentFallback = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: Int.max, length: 1),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "A👍B"
        )

        XCTAssertEqual(crossDocumentFallback.anchor.utf16Offset, 1)
        XCTAssertTrue(crossDocumentFallback.requiresPause)
        XCTAssertEqual(crossDocumentFallback.reason, .invalidEdit)
        XCTAssertTrue(isScalarBoundary(crossDocumentFallback.anchor.utf16Offset, in: "A👍B"))
    }

    func testResultDocumentMismatchClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 1),
            editedRangeUTF16: NSRange(location: 0, length: 1),
            replacement: "X",
            preEditDocument: "abc",
            postEditDocument: "abc"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 1)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .invalidEdit)
    }

    func testAnchorNormalizesBackwardToScalarBoundary() {
        let mapping = ReadingPositionMapper.map(
            anchor: ReadingAnchor(utf16Offset: 2),
            editedRangeUTF16: NSRange(location: 4, length: 0),
            replacement: "Z",
            preEditDocument: "A👍B",
            postEditDocument: "A👍BZ"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 1)
        XCTAssertFalse(mapping.requiresPause)
        XCTAssertTrue(isScalarBoundary(mapping.anchor.utf16Offset, in: "A👍BZ"))
    }

    func testExactIndependentContextsSelectUniqueCandidate() {
        let document = "prefix LEFTRIGHT suffix LEFTNOPE"
        let mapping = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 0,
                contextBefore: "LEFT",
                contextAfter: "RIGHT"
            ),
            in: document
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, "prefix LEFT".utf16.count)
        XCTAssertFalse(mapping.requiresPause)
        XCTAssertNil(mapping.reason)

        let partialTwoSided = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 0,
                contextBefore: "ABCDEFGHIJ",
                contextAfter: "KLMNOPQRST"
            ),
            in: "JKX---ABCDEFGHIJX"
        )

        XCTAssertEqual(partialTwoSided.anchor.utf16Offset, 1)
        XCTAssertFalse(partialTwoSided.requiresPause)

        let greatestTotal = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 0,
                contextBefore: "ABCDE",
                contextAfter: "VWXYZ"
            ),
            in: "DEVQ--EVWXQ"
        )

        XCTAssertEqual(greatestTotal.anchor.utf16Offset, 7)
        XCTAssertFalse(greatestTotal.requiresPause)

        let sixtyFourBefore = String(repeating: "A", count: 64)
        let sixtyFourAfter = String(repeating: "B", count: 64)
        let exactSixtyFour = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 0,
                contextBefore: sixtyFourBefore,
                contextAfter: sixtyFourAfter
            ),
            in: "prefix" + sixtyFourBefore + sixtyFourAfter + "suffix"
        )

        XCTAssertEqual(exactSixtyFour.anchor.utf16Offset, "prefix".utf16.count + 64)
        XCTAssertEqual(exactSixtyFour.anchor.contextBefore, sixtyFourBefore)
        XCTAssertEqual(exactSixtyFour.anchor.contextAfter, sixtyFourAfter)
        XCTAssertFalse(exactSixtyFour.requiresPause)
    }

    func testAbsentContextClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 2,
                contextBefore: "ZZZ",
                contextAfter: "YYY"
            ),
            in: "abcdef"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 2)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .contextNotFound)
    }

    func testAmbiguousEqualContextTieClampsAndRequestsPause() {
        let mapping = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 3,
                contextBefore: "A",
                contextAfter: "B"
            ),
            in: "ABxxAB"
        )

        XCTAssertEqual(mapping.anchor.utf16Offset, 3)
        XCTAssertTrue(mapping.requiresPause)
        XCTAssertEqual(mapping.reason, .ambiguousContext)

        let uniqueNearest = ReadingPositionMapper.recover(
            anchor: ReadingAnchor(
                utf16Offset: 4,
                contextBefore: "A",
                contextAfter: "B"
            ),
            in: "ABxxAB"
        )

        XCTAssertEqual(uniqueNearest.anchor.utf16Offset, 5)
        XCTAssertFalse(uniqueNearest.requiresPause)
        XCTAssertNil(uniqueNearest.reason)
    }

    private func isScalarBoundary(_ offset: Int, in document: String) -> Bool {
        let units = Array(document.utf16)
        guard (0...units.count).contains(offset) else { return false }
        guard offset < units.count else { return true }
        return !(0xDC00...0xDFFF).contains(units[offset])
    }
}
