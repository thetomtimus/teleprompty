import AppKit

@MainActor
final class EditorTextSystem: NSObject, NSTextStorageDelegate {
    let textView: NSTextView
    let textStorage: NSTextStorage
    private var authoritativeText: String
    private var authoritativeRevision: UInt64
    private var suppressesCallbacks = false
    private let onEdit: @MainActor (ScriptTextEdit) -> Void

    init(
        text: String,
        revision: UInt64,
        onEdit: @escaping @MainActor (ScriptTextEdit) -> Void
    ) {
        let textView = NSTextView(usingTextLayoutManager: true)
        guard let textStorage = textView.textStorage else {
            preconditionFailure("TextKit 2 editor requires text storage")
        }
        self.textView = textView
        self.textStorage = textStorage
        authoritativeText = text
        authoritativeRevision = revision
        self.onEdit = onEdit
        super.init()

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        configureViewport(NSSize(width: 720, height: 300))
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        textStorage.delegate = self
    }

    func configureViewport(_ size: NSSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        textView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        textView.minSize = NSSize(width: 0, height: height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
    }

    func synchronize(text: String, revision: UInt64) {
        guard text != authoritativeText || revision != authoritativeRevision else { return }
        suppressesCallbacks = true
        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: NSRange(location: 0, length: textStorage.length),
            with: text
        )
        textStorage.endEditing()
        authoritativeText = text
        authoritativeRevision = revision
        suppressesCallbacks = false
    }

    func replaceCharactersForTesting(in range: NSRange, with replacement: String) {
        textStorage.replaceCharacters(in: range, with: replacement)
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters), !suppressesCallbacks else { return }
        guard let edit = try? Self.deriveEdit(
            postEditText: textStorage.string,
            processedRange: editedRange,
            changeInLength: delta,
            baseText: authoritativeText,
            baseRevision: authoritativeRevision
        ) else {
            synchronize(text: authoritativeText, revision: authoritativeRevision)
            return
        }
        authoritativeText = textStorage.string
        authoritativeRevision = edit.revision
        onEdit(edit)
    }

    static func deriveEdit(
        postEditText: String,
        processedRange: NSRange,
        changeInLength: Int,
        baseText: String,
        baseRevision: UInt64
    ) throws -> ScriptTextEdit {
        guard processedRange.location >= 0, processedRange.length >= 0 else {
            throw ScriptTextEditError.invalidRange
        }
        let (originalLength, overflow) = processedRange.length.subtractingReportingOverflow(
            changeInLength
        )
        guard !overflow, originalLength >= 0 else {
            throw ScriptTextEditError.arithmeticOverflow
        }
        let postText = postEditText as NSString
        let (processedEnd, endOverflow) = processedRange.location.addingReportingOverflow(
            processedRange.length
        )
        guard !endOverflow else {
            throw ScriptTextEditError.arithmeticOverflow
        }
        guard processedEnd <= postText.length else {
            throw ScriptTextEditError.invalidRange
        }
        let replacement = postText.substring(with: processedRange)
        let edit = try ScriptTextEdit.replacing(
            in: baseText,
            range: UTF16TextRange(
                location: processedRange.location,
                length: originalLength
            ),
            with: replacement,
            baseRevision: baseRevision
        )
        guard edit.changeInLength == changeInLength,
            edit.resultUTF16Length == postEditText.utf16.count
        else { throw ScriptTextEditError.inconsistentLength }
        return edit
    }
}
