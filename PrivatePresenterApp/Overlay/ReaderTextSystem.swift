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
    private(set) var effectiveFont = NSFont.systemFont(ofSize: 42, weight: .regular)
    private var pendingLayoutReason: PerformanceSignpostReason? = .initial
    private(set) weak var viewportAdapter: ReaderViewportAdapter?
    var onResyncRequested: (@MainActor (UInt64) -> Void)?
    var onLayoutCompleted: (@MainActor () -> Void)?
    let performanceRegistry: PerformanceIntervalRegistry

    init(
        text: String,
        revision: UInt64,
        performanceRegistry: PerformanceIntervalRegistry = PerformanceIntervalRegistry(
            signposter: DisabledPerformanceSignposter()
        ),
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
        self.performanceRegistry = performanceRegistry
        self.onResyncRequested = onResyncRequested

        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
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
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        textMutationCount += 1
        updateAttributes(fontSize: 42, fontWeight: .regular, alignment: .left)
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
        switch reason {
        case .initial:
            pendingLayoutReason = .initial
        case .restore:
            pendingLayoutReason = .restore
        case .resync:
            pendingLayoutReason = .resync
        case .clear:
            pendingLayoutReason = nil
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

    func updateAttributes(
        fontSize: Double,
        fontWeight: TeleprompterFontWeight = .regular,
        alignment: TeleprompterTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment == .center ? .center : .left
        paragraph.lineHeightMultiple = 1.42
        paragraph.paragraphSpacing = 0
        paragraph.hyphenationFactor = 0
        effectiveFont = NSFont.systemFont(
            ofSize: CGFloat(fontSize), weight: Self.appKitWeight(for: fontWeight)
        )
        readerAttributes = [
            .font: effectiveFont,
            .foregroundColor: OverlayVisualTokens.readingText.appKitColor,
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
        let metrics = OverlayLayoutMetrics(size: NSSize(width: width, height: height))
        let contentHeight = max(height, documentHeight ?? height)
        textView.textContainerInset = NSSize(
            width: metrics.effectiveReadingSideInset,
            height: 24
        )
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

    static func appKitWeight(for weight: TeleprompterFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        }
    }

    func fallbackLineHeight(backingScaleFactor: CGFloat) -> CGFloat {
        let scale = backingScaleFactor.isFinite && backingScaleFactor > 0
            ? backingScaleFactor : 1
        let rawHeight =
            (effectiveFont.ascender - effectiveFont.descender + effectiveFont.leading) * 1.42
        return ceil(rawHeight * scale) / scale
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

    func layoutCompleted() {
        onLayoutCompleted?()
    }

    func takeLayoutReason() -> PerformanceSignpostReason? {
        defer { pendingLayoutReason = nil }
        return pendingLayoutReason
    }

    private func latchResync() {
        guard !isAwaitingResync else { return }
        isAwaitingResync = true
        resyncRequestCount += 1
        onResyncRequested?(appliedRevision)
    }
}
