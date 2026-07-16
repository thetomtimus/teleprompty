import AppKit
import TeleprompterCore

enum ReaderFullReplacementReason: String, CaseIterable, Equatable, Hashable, Sendable {
    case initial
    case restore
    case clear
    case resync
}

@MainActor
final class ReaderTextSystem {
    let textView: NSTextView
    let textStorage: NSTextStorage
    let activeBandView: NSView
    private(set) var appliedRevision: UInt64
    private(set) var isAwaitingResync = false
    private(set) var incrementalMutationCount = 0
    private(set) var fullReplacementCount = 0
    private(set) var resyncRequestCount = 0
    private(set) var textMutationCount = 0
    private(set) var isActiveBandEnabled = true
    private var readerAttributes: [NSAttributedString.Key: Any] = [:]
    private(set) weak var viewportAdapter: ReaderViewportAdapter?
    var onResyncRequested: (@MainActor (UInt64) -> Void)?

    init(
        text: String,
        revision: UInt64,
        onResyncRequested: (@MainActor (UInt64) -> Void)? = nil
    ) {
        let textView = NSTextView(usingTextLayoutManager: true)
        guard let textStorage = textView.textStorage else {
            preconditionFailure("TextKit 2 reader requires text storage")
        }
        self.textView = textView
        self.textStorage = textStorage
        activeBandView = ReaderActiveBandView()
        appliedRevision = revision
        self.onResyncRequested = onResyncRequested

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 28, height: 24)
        let accessibility = PresenterAccessibility.staticEntry(
            "privatePresenter.reader"
        )
        textView.identifier = NSUserInterfaceItemIdentifier(accessibility.identifier)
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel(accessibility.label)
        textView.setAccessibilityHelp(accessibility.help)
        configureViewport(NSSize(width: 640, height: 360))
        activeBandView.wantsLayer = true
        activeBandView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        textMutationCount += 1
    }

    func apply(_ edit: ScriptTextEdit) {
        guard !isAwaitingResync else { return }
        guard edit.revision > appliedRevision else { return }
        guard edit.baseRevision == appliedRevision,
            appliedRevision != UInt64.max,
            edit.revision == appliedRevision + 1,
            textStorage.length == edit.baseUTF16Length,
            let result = try? edit.applying(
                to: textStorage.string,
                revision: appliedRevision
            )
        else {
            latchResync()
            return
        }

        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: NSRange(location: edit.range.location, length: edit.range.length),
            with: edit.replacement
        )
        if !edit.replacement.isEmpty {
            textStorage.addAttributes(
                readerAttributes,
                range: NSRange(
                    location: edit.range.location,
                    length: edit.replacement.utf16.count
                )
            )
        }
        textStorage.endEditing()
        textMutationCount += 1
        guard textStorage.length == edit.resultUTF16Length,
            textStorage.string == result
        else {
            latchResync()
            return
        }
        appliedRevision = edit.revision
        incrementalMutationCount += 1
    }

    func replaceAuthoritatively(
        text: String,
        revision: UInt64,
        reason: ReaderFullReplacementReason
    ) {
        if reason == .resync {
            guard isAwaitingResync, revision >= appliedRevision else { return }
        } else {
            guard revision >= appliedRevision else { return }
        }
        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: NSRange(location: 0, length: textStorage.length),
            with: text
        )
        if textStorage.length > 0 {
            textStorage.addAttributes(
                readerAttributes,
                range: NSRange(location: 0, length: textStorage.length)
            )
        }
        textStorage.endEditing()
        textMutationCount += 1
        appliedRevision = revision
        fullReplacementCount += 1
        isAwaitingResync = false
    }

    func updateAttributes(fontSize: Double, alignment: TeleprompterTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment == .center ? .center : .left
        readerAttributes = [
            .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]
        if textStorage.length > 0 {
            textStorage.setAttributes(
                readerAttributes,
                range: NSRange(location: 0, length: textStorage.length)
            )
        }
    }

    func configureViewport(_ size: NSSize, documentHeight: CGFloat? = nil) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let contentHeight = max(height, documentHeight ?? height)
        textView.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
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

    #if DEBUG
    func replaceStorageForTesting(_ text: String) {
        textStorage.replaceCharacters(
            in: NSRange(location: 0, length: textStorage.length),
            with: text
        )
        textMutationCount += 1
    }
    #endif

    func setActiveBandEnabled(_ enabled: Bool) {
        isActiveBandEnabled = enabled
        activeBandView.isHidden = !enabled
    }

    func attachViewportAdapter(_ adapter: ReaderViewportAdapter) {
        viewportAdapter = adapter
    }

    private func latchResync() {
        guard !isAwaitingResync else { return }
        isAwaitingResync = true
        resyncRequestCount += 1
        onResyncRequested?(appliedRevision)
    }
}
