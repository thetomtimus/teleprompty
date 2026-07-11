import Foundation

public struct PanelResizeEdges: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let left = PanelResizeEdges(rawValue: 1 << 0)
    public static let right = PanelResizeEdges(rawValue: 1 << 1)
    public static let bottom = PanelResizeEdges(rawValue: 1 << 2)
    public static let top = PanelResizeEdges(rawValue: 1 << 3)
}

public struct PanelFramePolicy: Sendable {
    public static let defaultMinimumSize = DisplaySize(width: 320, height: 180)

    public let safeTopInset: Double
    public let minimumSize: DisplaySize

    public init(
        safeTopInset: Double = 24,
        minimumSize: DisplaySize = PanelFramePolicy.defaultMinimumSize
    ) {
        self.safeTopInset = max(0, safeTopInset)
        self.minimumSize = minimumSize
    }

    public func defaultFrame(in visibleFrame: DisplayRect) -> DisplayRect {
        let screen = standardized(visibleFrame)
        let width = screen.width * 0.70
        let height = screen.height * 0.35
        let candidate = DisplayRect(
            x: screen.minX + (screen.width - width) / 2,
            y: screen.maxY - min(safeTopInset, screen.height) - height,
            width: width,
            height: height
        )
        return clamp(
            candidate,
            to: screen,
            minimumSize: DisplaySize(width: 0, height: 0)
        )
    }

    public func normalize(
        _ frame: DisplayRect,
        in visibleFrame: DisplayRect
    ) -> NormalizedPanelFrame {
        let screen = standardized(visibleFrame)
        guard screen.width > 0, screen.height > 0 else {
            return NormalizedPanelFrame(x: 0, y: 0, width: 0, height: 0)
        }
        let contained = clamp(frame, to: screen)
        return NormalizedPanelFrame(
            x: (contained.x - screen.x) / screen.width,
            y: (contained.y - screen.y) / screen.height,
            width: contained.width / screen.width,
            height: contained.height / screen.height
        )
    }

    public func restore(
        _ normalized: NormalizedPanelFrame,
        in visibleFrame: DisplayRect
    ) -> DisplayRect {
        let screen = standardized(visibleFrame)
        let candidate = DisplayRect(
            x: screen.x + finiteOrZero(normalized.x) * screen.width,
            y: screen.y + finiteOrZero(normalized.y) * screen.height,
            width: finiteOrZero(normalized.width) * screen.width,
            height: finiteOrZero(normalized.height) * screen.height
        )
        return clamp(candidate, to: screen)
    }

    public func clamp(
        _ frame: DisplayRect,
        to visibleFrame: DisplayRect,
        minimumSize requestedMinimum: DisplaySize? = nil,
        maximumSize requestedMaximum: DisplaySize? = nil
    ) -> DisplayRect {
        let screen = standardized(visibleFrame)
        guard screen.width > 0, screen.height > 0 else {
            return DisplayRect(x: screen.x, y: screen.y, width: 0, height: 0)
        }

        let minimum = requestedMinimum ?? minimumSize
        let maximum = requestedMaximum ?? DisplaySize(
            width: screen.width,
            height: screen.height
        )
        let maximumWidth = min(positiveOr(maximum.width, fallback: screen.width), screen.width)
        let maximumHeight = min(positiveOr(maximum.height, fallback: screen.height), screen.height)
        let minimumWidth = min(max(0, finiteOrZero(minimum.width)), maximumWidth)
        let minimumHeight = min(max(0, finiteOrZero(minimum.height)), maximumHeight)
        let width = bounded(
            positiveOr(frame.width, fallback: minimumWidth),
            minimum: minimumWidth,
            maximum: maximumWidth
        )
        let height = bounded(
            positiveOr(frame.height, fallback: minimumHeight),
            minimum: minimumHeight,
            maximum: maximumHeight
        )
        let x = bounded(
            frame.x.isFinite ? frame.x : screen.minX,
            minimum: screen.minX,
            maximum: screen.maxX - width
        )
        let y = bounded(
            frame.y.isFinite ? frame.y : screen.minY,
            minimum: screen.minY,
            maximum: screen.maxY - height
        )
        return DisplayRect(x: x, y: y, width: width, height: height)
    }

    public func translatedFrame(
        _ frame: DisplayRect,
        deltaX: Double,
        deltaY: Double,
        in visibleFrame: DisplayRect
    ) -> DisplayRect {
        let candidate = DisplayRect(
            x: frame.x + finiteOrZero(deltaX),
            y: frame.y + finiteOrZero(deltaY),
            width: frame.width,
            height: frame.height
        )
        return clamp(candidate, to: visibleFrame)
    }

    public func resizedFrame(
        _ frame: DisplayRect,
        edges: PanelResizeEdges,
        deltaX: Double,
        deltaY: Double,
        in visibleFrame: DisplayRect
    ) -> DisplayRect {
        var candidate = frame
        let horizontalDelta = finiteOrZero(deltaX)
        let verticalDelta = finiteOrZero(deltaY)

        if edges.contains(.left) {
            candidate.x += horizontalDelta
            candidate.width -= horizontalDelta
        }
        if edges.contains(.right) {
            candidate.width += horizontalDelta
        }
        if edges.contains(.bottom) {
            candidate.y += verticalDelta
            candidate.height -= verticalDelta
        }
        if edges.contains(.top) {
            candidate.height += verticalDelta
        }

        return clamp(candidate, to: visibleFrame)
    }

    private func standardized(_ rect: DisplayRect) -> DisplayRect {
        let finiteX = rect.x.isFinite ? rect.x : 0
        let finiteY = rect.y.isFinite ? rect.y : 0
        let finiteWidth = rect.width.isFinite ? rect.width : 0
        let finiteHeight = rect.height.isFinite ? rect.height : 0
        return DisplayRect(
            x: finiteWidth >= 0 ? finiteX : finiteX + finiteWidth,
            y: finiteHeight >= 0 ? finiteY : finiteY + finiteHeight,
            width: abs(finiteWidth),
            height: abs(finiteHeight)
        )
    }

    private func finiteOrZero(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private func positiveOr(_ value: Double, fallback: Double) -> Double {
        value.isFinite && value > 0 ? value : fallback
    }

    private func bounded(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
