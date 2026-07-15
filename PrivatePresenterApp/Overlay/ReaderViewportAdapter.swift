import AppKit
import TeleprompterCore

@MainActor
final class ReaderViewportAdapter: ReaderViewport {
    static let documentBottomPadding = 64.0

    struct LineFragmentEvidence {
        let utf16Range: Range<Int>
        let frame: NSRect
    }

    private let system: ReaderTextSystem
    private weak var hostedView: NSView?
    private weak var scrollView: ReaderScrollView?
    private var lineMetrics: [LineFragmentEvidence] = []
    private var viewportFraction: Double

    private(set) var laidOutTextBottom = 0.0
    private(set) var lastRestoredAnchor: ReadingAnchor?

    init(
        system: ReaderTextSystem,
        attachmentView: NSView,
        scrollView: ReaderScrollView,
        viewportFraction: Double
    ) {
        self.system = system
        hostedView = attachmentView
        self.scrollView = scrollView
        self.viewportFraction = Self.clampedFraction(viewportFraction)
    }

    var attachmentView: NSView? { hostedView }

    var clipSize: NSSize {
        scrollView?.contentSize ?? .zero
    }

    var clipOriginY: Double {
        Double(scrollView?.contentView.bounds.origin.y ?? 0)
    }

    var maximumOffset: Double {
        max(
            0,
            laidOutTextBottom + Self.documentBottomPadding - Double(clipSize.height)
        )
    }

    var textMutationCount: Int {
        system.textMutationCount
    }

    func ensureLayout() {
        guard clipSize.width > 0, clipSize.height > 0 else {
            laidOutTextBottom = 0
            lineMetrics = []
            return
        }

        let priorDocumentHeight = laidOutTextBottom > 0
            ? CGFloat(laidOutTextBottom + Self.documentBottomPadding)
            : nil
        system.configureViewport(clipSize, documentHeight: priorDocumentHeight)
        guard
            let textLayoutManager = system.textView.textLayoutManager,
            let textContentManager = textLayoutManager.textContentManager
        else {
            laidOutTextBottom = 0
            lineMetrics = []
            return
        }

        let documentRange = textContentManager.documentRange
        textLayoutManager.ensureLayout(for: documentRange)

        let textContainerOrigin = system.textView.textContainerOrigin
        var metrics: [LineFragmentEvidence] = []
        var textBottom = 0.0
        _ = textLayoutManager.enumerateTextLayoutFragments(
            from: documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentFrame = fragment.layoutFragmentFrame
            textBottom = max(
                textBottom,
                Double(fragmentFrame.maxY + textContainerOrigin.y)
            )
            let fragmentOffset = textContentManager.offset(
                from: documentRange.location,
                to: fragment.rangeInElement.location
            )
            guard fragmentOffset != NSNotFound, fragmentOffset >= 0 else {
                return true
            }

            for line in fragment.textLineFragments {
                let characterRange = line.characterRange
                guard
                    characterRange.location != NSNotFound,
                    characterRange.location >= 0,
                    characterRange.length > 0
                else {
                    continue
                }
                let (lowerBound, lowerOverflow) = fragmentOffset.addingReportingOverflow(
                    characterRange.location
                )
                let (upperBound, upperOverflow) = lowerBound.addingReportingOverflow(
                    characterRange.length
                )
                guard
                    !lowerOverflow,
                    !upperOverflow,
                    lowerBound >= 0,
                    lowerBound < upperBound,
                    upperBound <= system.textStorage.length
                else {
                    continue
                }

                let bounds = line.typographicBounds
                metrics.append(
                    LineFragmentEvidence(
                        utf16Range: lowerBound..<upperBound,
                        frame: bounds.offsetBy(
                            dx: fragmentFrame.minX + textContainerOrigin.x,
                            dy: fragmentFrame.minY + textContainerOrigin.y
                        )
                    )
                )
            }
            return true
        }

        lineMetrics = metrics.sorted { $0.frame.minY < $1.frame.minY }
        laidOutTextBottom = textBottom
        system.configureViewport(
            clipSize,
            documentHeight: CGFloat(laidOutTextBottom + Self.documentBottomPadding)
        )
        setClipOriginY(clipOriginY)
    }

    func captureAnchor(viewportFraction: Double) -> ReadingAnchor {
        ensureLayout()
        let fraction = Self.clampedFraction(viewportFraction)
        let targetY = clipOriginY + Double(clipSize.height) * fraction
        let metric = lineMetrics.min {
            abs(Double($0.frame.midY) - targetY) < abs(Double($1.frame.midY) - targetY)
        }
        let offset = normalizedScalarOffset(metric?.utf16Range.lowerBound ?? 0)
        let contexts = anchorContexts(at: offset)
        return ReadingAnchor(
            utf16Offset: offset,
            contextBefore: contexts.before,
            contextAfter: contexts.after,
            viewportFraction: fraction,
            document: system.textStorage.string
        )
    }

    @discardableResult
    func restore(anchor: ReadingAnchor) -> Double {
        updateViewportFraction(anchor.viewportFraction)
        ensureLayout()
        lastRestoredAnchor = anchor.clamped(to: system.textStorage.string)
        guard let anchorY = anchorY(forUTF16Offset: anchor.utf16Offset) else {
            setClipOriginY(0)
            return 0
        }

        let restored = ReadingPositionMapper.restoredOffset(
            anchorY: anchorY,
            clipHeight: Double(clipSize.height),
            viewportFraction: viewportFraction,
            maximumOffset: maximumOffset
        )
        setClipOriginY(restored)
        return clipOriginY
    }

    func setClipOriginY(_ offset: Double) {
        guard let clipView = scrollView?.contentView as? ReaderClipView else { return }
        clipView.setProgrammaticOriginY(offset, maximumOffset: maximumOffset)
    }

    func threeCompleteLineStep() -> Double {
        let completeFragments = completeLineFragmentEvidenceInViewport()
        guard completeFragments.count >= 3 else {
            return Self.fallbackManualStep(clipHeight: Double(clipSize.height))
        }
        let firstThree = completeFragments.prefix(3)
        guard let first = firstThree.first, let third = firstThree.last else {
            return Self.fallbackManualStep(clipHeight: Double(clipSize.height))
        }
        let span = Double(third.frame.maxY - first.frame.minY)
        guard span.isFinite, span > 0 else {
            return Self.fallbackManualStep(clipHeight: Double(clipSize.height))
        }
        return span
    }

    func completeLineFragmentEvidenceInViewport() -> [LineFragmentEvidence] {
        ensureLayout()
        let viewportStart = clipOriginY
        let viewportEnd = viewportStart + Double(clipSize.height)
        return lineMetrics.filter { metric in
            let start = Double(metric.frame.minY)
            let end = Double(metric.frame.maxY)
            return start >= viewportStart
                && end <= viewportEnd
                && metric.frame.height > 0
                && !metric.utf16Range.isEmpty
        }
    }

    func anchorY(forUTF16Offset offset: Int) -> Double? {
        if lineMetrics.isEmpty {
            ensureLayout()
        }
        guard !lineMetrics.isEmpty else { return nil }
        let normalizedOffset = normalizedScalarOffset(offset)
        let containing = lineMetrics.first {
            $0.utf16Range.contains(normalizedOffset)
                || ($0.utf16Range.upperBound == normalizedOffset
                    && normalizedOffset == system.textStorage.length)
        }
        let nearest = containing ?? lineMetrics.min {
            abs(Double($0.utf16Range.lowerBound) - Double(normalizedOffset))
                < abs(Double($1.utf16Range.lowerBound) - Double(normalizedOffset))
        }
        return nearest.map { Double($0.frame.midY) }
    }

    func updateViewportFraction(_ fraction: Double) {
        viewportFraction = Self.clampedFraction(fraction)
        (hostedView as? ReaderViewportContainerView)?.updateViewportFraction(
            viewportFraction
        )
    }

    static func fallbackManualStep(clipHeight: Double) -> Double {
        min(max(0.15 * max(clipHeight, 0), 80), 240)
    }

    private func normalizedScalarOffset(_ offset: Int) -> Int {
        let units = Array(system.textStorage.string.utf16)
        var result = min(max(offset, 0), units.count)
        if result < units.count, (0xDC00...0xDFFF).contains(units[result]) {
            result -= 1
        }
        return result
    }

    private func anchorContexts(at offset: Int) -> (before: String, after: String) {
        let units = Array(system.textStorage.string.utf16)
        let limit = ReadingAnchor.maximumContextUTF16Length
        var beforeStart = max(0, offset - limit)
        if beforeStart < offset, (0xDC00...0xDFFF).contains(units[beforeStart]) {
            beforeStart += 1
        }
        var afterEnd = min(units.count, offset + limit)
        if afterEnd > offset, (0xD800...0xDBFF).contains(units[afterEnd - 1]) {
            afterEnd -= 1
        }
        return (
            String(decoding: units[beforeStart..<offset], as: UTF16.self),
            String(decoding: units[offset..<afterEnd], as: UTF16.self)
        )
    }

    private static func clampedFraction(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0.5 }
        return min(max(fraction, 0), 1)
    }
}
