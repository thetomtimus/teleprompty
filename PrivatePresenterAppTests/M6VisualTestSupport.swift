import AppKit
import CoreGraphics
import SwiftUI
import TeleprompterCore

@testable import PrivatePresenter

/// Test-only native rendering and a literal oracle that shares no production
/// visual value or geometry authority.
@MainActor
enum M6VisualTestSupport {
    static let canonicalSize = CGSize(width: 1_036, height: 460)
    static let backingScale: CGFloat = 2
    static let renderSizes = [
        CGSize(width: 320, height: 180),
        CGSize(width: 700, height: 350),
        canonicalSize,
        CGSize(width: 1_440, height: 460),
    ]

    enum SupportError: Error {
        case bitmapAllocation
        case backingScale
        case imageAllocation
        case colorSpace
        case fragmentLayout
        case missingAttribute
    }

    enum RenderState: CaseIterable {
        case unlocked
        case lockedVisible
        case lockedFocusHidden
    }

    enum CardMaskStyle: Equatable {
        case continuous
        case circular
    }

    enum Corruption: CaseIterable {
        case topGradientProbe
        case middleGradientProbe
        case bottomGradientProbe
        case interiorAlphaPatch
        case exteriorCorner
        case translatedDivider
        case translatedBand
        case translatedPill
        case translatedPrimaryControl

        var expectedFailureMetric: String {
            switch self {
            case .topGradientProbe, .middleGradientProbe, .bottomGradientProbe:
                "gradient"
            case .interiorAlphaPatch:
                "alpha"
            case .exteriorCorner:
                "corner"
            case .translatedDivider, .translatedBand, .translatedPill,
                .translatedPrimaryControl:
                "geometry"
            }
        }
    }

    struct RenderedOverlay {
        let image: CGImage
        let size: CGSize
        let scale: CGFloat
        let effectiveBackingScale: CGFloat
        let textKitBandBackingScale: CGFloat
        let bitmapUsesNonpremultipliedAlpha: Bool
        let state: RenderState
        let localeIdentifier: String
        let layoutDirection: LayoutDirection
        let appearanceName: NSAppearance.Name
        let font: NSFont
        let paragraphStyle: NSParagraphStyle
        let textColor: NSColor
        let readerFrame: CGRect
        let toolbarFrame: CGRect
        let readerGeometry: CGRect
        let readerFingerprint: UInt64
        let interiorIsOpaque: Bool
        let structuresAreContained: Bool
        let chromeIsAccessibilityNavigable: Bool
    }

    static let tierSizes = [
        CGSize(width: 320, height: 180),
        CGSize(width: 700, height: 350),
        CGSize(width: 1_036, height: 460),
    ]

    struct HostedControlState: Equatable {
        var fontSizePoints: Double
        var speedPointsPerSecond: Double
        var alignment: TeleprompterTextAlignment
        var isPaused: Bool
        var isFocusModeEnabled: Bool
        var isLocked: Bool
    }

    struct HostedAccessibilityControl: Equatable {
        let identifier: String
        let label: String?
        let isEnabled: Bool
    }

    struct HostedReaderEvidence: Equatable {
        let storageIdentity: ObjectIdentifier
        let storageText: String
        let fullReplacementCount: Int
        let textMutationCount: Int
        let attachmentFrame: CGRect
        let textFrame: CGRect
        let activeBandFrame: CGRect
        let textContainerInset: NSSize
        let hostingFrame: CGRect
        let panelWindowFrame: CGRect
        let anchor: ReadingAnchor?
    }

    struct HostedResizeChange: Equatable {
        let edge: ClampedPanelInteractionController.ResizeEdge
        let translation: CGSize
    }

    @MainActor
    final class HostedRootProbe {
        static let chromeIdentifiers = Set(
            OverlayChromeView.actionIdentifiers + OverlayQuickControlsView.actionIdentifiers
        )

        private final class CallbackRecorder {
            var resizeChanges: [HostedResizeChange] = []
            var resizeEndCount = 0
            var titleChanges: [CGSize] = []
            var titleEndCount = 0
            var showExistingControllerCount = 0
        }

        private struct HostedAccessibilityControlFrame {
            let identifier: String
            let screenFrame: CGRect
        }

        private let callbacks: CallbackRecorder
        private let model: AppModel
        private let system: ReaderTextSystem
        private let window: NSWindow
        private let hosting: NSHostingView<AnyView>
        private var hostedAccessibilityControlFrames: [HostedAccessibilityControlFrame] = []

        init(
            size: CGSize,
            scriptText: String = "Hosted semantic probe",
            initiallyPlaying: Bool = false
        ) {
            let callbacks = CallbackRecorder()
            self.callbacks = callbacks
            system = ReaderTextSystem(text: scriptText, revision: 0)
            let model = AppModel(
                overlayController: OverlayPanelController(),
                document: ScriptDocument(
                    title: "Hosted Presenter", text: scriptText
                ),
                restorationRequired: false,
                effectHandler: { effect in
                    if effect == .showExistingController {
                        callbacks.showExistingControllerCount += 1
                    }
                }
            )
            self.model = model
            let display = RuntimeDisplay(
                id: 6_006,
                localizedName: "Hosted Private Display",
                isBuiltIn: true,
                isMain: true,
                isOnline: true,
                frame: CGRect(origin: .zero, size: size),
                visibleFrame: CGRect(origin: .zero, size: size),
                scale: 2,
                persistentUUID: "hosted-private-display",
                mirrorSourceID: nil,
                isInMirrorSet: false
            )
            model.send(
                .displayInventoryLoaded(RuntimeDisplayInventory(displays: [display]))
            )
            model.send(.confirmSelectedDisplay)
            model.send(.completeShieldedMove(screenID: display.id))
            model.send(.showOverlay)
            if initiallyPlaying {
                model.send(.togglePlayback)
            }

            let root = AnyView(
                OverlayRootView(
                    model: model,
                    readerSystem: system,
                    onDragChanged: { translation in
                        if callbacks.titleChanges.isEmpty {
                            callbacks.titleChanges.append(translation)
                        } else {
                            callbacks.titleChanges[callbacks.titleChanges.index(before: callbacks.titleChanges.endIndex)] = translation
                        }
                    },
                    onDragEnded: { callbacks.titleEndCount += 1 },
                    onResizeChanged: { edge, translation in
                        let change = HostedResizeChange(edge: edge, translation: translation)
                        if callbacks.resizeChanges.last?.edge == edge {
                            callbacks.resizeChanges[callbacks.resizeChanges.index(before: callbacks.resizeChanges.endIndex)] = change
                        } else {
                            callbacks.resizeChanges.append(change)
                        }
                    },
                    onResizeEnded: { callbacks.resizeEndCount += 1 }
                )
                .frame(width: size.width, height: size.height)
            )
            hosting = NSHostingView(rootView: root)
            hosting.frame = CGRect(origin: .zero, size: size)
            window = NSWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = false
            window.contentView = hosting
            window.orderFrontRegardless()
            layout()
        }

        var controlState: HostedControlState {
            HostedControlState(
                fontSizePoints: model.preferences.fontSizePoints,
                speedPointsPerSecond: model.preferences.speedPointsPerSecond,
                alignment: model.preferences.textAlignment,
                isPaused: model.isPaused,
                isFocusModeEnabled: model.preferences.isFocusModeEnabled,
                isLocked: model.isLocked
            )
        }

        var commandDispatchCount: Int { model.commandDispatchCount }
        var isPrivatePresenterConfirmed: Bool { model.isSelectionConfirmed }
        var isShielded: Bool { model.isShielded }

        var resizeChanges: [HostedResizeChange] { callbacks.resizeChanges }
        var resizeEndCount: Int { callbacks.resizeEndCount }
        var titleChanges: [CGSize] { callbacks.titleChanges }
        var titleEndCount: Int { callbacks.titleEndCount }
        var showExistingControllerCount: Int { callbacks.showExistingControllerCount }

        func close() {
            window.orderOut(nil)
            window.close()
        }

        var accessibilityIdentifiers: Set<String> {
            Self.accessibilityIdentifiers(in: hosting)
        }

        var chromeIsAccessibilityNavigable: Bool {
            !accessibilityIdentifiers.intersection(Self.chromeIdentifiers).isEmpty
        }

        var readerEvidence: HostedReaderEvidence {
            let adapter = system.viewportAdapter
            return HostedReaderEvidence(
                storageIdentity: ObjectIdentifier(system.textStorage),
                storageText: system.textStorage.string,
                fullReplacementCount: system.fullReplacementCount,
                textMutationCount: system.textMutationCount,
                attachmentFrame: adapter?.attachmentView?.frame ?? .zero,
                textFrame: system.textView.frame,
                activeBandFrame: system.activeBandView.frame,
                textContainerInset: system.textView.textContainerInset,
                hostingFrame: hosting.frame,
                panelWindowFrame: window.frame,
                anchor: adapter?.captureAnchor(viewportFraction: 0.5)
            )
        }

        func setRenderState(_ state: RenderState) {
            switch state {
            case .unlocked:
                model.send(.setLocked(false))
                model.send(.focusChromeStateChanged(.unlocked))
            case .lockedVisible:
                model.send(.setLocked(true))
                model.send(.focusChromeStateChanged(.lockedChromeVisible))
            case .lockedFocusHidden:
                model.send(.setLocked(true))
                model.send(.focusChromeStateChanged(.lockedFocusChromeHidden))
            }
            layout()
        }

        func accessibilityControl(identifier: String) -> HostedAccessibilityControl? {
            guard let element = Self.accessibilityElements(in: hosting).first(where: {
                Self.accessibilityIdentifier(of: $0) == identifier
            }) else { return nil }
            return HostedAccessibilityControl(
                identifier: identifier,
                label: Self.accessibilityLabel(of: element),
                isEnabled: Self.accessibilityEnabled(of: element)
            )
        }

        @discardableResult
        func pressAccessibilityControl(identifier: String) -> Bool {
            guard let element = Self.accessibilityElements(in: hosting).first(where: {
                Self.accessibilityIdentifier(of: $0) == identifier
            }) else { return false }
            let performed = Self.performAccessibilityPress(on: element)
            layout()
            return performed
        }

        func press(at point: CGPoint) {
            guard hosting.bounds.contains(point), hostedHitTest(point) != nil else { return }
            send(type: .leftMouseDown, location: point, clickCount: 1)
            send(type: .leftMouseUp, location: point, clickCount: 1)
            layout()
        }

        func hostedIdentifier(at point: CGPoint) -> String? {
            guard hosting.bounds.contains(point), hostedHitTest(point) != nil else {
                return nil
            }
            let windowPoint = hosting.convert(point, to: nil)
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            return hostedAccessibilityControlFrames
                .filter { $0.screenFrame.contains(screenPoint) }
                .min {
                    $0.screenFrame.width * $0.screenFrame.height
                        < $1.screenFrame.width * $1.screenFrame.height
                }?
                .identifier
        }

        func drag(from point: CGPoint, by translation: CGSize) {
            guard hosting.bounds.contains(point), hostedHitTest(point) != nil else { return }
            let destination = CGPoint(
                x: point.x + translation.width, y: point.y + translation.height
            )
            send(type: .leftMouseDown, location: point, clickCount: 1)
            send(type: .leftMouseDragged, location: destination, clickCount: 1)
            send(type: .leftMouseUp, location: destination, clickCount: 1)
            layout()
        }

        private func hostedHitTest(_ point: CGPoint) -> NSView? {
            hosting.hitTest(point)
        }

        private func layout() {
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
            cacheHostedAccessibilityControlFrames()
        }

        private func cacheHostedAccessibilityControlFrames() {
            hostedAccessibilityControlFrames = Self.accessibilityElements(in: hosting)
                .compactMap { element in
                    guard let identifier = Self.accessibilityIdentifier(of: element),
                        Self.chromeIdentifiers.contains(identifier),
                        let screenFrame = Self.accessibilityFrame(of: element),
                        !screenFrame.isEmpty
                    else { return nil }
                    return HostedAccessibilityControlFrame(
                        identifier: identifier,
                        screenFrame: screenFrame
                    )
                }
        }

        private func send(
            type: NSEvent.EventType, location: CGPoint, clickCount: Int
        ) {
            guard let event = NSEvent.mouseEvent(
                with: type,
                location: location,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: clickCount,
                pressure: type == .leftMouseUp ? 0 : 1
            ) else { return }
            window.sendEvent(event)
        }

        fileprivate static func accessibilityIdentifiers(
            in root: NSAccessibilityProtocol
        ) -> Set<String> {
            Set(accessibilityElements(in: root).compactMap { accessibilityIdentifier(of: $0) })
        }

        private static func accessibilityElements(
            in root: NSAccessibilityProtocol
        ) -> [NSAccessibilityProtocol] {
            var result: [NSAccessibilityProtocol] = []
            var pending: [NSAccessibilityProtocol] = [root]
            var visited: Set<ObjectIdentifier> = []
            while let element = pending.popLast() {
                let identity = ObjectIdentifier(element)
                guard visited.insert(identity).inserted else { continue }
                result.append(element)
                pending.append(
                    contentsOf: (element.accessibilityChildren() ?? [])
                        .compactMap { $0 as? NSAccessibilityProtocol }
                )
            }
            return result
        }

        private static func accessibilityIdentifier(
            of element: NSAccessibilityProtocol
        ) -> String? {
            element.accessibilityIdentifier()
        }

        private static func accessibilityLabel(
            of element: NSAccessibilityProtocol
        ) -> String? {
            element.accessibilityLabel()
        }

        private static func accessibilityFrame(
            of element: NSAccessibilityProtocol
        ) -> CGRect? {
            element.accessibilityFrame()
        }

        private static func accessibilityEnabled(
            of element: NSAccessibilityProtocol
        ) -> Bool {
            element.isAccessibilityEnabled()
        }

        private static func performAccessibilityPress(
            on element: NSAccessibilityProtocol
        ) -> Bool {
            element.accessibilityPerformPress()
        }
    }

    struct PixelMask: Equatable {
        let width: Int
        let height: Int
        fileprivate var bits: [Bool]

        fileprivate subscript(x: Int, y: Int) -> Bool {
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            return bits[y * width + x]
        }
    }

    struct SemanticOracle {
        let image: CGImage
        let backgroundImage: CGImage
        let cardMask: PixelMask
        let erodedInteriorMask: PixelMask
        let edgeMask: PixelMask
        let exclusionMask: PixelMask
        let regions: [String: CGRect]
    }

    struct Comparison {
        let interiorAlphaFraction: Double
        let checkerboardMaximumDifference: Int
        let outsideCornerOpaquePixels: Int
        let gradientMaximumChannelError: Int
        let minimumRegionIntersectionOverUnion: Double
        let bandAndPillMeanAbsoluteError: Double
        let structuralMeanAbsoluteError: Double
        let structuralP99AbsoluteError: Double
        let structuralOutlierFraction: Double

        var interiorAlphaIsExact: Bool { interiorAlphaFraction == 1 }
        var checkerboardsMatch: Bool { checkerboardMaximumDifference == 0 }
        var outsideCornersAreClear: Bool { outsideCornerOpaquePixels == 0 }
        var gradientProbesPass: Bool { gradientMaximumChannelError <= 2 }
        var geometryPasses: Bool { minimumRegionIntersectionOverUnion >= 0.98 }
        var regionErrorsPass: Bool { bandAndPillMeanAbsoluteError <= 4.0 / 255 }
        var structuralErrorsPass: Bool {
            structuralMeanAbsoluteError <= 3.0 / 255
                && structuralP99AbsoluteError <= 8.0 / 255
                && structuralOutlierFraction <= 0.01
        }
        var passed: Bool {
            interiorAlphaIsExact && checkerboardsMatch && outsideCornersAreClear
                && gradientProbesPass && geometryPasses && regionErrorsPass
                && structuralErrorsPass
        }
        var failedMetrics: Set<String> {
            var result: Set<String> = []
            if !interiorAlphaIsExact || !checkerboardsMatch { result.insert("alpha") }
            if !outsideCornersAreClear { result.insert("corner") }
            if !gradientProbesPass { result.insert("gradient") }
            if !geometryPasses { result.insert("geometry") }
            if !regionErrorsPass { result.insert("region") }
            if !structuralErrorsPass { result.insert("structure") }
            return result
        }
        var summary: String {
            "alpha=\(interiorAlphaFraction) checker=\(checkerboardMaximumDifference) "
                + "corners=\(outsideCornerOpaquePixels) gradient=\(gradientMaximumChannelError) "
                + "iou=\(minimumRegionIntersectionOverUnion) region=\(bandAndPillMeanAbsoluteError) "
                + "mean=\(structuralMeanAbsoluteError) p99=\(structuralP99AbsoluteError) "
                + "outliers=\(structuralOutlierFraction)"
        }
    }

    private struct LiteralGeometry {
        let size: CGSize
        let bandFragmentHeights: [CGFloat]
        let headerHeight: CGFloat
        let sideInset: CGFloat
        let topReserve: CGFloat
        let bottomReserve: CGFloat
        let toolbarWidth: CGFloat
        let toolbarHeight: CGFloat
        let toolbarBottom: CGFloat
        let toolbarPadding: CGFloat
        let controlDiameter: CGFloat
        let controlSpacing: CGFloat

        init(size: CGSize, bandFragmentHeights: [CGFloat] = []) {
            self.size = size
            self.bandFragmentHeights = bandFragmentHeights
            if size.width >= 800, size.height >= 400 {
                headerHeight = 92
                sideInset = max(52, (size.width - 1_050) / 2)
                topReserve = 124
                bottomReserve = 114
                toolbarWidth = 387
                toolbarHeight = 65
                toolbarBottom = 24
                toolbarPadding = 10
                controlDiameter = 49
                controlSpacing = 4
            } else if size.width >= 520, size.height >= 280 {
                headerHeight = 72
                sideInset = max(48, (size.width - 1_050) / 2)
                topReserve = 96
                bottomReserve = 90
                toolbarWidth = 348
                toolbarHeight = 56
                toolbarBottom = 18
                toolbarPadding = 8
                controlDiameter = 44
                controlSpacing = 4
            } else {
                headerHeight = 52
                sideInset = max(20, (size.width - 1_050) / 2)
                topReserve = 58
                bottomReserve = 88
                toolbarWidth = 316
                toolbarHeight = 52
                toolbarBottom = 30
                toolbarPadding = 4
                controlDiameter = 44
                controlSpacing = 0
            }
        }

        var bounds: CGRect { CGRect(origin: .zero, size: size) }
        var readerFrame: CGRect {
            CGRect(
                x: sideInset,
                y: topReserve,
                width: min(1_050, max(0, size.width - 2 * sideInset)),
                height: max(0, size.height - topReserve - bottomReserve)
            )
        }
        var toolbarFrame: CGRect {
            CGRect(
                x: (size.width - toolbarWidth) / 2,
                y: toolbarBottom,
                width: toolbarWidth,
                height: toolbarHeight
            )
        }
        var bandFrame: CGRect {
            precondition(bandFragmentHeights.count == 2)
            let measuredHeight =
                bandFragmentHeights[0] + bandFragmentHeights[1] + 12
            let height = min(readerFrame.height, measuredHeight)
            return CGRect(
                x: max(0, sideInset - 18),
                y: size.height - (readerFrame.midY + height / 2),
                width: min(size.width, sideInset + readerFrame.width + 18)
                    - max(0, sideInset - 18),
                height: height
            )
        }
        var dividerFrame: CGRect {
            CGRect(x: 0, y: size.height - headerHeight, width: size.width, height: 1)
        }
        var primaryControlFrame: CGRect {
            CGRect(
                x: toolbarFrame.minX + toolbarPadding
                    + 4 * (controlDiameter + controlSpacing),
                y: toolbarFrame.minY + (toolbarHeight - controlDiameter) / 2,
                width: controlDiameter,
                height: controlDiameter
            )
        }
        var controlFrames: [CGRect] {
            (0..<7).map { index in
                CGRect(
                    x: toolbarFrame.minX + toolbarPadding
                        + CGFloat(index) * (controlDiameter + controlSpacing),
                    y: toolbarFrame.minY + (toolbarHeight - controlDiameter) / 2,
                    width: controlDiameter,
                    height: controlDiameter
                )
            }
        }
    }

    static func renderCanonicalOverlay() throws -> RenderedOverlay {
        try render(size: canonicalSize, state: .unlocked)
    }

    static func render(size: CGSize, state: RenderState) throws -> RenderedOverlay {
        let genericText = (1...28)
            .map { "Synthetic rehearsal line \($0) for deterministic visual testing." }
            .joined(separator: "\n")
        let system = ReaderTextSystem(text: genericText, revision: 0)
        system.updateAttributes(fontSize: 42, fontWeight: .regular, alignment: .left)
        let model = AppModel(
            overlayController: OverlayPanelController(),
            document: ScriptDocument(title: "Synthetic Presenter", text: genericText),
            restorationRequired: false
        )
        switch state {
        case .unlocked:
            break
        case .lockedVisible:
            model.send(.setLocked(true))
            model.send(.focusChromeStateChanged(.lockedFocusChromeVisible))
        case .lockedFocusHidden:
            model.send(.setLocked(true))
            model.send(.focusChromeStateChanged(.lockedFocusChromeHidden))
        }

        let locale = Locale(identifier: "en_US_POSIX")
        let root = OverlayRootView(model: model, readerSystem: system)
            .frame(width: size.width, height: size.height)
            .environment(\.locale, locale)
            .environment(\.layoutDirection, .leftToRight)
            .environment(\.colorScheme, .dark)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = backingScale
        let readerTextKitView = system.textView
        readerTextKitView.wantsLayer = true
        readerTextKitView.layer?.contentsScale = backingScale
        system.activeBandView.wantsLayer = true
        system.activeBandView.layer?.contentsScale = backingScale
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        }

        let pixelsWide = Int(size.width * backingScale)
        let pixelsHigh = Int(size.height * backingScale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: pixelsWide * 4,
            bitsPerPixel: 32
        ) else { throw SupportError.bitmapAllocation }
        bitmap.size = size
        let effectiveBackingScale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        guard effectiveBackingScale == backingScale else {
            throw SupportError.backingScale
        }
        guard hosting.layer?.contentsScale == backingScale,
            readerTextKitView.layer?.contentsScale == backingScale,
            system.activeBandView.layer?.contentsScale == backingScale
        else { throw SupportError.backingScale }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let sourceImage = bitmap.cgImage,
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: pixelsWide,
                height: pixelsHigh,
                bitsPerComponent: 8,
                bytesPerRow: pixelsWide * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw SupportError.imageAllocation }
        context.draw(sourceImage, in: CGRect(
            x: 0, y: 0, width: CGFloat(pixelsWide), height: CGFloat(pixelsHigh)
        ))
        guard let image = context.makeImage() else { throw SupportError.imageAllocation }

        guard genericText.utf16.count > 0 else { throw SupportError.missingAttribute }
        let attributes = system.textStorage.attributes(at: 0, effectiveRange: nil)
        guard let font = attributes[.font] as? NSFont,
            let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
            let color = attributes[.foregroundColor] as? NSColor
        else { throw SupportError.missingAttribute }

        let geometry = LiteralGeometry(size: size)
        let normalized = try PixelBuffer(image: image)
        let card = try makeLiteralCardMask(size: size, radius: 30, style: .continuous)
        let interior = eroded(card, by: 2)
        let interiorIsOpaque = interiorIndices(interior).allSatisfy {
            normalized.bytes[$0 * 4 + 3] == 255
        }
        let cardPath = RoundedRectangle(
            cornerRadius: 30, style: .continuous
        ).path(in: geometry.bounds).cgPath
        let structures = [geometry.toolbarFrame, geometry.primaryControlFrame]
        let structuresAreContained = structures.allSatisfy { rect in
            cornersAndCenter(of: rect).allSatisfy { cardPath.contains($0) }
        }
        let readerFingerprint = normalized.fingerprint(
            pointRect: geometry.readerFrame, scale: backingScale
        )
        return RenderedOverlay(
            image: image,
            size: size,
            scale: backingScale,
            effectiveBackingScale: effectiveBackingScale,
            textKitBandBackingScale: system.activeBandView.layer?.contentsScale ?? 0,
            bitmapUsesNonpremultipliedAlpha: !bitmap.bitmapFormat.isEmpty,
            state: state,
            localeIdentifier: locale.identifier,
            layoutDirection: .leftToRight,
            appearanceName: .darkAqua,
            font: font,
            paragraphStyle: paragraph,
            textColor: color,
            readerFrame: geometry.readerFrame,
            toolbarFrame: geometry.toolbarFrame,
            readerGeometry: geometry.readerFrame,
            readerFingerprint: readerFingerprint,
            interiorIsOpaque: interiorIsOpaque,
            structuresAreContained: structuresAreContained,
            chromeIsAccessibilityNavigable: !HostedRootProbe.accessibilityIdentifiers(
                in: hosting
            ).intersection(HostedRootProbe.chromeIdentifiers).isEmpty
        )
    }

    static func measureSyntheticTextKitFragmentHeights() throws -> [CGFloat] {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.frame = CGRect(x: 0, y: 0, width: 932, height: 222)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: 932, height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.wantsLayer = true
        textView.layer?.contentsScale = backingScale
        guard textView.layer?.contentsScale == backingScale else {
            throw SupportError.backingScale
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 1.42
        paragraph.paragraphSpacing = 0
        paragraph.hyphenationFactor = 0
        let text = "Independent synthetic first line.\n"
            + "Independent synthetic second line.\n"
            + "Independent synthetic third line."
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 42, weight: .regular),
                    .foregroundColor: NSColor(
                        srgbRed: 247.0 / 255,
                        green: 248.0 / 255,
                        blue: 252.0 / 255,
                        alpha: 1
                    ),
                    .paragraphStyle: paragraph,
                ]
            )
        )
        guard let textLayoutManager = textView.textLayoutManager,
            let textContentManager = textLayoutManager.textContentManager
        else { throw SupportError.fragmentLayout }
        let documentRange = textContentManager.documentRange
        textLayoutManager.ensureLayout(for: documentRange)
        var fragmentHeights: [CGFloat] = []
        _ = textLayoutManager.enumerateTextLayoutFragments(
            from: documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            for line in fragment.textLineFragments where fragmentHeights.count < 2 {
                let height = line.typographicBounds.height
                if height.isFinite, height > 0 {
                    fragmentHeights.append(height)
                }
            }
            return fragmentHeights.count < 2
        }
        guard fragmentHeights.count == 2 else {
            throw SupportError.fragmentLayout
        }
        return fragmentHeights
    }

    static func makeCanonicalSemanticOracle() throws -> SemanticOracle {
        try makeCanonicalSemanticOracle(
            fragmentHeights: measureSyntheticTextKitFragmentHeights()
        )
    }

    static func makeCanonicalSemanticOracle(
        fragmentHeights: [CGFloat]
    ) throws -> SemanticOracle {
        guard fragmentHeights.count == 2,
            fragmentHeights.allSatisfy({ $0.isFinite && $0 > 0 })
        else { throw SupportError.fragmentLayout }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw SupportError.colorSpace
        }
        let geometry = LiteralGeometry(
            size: canonicalSize, bandFragmentHeights: fragmentHeights
        )
        let image = try drawLiteralSurface(geometry: geometry, colorSpace: colorSpace)
        let backgroundImage = try drawLiteralBackground(
            geometry: geometry, colorSpace: colorSpace
        )
        let cardMask = try makeLiteralCardMask(radius: 30, style: .continuous)
        return SemanticOracle(
            image: image,
            backgroundImage: backgroundImage,
            cardMask: cardMask,
            erodedInteriorMask: eroded(cardMask, by: 2),
            edgeMask: literalTwoDevicePixelEdgeMask(),
            exclusionMask: literalGlyphAndIconExclusionMask(),
            regions: [
                "divider": geometry.dividerFrame,
                "band": geometry.bandFrame,
                "pill": geometry.toolbarFrame,
                "primary": geometry.primaryControlFrame,
            ]
        )
    }

    static func compare(_ actualImage: CGImage, with oracle: SemanticOracle) -> Comparison {
        guard let actual = try? PixelBuffer(image: actualImage),
            let expected = try? PixelBuffer(image: oracle.image),
            let background = try? PixelBuffer(image: oracle.backgroundImage),
            actual.width == expected.width, actual.height == expected.height
        else {
            return Comparison(
                interiorAlphaFraction: 0,
                checkerboardMaximumDifference: 255,
                outsideCornerOpaquePixels: .max,
                gradientMaximumChannelError: 255,
                minimumRegionIntersectionOverUnion: 0,
                bandAndPillMeanAbsoluteError: 1,
                structuralMeanAbsoluteError: 1,
                structuralP99AbsoluteError: 1,
                structuralOutlierFraction: 1
            )
        }

        let interior = interiorIndices(oracle.erodedInteriorMask)
        let opaqueCount = interior.reduce(0) {
            $0 + (actual.bytes[$1 * 4 + 3] == 255 ? 1 : 0)
        }
        let interiorAlphaFraction = interior.isEmpty
            ? 0 : Double(opaqueCount) / Double(interior.count)
        var checkerboardMaximumDifference = 0
        for index in interior {
            let alpha = Int(actual.bytes[index * 4 + 3])
            for channel in 0..<3 {
                let value = Int(actual.bytes[index * 4 + channel])
                let overWhite = (value * alpha + 255 * (255 - alpha)) / 255
                let overBlack = (value * alpha) / 255
                checkerboardMaximumDifference = max(
                    checkerboardMaximumDifference, abs(overWhite - overBlack)
                )
            }
        }

        var outsideCornerOpaquePixels = 0
        for y in 0..<actual.height {
            for x in 0..<actual.width where !oracle.cardMask[x, y] && !oracle.edgeMask[x, y] {
                if actual.alpha(x: x, y: y) != 0 { outsideCornerOpaquePixels += 1 }
            }
        }

        let probes = [
            CGRect(x: 480, y: 432, width: 76, height: 12),
            CGRect(x: 480, y: 226, width: 76, height: 12),
            CGRect(x: 480, y: 16, width: 76, height: 12),
        ]
        let gradientMaximumChannelError = probes.reduce(0) { maximum, rect in
            max(maximum, maximumChannelError(actual, expected, pointRect: rect))
        }

        let regionIOUs = oracle.regions.map { name, pointRect in
            if name == "primary" {
                return brightRegionIntersectionOverUnion(
                    actual: actual,
                    expected: expected,
                    pointRect: pointRect.insetBy(dx: -6, dy: -6)
                )
            }
            return regionIntersectionOverUnion(
                actual: actual,
                expected: expected,
                background: background,
                pointRect: pointRect.insetBy(dx: -6, dy: -6)
            )
        }
        let minimumRegionIntersectionOverUnion = regionIOUs.min() ?? 0
        let bandAndPillMeanAbsoluteError = meanAbsoluteError(
            actual,
            expected,
            pointRects: [oracle.regions["band"]!, oracle.regions["pill"]!],
            excluding: oracle.exclusionMask
        )

        var structuralErrors: [Double] = []
        structuralErrors.reserveCapacity(interior.count * 3)
        for index in interior where !oracle.exclusionMask.bits[index] {
            for channel in 0..<3 {
                structuralErrors.append(
                    Double(abs(Int(actual.bytes[index * 4 + channel])
                        - Int(expected.bytes[index * 4 + channel]))) / 255
                )
            }
        }
        structuralErrors.sort()
        let structuralMeanAbsoluteError = structuralErrors.isEmpty
            ? 1 : structuralErrors.reduce(0, +) / Double(structuralErrors.count)
        let p99Index = max(0, Int(ceil(0.99 * Double(structuralErrors.count))) - 1)
        let structuralP99AbsoluteError = structuralErrors.isEmpty
            ? 1 : structuralErrors[p99Index]
        let structuralOutlierFraction = structuralErrors.isEmpty
            ? 1
            : Double(structuralErrors.filter { $0 > 8.0 / 255 }.count)
                / Double(structuralErrors.count)

        return Comparison(
            interiorAlphaFraction: interiorAlphaFraction,
            checkerboardMaximumDifference: checkerboardMaximumDifference,
            outsideCornerOpaquePixels: outsideCornerOpaquePixels,
            gradientMaximumChannelError: gradientMaximumChannelError,
            minimumRegionIntersectionOverUnion: minimumRegionIntersectionOverUnion,
            bandAndPillMeanAbsoluteError: bandAndPillMeanAbsoluteError,
            structuralMeanAbsoluteError: structuralMeanAbsoluteError,
            structuralP99AbsoluteError: structuralP99AbsoluteError,
            structuralOutlierFraction: structuralOutlierFraction
        )
    }

    static func corrupt(_ image: CGImage, corruption: Corruption) throws -> CGImage {
        var buffer = try PixelBuffer(image: image)
        let geometry = LiteralGeometry(
            size: canonicalSize,
            bandFragmentHeights: try measureSyntheticTextKitFragmentHeights()
        )
        let devicePixelTranslation = 4
        switch corruption {
        case .topGradientProbe:
            buffer.paint(pointRect: CGRect(x: 500, y: 434, width: 24, height: 8), rgba: [255, 0, 0, 255])
        case .middleGradientProbe:
            buffer.paint(pointRect: CGRect(x: 500, y: 228, width: 24, height: 8), rgba: [0, 255, 0, 255])
        case .bottomGradientProbe:
            buffer.paint(pointRect: CGRect(x: 500, y: 18, width: 24, height: 8), rgba: [0, 0, 255, 255])
        case .interiorAlphaPatch:
            buffer.paint(pointRect: CGRect(x: 760, y: 210, width: 12, height: 12), rgba: [0, 0, 0, 0])
        case .exteriorCorner:
            buffer.paintDevice(rect: CGRect(x: 0, y: 0, width: 12, height: 12), rgba: [255, 255, 255, 255])
        case .translatedDivider:
            buffer.translate(
                pointRect: geometry.dividerFrame,
                devicePixels: devicePixelTranslation,
                vertically: true
            )
        case .translatedBand:
            buffer.translate(
                pointRect: geometry.bandFrame,
                devicePixels: devicePixelTranslation,
                vertically: true
            )
        case .translatedPill:
            buffer.translate(
                pointRect: geometry.toolbarFrame,
                devicePixels: devicePixelTranslation,
                vertically: true
            )
        case .translatedPrimaryControl:
            buffer.translate(
                pointRect: geometry.primaryControlFrame,
                devicePixels: devicePixelTranslation,
                vertically: false
            )
        }
        return try buffer.makeImage()
    }

    static func makeLiteralCardMask(
        radius: CGFloat,
        style: CardMaskStyle
    ) throws -> PixelMask {
        try makeLiteralCardMask(size: canonicalSize, radius: radius, style: style)
    }

    static func cardMaskMatchesCanonical(_ candidate: PixelMask) -> Bool {
        guard let canonical = try? makeLiteralCardMask(radius: 30, style: .continuous) else {
            return false
        }
        return candidate == canonical
    }

    static func literalGlyphAndIconExclusionMask() -> PixelMask {
        var mask = emptyMask(size: canonicalSize)
        let geometry = LiteralGeometry(size: canonicalSize)
        let pointRects = [
            CGRect(x: 40, y: 382, width: 610, height: 58),
            CGRect(x: 840, y: 382, width: 150, height: 58),
        ] + (0..<4).map { line in
            let topY = 124 + CGFloat(line) * 59.64
            return CGRect(
                x: 45,
                y: canonicalSize.height - topY - 51,
                width: 946,
                height: 51
            )
        } + geometry.controlFrames.map { frame in
            CGRect(x: frame.midX - 13, y: frame.midY - 13, width: 26, height: 26)
        }
        for rect in pointRects { mask.set(pointRect: rect, scale: backingScale) }
        return mask
    }

    static func literalTwoDevicePixelEdgeMask() -> PixelMask {
        guard let card = try? makeLiteralCardMask(radius: 30, style: .continuous) else {
            return emptyMask(size: canonicalSize)
        }
        let inside = eroded(card, by: 2)
        let outside = dilated(card, by: 2)
        var ring = emptyMask(size: canonicalSize)
        for index in ring.bits.indices {
            ring.bits[index] = outside.bits[index] && !inside.bits[index]
        }
        return ring
    }

    private static func makeLiteralCardMask(
        size: CGSize,
        radius: CGFloat,
        style: CardMaskStyle
    ) throws -> PixelMask {
        let literalBounds = CGRect(origin: .zero, size: size)
        let path: CGPath
        if radius == 30, style == .continuous {
            path = RoundedRectangle(cornerRadius: 30, style: .continuous).path(in: literalBounds).cgPath
        } else {
            let cornerStyle: RoundedCornerStyle = style == .continuous ? .continuous : .circular
            path = RoundedRectangle(cornerRadius: radius, style: cornerStyle)
                .path(in: literalBounds).cgPath
        }
        let width = Int(size.width * backingScale)
        let height = Int(size.height * backingScale)
        var bits = Array(repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(
                    x: (CGFloat(x) + 0.5) / backingScale,
                    y: (CGFloat(y) + 0.5) / backingScale
                )
                bits[y * width + x] = path.contains(point)
            }
        }
        return PixelMask(width: width, height: height, bits: bits)
    }

    private static func drawLiteralSurface(
        geometry: LiteralGeometry,
        colorSpace: CGColorSpace
    ) throws -> CGImage {
        var buffer = PixelBuffer(size: geometry.size, scale: backingScale)
        try buffer.withContext(colorSpace: colorSpace) { context in
            context.scaleBy(x: backingScale, y: backingScale)
            let path = RoundedRectangle(cornerRadius: 30, style: .continuous)
                .path(in: geometry.bounds).cgPath
            context.addPath(path)
            context.clip()
            drawCardGradient(context: context, geometry: geometry, colorSpace: colorSpace)

            context.setFillColor(literalColor(255, 255, 255, 0.08, colorSpace))
            context.fill(geometry.dividerFrame)
            drawBand(context: context, geometry: geometry, colorSpace: colorSpace)
            drawPill(context: context, geometry: geometry, colorSpace: colorSpace)
            context.setFillColor(literalColor(247, 248, 252, 1, colorSpace))
            context.fillEllipse(in: geometry.primaryControlFrame)
            context.setStrokeColor(literalColor(255, 255, 255, 0.24, colorSpace))
            context.setLineWidth(1)
            context.addPath(path)
            context.strokePath()
        }
        return try buffer.makeImage()
    }

    private static func drawLiteralBackground(
        geometry: LiteralGeometry,
        colorSpace: CGColorSpace
    ) throws -> CGImage {
        var buffer = PixelBuffer(size: geometry.size, scale: backingScale)
        try buffer.withContext(colorSpace: colorSpace) { context in
            context.scaleBy(x: backingScale, y: backingScale)
            let path = RoundedRectangle(cornerRadius: 30, style: .continuous)
                .path(in: geometry.bounds).cgPath
            context.addPath(path)
            context.clip()
            drawCardGradient(context: context, geometry: geometry, colorSpace: colorSpace)
        }
        return try buffer.makeImage()
    }

    private static func drawCardGradient(
        context: CGContext,
        geometry: LiteralGeometry,
        colorSpace: CGColorSpace
    ) {
        let colors = [
            literalColor(32, 43, 75, 1, colorSpace),
            literalColor(44, 61, 99, 1, colorSpace),
            literalColor(52, 70, 111, 1, colorSpace),
        ] as CFArray
        let locations: [CGFloat] = [0, 0.58, 1]
        guard let gradient = CGGradient(
            colorsSpace: colorSpace, colors: colors, locations: locations
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: geometry.size.height),
            options: []
        )
    }

    private static func drawBand(
        context: CGContext,
        geometry: LiteralGeometry,
        colorSpace: CGColorSpace
    ) {
        context.saveGState()
        let path = CGPath(
            roundedRect: geometry.bandFrame,
            cornerWidth: 8,
            cornerHeight: 8,
            transform: nil
        )
        context.addPath(path)
        context.clip()
        let colors = [
            literalColor(130, 160, 213, 0.28, colorSpace),
            literalColor(113, 145, 202, 0.35, colorSpace),
            literalColor(130, 160, 213, 0.20, colorSpace),
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1]
        ) else { context.restoreGState(); return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: geometry.bandFrame.minX, y: geometry.bandFrame.midY),
            end: CGPoint(x: geometry.bandFrame.maxX, y: geometry.bandFrame.midY),
            options: []
        )
        context.setFillColor(literalColor(190, 211, 248, 0.62, colorSpace))
        context.fill(
            CGRect(
                x: geometry.bandFrame.minX,
                y: geometry.bandFrame.minY,
                width: 3,
                height: geometry.bandFrame.height
            )
        )
        context.restoreGState()
    }

    private static func drawPill(
        context: CGContext,
        geometry: LiteralGeometry,
        colorSpace: CGColorSpace
    ) {
        let path = CGPath(
            roundedRect: geometry.toolbarFrame,
            cornerWidth: geometry.toolbarHeight / 2,
            cornerHeight: geometry.toolbarHeight / 2,
            transform: nil
        )
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -8),
            blur: 16,
            color: literalColor(7, 12, 30, 0.34, colorSpace)
        )
        context.setFillColor(literalColor(70, 92, 145, 0.98, colorSpace))
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()
        let colors = [
            literalColor(70, 92, 145, 0.98, colorSpace),
            literalColor(90, 113, 165, 0.98, colorSpace),
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace, colors: colors, locations: [0, 1]
        ) else { context.restoreGState(); return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: geometry.toolbarFrame.minY),
            end: CGPoint(x: 0, y: geometry.toolbarFrame.maxY),
            options: []
        )
        context.restoreGState()
        context.setStrokeColor(literalColor(255, 255, 255, 0.13, colorSpace))
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()
    }

    private static func literalColor(
        _ red: CGFloat,
        _ green: CGFloat,
        _ blue: CGFloat,
        _ alpha: CGFloat,
        _ colorSpace: CGColorSpace
    ) -> CGColor {
        CGColor(
            colorSpace: colorSpace,
            components: [red / 255, green / 255, blue / 255, alpha]
        )!
    }

    private static func emptyMask(size: CGSize) -> PixelMask {
        let width = Int(size.width * backingScale)
        let height = Int(size.height * backingScale)
        return PixelMask(
            width: width,
            height: height,
            bits: Array(repeating: false, count: width * height)
        )
    }

    private static func eroded(_ mask: PixelMask, by distance: Int) -> PixelMask {
        var result = mask
        for y in 0..<mask.height {
            for x in 0..<mask.width where mask[x, y] {
                outer: for dy in -distance...distance {
                    for dx in -distance...distance where !mask[x + dx, y + dy] {
                        result.bits[y * mask.width + x] = false
                        break outer
                    }
                }
            }
        }
        return result
    }

    private static func dilated(_ mask: PixelMask, by distance: Int) -> PixelMask {
        var result = mask
        for y in 0..<mask.height {
            for x in 0..<mask.width where !mask[x, y] {
                outer: for dy in -distance...distance {
                    for dx in -distance...distance where mask[x + dx, y + dy] {
                        result.bits[y * mask.width + x] = true
                        break outer
                    }
                }
            }
        }
        return result
    }

    private static func interiorIndices(_ mask: PixelMask) -> [Int] {
        mask.bits.indices.filter { mask.bits[$0] }
    }

    private static func cornersAndCenter(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX + 0.5, y: rect.minY + 0.5),
            CGPoint(x: rect.maxX - 0.5, y: rect.minY + 0.5),
            CGPoint(x: rect.minX + 0.5, y: rect.maxY - 0.5),
            CGPoint(x: rect.maxX - 0.5, y: rect.maxY - 0.5),
            CGPoint(x: rect.midX, y: rect.midY),
        ]
    }

    private static func maximumChannelError(
        _ actual: PixelBuffer,
        _ expected: PixelBuffer,
        pointRect: CGRect
    ) -> Int {
        var maximum = 0
        for index in actual.indices(pointRect: pointRect, scale: backingScale) {
            for channel in 0..<3 {
                maximum = max(
                    maximum,
                    abs(Int(actual.bytes[index * 4 + channel])
                        - Int(expected.bytes[index * 4 + channel]))
                )
            }
        }
        return maximum
    }

    private static func meanAbsoluteError(
        _ actual: PixelBuffer,
        _ expected: PixelBuffer,
        pointRects: [CGRect],
        excluding mask: PixelMask
    ) -> Double {
        let indices = pointRects.flatMap {
            actual.indices(pointRect: $0, scale: backingScale)
        }.filter { !mask.bits[$0] }
        guard !indices.isEmpty else { return 1 }
        var total = 0
        for index in indices {
            for channel in 0..<3 {
                total += abs(Int(actual.bytes[index * 4 + channel])
                    - Int(expected.bytes[index * 4 + channel]))
            }
        }
        return Double(total) / Double(indices.count * 3 * 255)
    }

    private static func regionIntersectionOverUnion(
        actual: PixelBuffer,
        expected: PixelBuffer,
        background: PixelBuffer,
        pointRect: CGRect
    ) -> Double {
        var intersection = 0
        var union = 0
        for index in actual.indices(pointRect: pointRect, scale: backingScale) {
            let actualDelta = (0..<3).reduce(0) {
                $0 + abs(Int(actual.bytes[index * 4 + $1])
                    - Int(background.bytes[index * 4 + $1]))
            }
            let expectedDelta = (0..<3).reduce(0) {
                $0 + abs(Int(expected.bytes[index * 4 + $1])
                    - Int(background.bytes[index * 4 + $1]))
            }
            let actualMember = actualDelta > 9
            let expectedMember = expectedDelta > 9
            if actualMember && expectedMember { intersection += 1 }
            if actualMember || expectedMember { union += 1 }
        }
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }

    private static func brightRegionIntersectionOverUnion(
        actual: PixelBuffer,
        expected: PixelBuffer,
        pointRect: CGRect
    ) -> Double {
        var intersection = 0
        var union = 0
        for index in actual.indices(pointRect: pointRect, scale: backingScale) {
            let actualMember = (0..<3).allSatisfy {
                actual.bytes[index * 4 + $0] >= 220
            }
            let expectedMember = (0..<3).allSatisfy {
                expected.bytes[index * 4 + $0] >= 220
            }
            if actualMember && expectedMember { intersection += 1 }
            if actualMember || expectedMember { union += 1 }
        }
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }

    @MainActor
    private struct PixelBuffer {
        let width: Int
        let height: Int
        let scale: CGFloat
        var bytes: [UInt8]

        init(size: CGSize, scale: CGFloat) {
            width = Int(size.width * scale)
            height = Int(size.height * scale)
            self.scale = scale
            bytes = Array(repeating: 0, count: width * height * 4)
        }

        init(image: CGImage) throws {
            width = image.width
            height = image.height
            scale = backingScale
            bytes = Array(repeating: 0, count: width * height * 4)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                throw SupportError.colorSpace
            }
            let created = bytes.withUnsafeMutableBytes { storage -> Bool in
                guard let context = CGContext(
                    data: storage.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(
                    image,
                    in: CGRect(
                        x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)
                    )
                )
                return true
            }
            guard created else { throw SupportError.bitmapAllocation }
        }

        mutating func withContext(
            colorSpace: CGColorSpace,
            _ draw: (CGContext) throws -> Void
        ) throws {
            var thrown: Error?
            let created = bytes.withUnsafeMutableBytes { storage -> Bool in
                guard let context = CGContext(
                    data: storage.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                do { try draw(context) } catch { thrown = error }
                return true
            }
            if let thrown { throw thrown }
            guard created else { throw SupportError.bitmapAllocation }
        }

        func makeImage() throws -> CGImage {
            let data = Data(bytes) as CFData
            guard let provider = CGDataProvider(data: data),
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                let image = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                )
            else { throw SupportError.imageAllocation }
            return image
        }

        func alpha(x: Int, y: Int) -> UInt8 {
            bytes[(y * width + x) * 4 + 3]
        }

        func indices(pointRect: CGRect, scale: CGFloat) -> [Int] {
            let rect = CGRect(
                x: pointRect.minX * scale,
                y: pointRect.minY * scale,
                width: pointRect.width * scale,
                height: pointRect.height * scale
            ).intersection(
                CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            )
            guard !rect.isNull else { return [] }
            return (Int(floor(rect.minY))..<Int(ceil(rect.maxY))).flatMap { y in
                (Int(floor(rect.minX))..<Int(ceil(rect.maxX))).map { x in y * width + x }
            }
        }

        func fingerprint(pointRect: CGRect, scale: CGFloat) -> UInt64 {
            var hash: UInt64 = 14_695_981_039_346_656_037
            for index in indices(pointRect: pointRect, scale: scale) {
                for channel in 0..<4 {
                    hash ^= UInt64(bytes[index * 4 + channel])
                    hash &*= 1_099_511_628_211
                }
            }
            return hash
        }

        mutating func paint(pointRect: CGRect, rgba: [UInt8]) {
            for index in indices(pointRect: pointRect, scale: scale) {
                bytes.replaceSubrange(index * 4..<(index * 4 + 4), with: rgba)
            }
        }

        mutating func paintDevice(rect: CGRect, rgba: [UInt8]) {
            for y in Int(rect.minY)..<Int(rect.maxY) {
                for x in Int(rect.minX)..<Int(rect.maxX) where x >= 0 && y >= 0 && x < width && y < height {
                    let index = (y * width + x) * 4
                    bytes.replaceSubrange(index..<(index + 4), with: rgba)
                }
            }
        }

        mutating func translate(
            pointRect: CGRect,
            devicePixels: Int,
            vertically: Bool
        ) {
            let sourceIndices = indices(pointRect: pointRect, scale: scale)
            let snapshot = bytes
            for index in sourceIndices {
                let source = index * 4
                bytes[source..<(source + 4)] = [0, 0, 0, 0]
            }
            for index in sourceIndices {
                let x = index % width
                let y = index / width
                let destinationX = x + (vertically ? 0 : devicePixels)
                let destinationY = y + (vertically ? devicePixels : 0)
                if destinationX < width, destinationY < height {
                    let destination = (destinationY * width + destinationX) * 4
                    let source = index * 4
                    bytes[destination..<(destination + 4)] = snapshot[source..<(source + 4)]
                }
            }
        }
    }
}

private extension M6VisualTestSupport.PixelMask {
    mutating func set(pointRect: CGRect, scale: CGFloat) {
        let rect = CGRect(
            x: pointRect.minX * scale,
            y: pointRect.minY * scale,
            width: pointRect.width * scale,
            height: pointRect.height * scale
        ).intersection(
            CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )
        guard !rect.isNull else { return }
        for y in Int(floor(rect.minY))..<Int(ceil(rect.maxY)) {
            for x in Int(floor(rect.minX))..<Int(ceil(rect.maxX)) {
                bits[y * width + x] = true
            }
        }
    }
}
