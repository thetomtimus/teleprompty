import Foundation

struct UTF16TextRange: Equatable, Hashable, Sendable {
    let location: Int
    let length: Int
}

enum ScriptTextEditError: Error, Equatable, Sendable {
    case arithmeticOverflow
    case invalidRevision
    case invalidRange
    case inconsistentLength
    case replacementMismatch
}

struct ScriptTextEdit: Equatable, Sendable {
    let range: UTF16TextRange
    let replacement: String
    let changeInLength: Int
    let baseUTF16Length: Int
    let resultUTF16Length: Int
    let baseRevision: UInt64
    let revision: UInt64

    static func replacing(
        in baseText: String,
        range: UTF16TextRange,
        with replacement: String,
        baseRevision: UInt64
    ) throws -> ScriptTextEdit {
        guard baseRevision != UInt64.max else { throw ScriptTextEditError.arithmeticOverflow }
        try validate(range: range, in: baseText)
        let replacementLength = replacement.utf16.count
        let (changeInLength, deltaOverflow) = replacementLength.subtractingReportingOverflow(
            range.length
        )
        guard !deltaOverflow else { throw ScriptTextEditError.arithmeticOverflow }
        let (resultLength, resultOverflow) = baseText.utf16.count.addingReportingOverflow(
            changeInLength
        )
        guard !resultOverflow, resultLength >= 0 else {
            throw ScriptTextEditError.arithmeticOverflow
        }
        return ScriptTextEdit(
            range: range,
            replacement: replacement,
            changeInLength: changeInLength,
            baseUTF16Length: baseText.utf16.count,
            resultUTF16Length: resultLength,
            baseRevision: baseRevision,
            revision: baseRevision + 1
        )
    }

    func applying(to baseText: String, revision currentRevision: UInt64) throws -> String {
        guard baseRevision == currentRevision,
            revision == baseRevision.addingReportingOverflow(1).partialValue,
            !baseRevision.addingReportingOverflow(1).overflow
        else { throw ScriptTextEditError.invalidRevision }
        guard baseText.utf16.count == baseUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        try Self.validate(range: range, in: baseText)
        let (expectedDelta, deltaOverflow) = replacement.utf16.count.subtractingReportingOverflow(
            range.length
        )
        guard !deltaOverflow, expectedDelta == changeInLength else {
            throw ScriptTextEditError.replacementMismatch
        }
        let (expectedLength, lengthOverflow) = baseUTF16Length.addingReportingOverflow(
            changeInLength
        )
        guard !lengthOverflow, expectedLength == resultUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        let result = NSMutableString(string: baseText)
        result.replaceCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: replacement
        )
        let resultString = result as String
        guard resultString.utf16.count == resultUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        return resultString
    }

    private static func validate(range: UTF16TextRange, in text: String) throws {
        guard range.location >= 0, range.length >= 0 else {
            throw ScriptTextEditError.invalidRange
        }
        let (end, overflow) = range.location.addingReportingOverflow(range.length)
        guard !overflow, end <= text.utf16.count,
            isUnicodeScalarBoundary(range.location, in: text),
            isUnicodeScalarBoundary(end, in: text)
        else {
            throw ScriptTextEditError.invalidRange
        }
    }

    private static func isUnicodeScalarBoundary(_ offset: Int, in text: String) -> Bool {
        let utf16 = text.utf16
        guard offset >= 0, offset <= utf16.count else { return false }
        guard offset > 0, offset < utf16.count else { return true }
        let previousIndex = utf16.index(utf16.startIndex, offsetBy: offset - 1)
        let currentIndex = utf16.index(utf16.startIndex, offsetBy: offset)
        let previous = utf16[previousIndex]
        let current = utf16[currentIndex]
        let previousIsHighSurrogate = previous >= 0xD800 && previous <= 0xDBFF
        let currentIsLowSurrogate = current >= 0xDC00 && current <= 0xDFFF
        return !(previousIsHighSurrogate && currentIsLowSurrogate)
    }
}
