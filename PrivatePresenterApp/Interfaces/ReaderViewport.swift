import AppKit
import TeleprompterCore

@MainActor
protocol ReaderViewport: AnyObject {
    var attachmentView: NSView? { get }
    var clipSize: NSSize { get }
    var clipOriginY: Double { get }
    var maximumOffset: Double { get }
    var textMutationCount: Int { get }

    func ensureLayout()
    func captureAnchor(viewportFraction: Double) -> ReadingAnchor

    @discardableResult
    func restore(anchor: ReadingAnchor) -> Double

    func setClipOriginY(_ offset: Double)
    func threeCompleteLineStep() -> Double
}
