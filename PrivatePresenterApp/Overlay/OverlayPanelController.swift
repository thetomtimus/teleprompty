import AppKit
import SwiftUI
import TeleprompterCore

struct OverlayConfigurationSnapshot: Equatable, Sendable {
    let panelCount: Int
    let isBorderless: Bool
    let isNonactivating: Bool
    let isNativelyResizable: Bool
    let joinsAllSpaces: Bool
    let isFullScreenAuxiliary: Bool
    let level: String
    #if DEBUG
    let ordering: String
    #endif
    let isLocked: Bool
    let ignoresMouseEvents: Bool
    let canBecomeKey: Bool
    let canBecomeMain: Bool
    let interiorIsFullyOpaque: Bool
}

enum OverlayPanelOperation: Equatable {
    case orderOut
    case applyContainedFrame
    case orderFrontRegardless
    #if DEBUG
    case orderFront
    #endif
    case setLocked(Bool)
    case activateApplication
    case showWindow
    case makeKey
    case makeMain
}

struct OverlayAppliedFrameRecord: Equatable, Sendable {
    let displayID: UInt32?
    let appliedFrame: NSRect
    let selectedFullFrame: NSRect
    let selectedVisibleFrame: NSRect
    let containmentFrame: NSRect
}

/// Sole owner and creator of the process's one teleprompter panel.
@MainActor
final class OverlayPanelController: NSWindowController {
    let teleprompterPanel: TeleprompterPanel
    let interactionController: ClampedPanelInteractionController
    let readerTextSystem: ReaderTextSystem
    private(set) var selectedFullScreenFrame: NSRect?
    private(set) var selectedVisibleScreenFrame: NSRect?
    private(set) var selectedScreenFrame: NSRect?
    private(set) var selectedDisplayID: UInt32?
    private(set) var appliedFrames: [NSRect] = []
    private var interactionStartFrame: NSRect?
    private let operationRecorder: (OverlayPanelOperation) -> Void
    private let appliedFrameRecorder: (OverlayAppliedFrameRecord) -> Void
    private weak var connectedModel: AppModel?
    private(set) var hostingControllerConstructionCount = 0
    var onAppliedFrame: ((OverlayAppliedFrameRecord) -> Void)?
    var onReaderAttachmentChanged: (@MainActor (Bool) -> Void)?
    var onReaderScreenChanged: (@MainActor () -> Void)?
    var onReaderBoundsWillChange: (@MainActor () -> Void)?
    var onReaderBoundsChanged: (@MainActor () -> Void)?
    #if DEBUG
    let orderingMode: OverlayPanelOrderingMode
    #endif

    #if DEBUG
    convenience init(
        initialFrame: NSRect = NSRect(x: 0, y: 0, width: 700, height: 350),
        proofLevel: OverlayPanelLevel = .statusBar,
        orderingMode: OverlayPanelOrderingMode = .frontRegardless,
        operationRecorder: @escaping (OverlayPanelOperation) -> Void = { _ in },
        appliedFrameRecorder: @escaping (OverlayAppliedFrameRecord) -> Void = { _ in }
    ) {
        self.init(
            initialFrame: initialFrame,
            proofLevel: proofLevel,
            orderingModeObject: orderingMode,
            operationRecorder: operationRecorder,
            appliedFrameRecorder: appliedFrameRecorder
        )
    }
    #else
    convenience init(
        initialFrame: NSRect = NSRect(x: 0, y: 0, width: 700, height: 350),
        proofLevel: OverlayPanelLevel = .statusBar,
        operationRecorder: @escaping (OverlayPanelOperation) -> Void = { _ in },
        appliedFrameRecorder: @escaping (OverlayAppliedFrameRecord) -> Void = { _ in }
    ) {
        self.init(
            initialFrame: initialFrame,
            proofLevel: proofLevel,
            orderingModeObject: nil,
            operationRecorder: operationRecorder,
            appliedFrameRecorder: appliedFrameRecorder
        )
    }
    #endif

    private init(
        initialFrame: NSRect,
        proofLevel: OverlayPanelLevel,
        orderingModeObject: Any?,
        operationRecorder: @escaping (OverlayPanelOperation) -> Void,
        appliedFrameRecorder: @escaping (OverlayAppliedFrameRecord) -> Void
    ) {
        let panel = TeleprompterPanel(contentRect: initialFrame, proofLevel: proofLevel)
        teleprompterPanel = panel
        readerTextSystem = ReaderTextSystem(text: "", revision: 0)
        #if DEBUG
        orderingMode = orderingModeObject as? OverlayPanelOrderingMode ?? .frontRegardless
        #endif
        self.operationRecorder = operationRecorder
        self.appliedFrameRecorder = appliedFrameRecorder
        interactionController = ClampedPanelInteractionController { [weak panel] frame in
            operationRecorder(.applyContainedFrame)
            panel?.setFrame(frame, display: false)
        }
        super.init(window: panel)

    }

    @discardableResult
    func connect(model: AppModel) -> Bool {
        if let connectedModel {
            return connectedModel === model
        }
        connectedModel = model
        teleprompterPanel.contentViewController = NSHostingController(
            rootView: OverlayRootView(
                model: model,
                readerSystem: readerTextSystem,
                onReaderAttachmentChanged: { [weak self] isAttached in
                    self?.onReaderAttachmentChanged?(isAttached)
                },
                onReaderScreenChanged: { [weak self] in
                    self?.onReaderScreenChanged?()
                },
                onReaderBoundsWillChange: { [weak self] in
                    self?.onReaderBoundsWillChange?()
                },
                onReaderBoundsChanged: { [weak self] in
                    self?.onReaderBoundsChanged?()
                },
                onDragChanged: { [weak self] translation in
                    self?.updateDrag(translation: translation)
                },
                onDragEnded: { [weak self] in
                    self?.endInteraction()
                },
                onResizeChanged: { [weak self] edge, translation in
                    self?.updateResize(edge: edge, translation: translation)
                },
                onResizeEnded: { [weak self] in
                    self?.endInteraction()
                }
            )
        )
        hostingControllerConstructionCount += 1
        return true
    }

    var connectedModelIdentity: ObjectIdentifier? {
        connectedModel.map(ObjectIdentifier.init)
    }

    func teardownConnection() {
        hide()
        onAppliedFrame = nil
        onReaderAttachmentChanged = nil
        onReaderScreenChanged = nil
        onReaderBoundsWillChange = nil
        onReaderBoundsChanged = nil
        teleprompterPanel.contentViewController = nil
        connectedModel = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func stageHidden(
        proposedFrame: NSRect,
        on visibleFrame: NSRect,
        fullFrame: NSRect? = nil,
        displayID: UInt32? = nil
    ) {
        configureSelectedFrames(
            visibleFrame: visibleFrame,
            fullFrame: fullFrame,
            displayID: displayID
        )
        operationRecorder(.orderOut)
        teleprompterPanel.orderOut(nil)
        applyContainedFrame(proposedFrame)
    }

    func show(
        proposedFrame: NSRect,
        on visibleFrame: NSRect,
        fullFrame: NSRect? = nil,
        displayID: UInt32? = nil
    ) {
        configureSelectedFrames(
            visibleFrame: visibleFrame,
            fullFrame: fullFrame,
            displayID: displayID
        )
        applyContainedFrame(proposedFrame)
        // Intentionally neither makeKeyAndOrderFront nor NSApp.activate.
        #if DEBUG
        switch orderingMode {
        case .front:
            operationRecorder(.orderFront)
            teleprompterPanel.orderFront(nil)
        case .frontRegardless:
            operationRecorder(.orderFrontRegardless)
            teleprompterPanel.orderFrontRegardless()
        }
        #else
        operationRecorder(.orderFrontRegardless)
        teleprompterPanel.orderFrontRegardless()
        #endif
    }

    func hide() {
        operationRecorder(.orderOut)
        teleprompterPanel.orderOut(nil)
    }

    func setLocked(_ locked: Bool) {
        operationRecorder(.setLocked(locked))
        teleprompterPanel.setLocked(locked)
    }

    @discardableResult
    func applyContainedFrame(_ candidate: NSRect) -> NSRect? {
        guard let selectedScreenFrame else { return nil }
        let frame = interactionController.apply(candidate: candidate, inside: selectedScreenFrame)
        recordAppliedFrame(frame)
        return frame
    }

    func defaultFrame(on visibleFrame: NSRect) -> NSRect {
        NSRect(
            PanelFramePolicy(safeTopInset: 24).defaultFrame(
                in: DisplayRect(visibleFrame)
            )
        )
    }

    func updateDrag(translation: CGSize) {
        guard let selectedScreenFrame else { return }
        let start = interactionStartFrame ?? teleprompterPanel.frame
        interactionStartFrame = start
        let frame = interactionController.drag(
            frame: start,
            delta: NSSize(width: translation.width, height: translation.height),
            inside: selectedScreenFrame
        )
        recordAppliedFrame(frame)
    }

    func updateResize(
        edge: ClampedPanelInteractionController.ResizeEdge,
        translation: CGSize
    ) {
        guard let selectedScreenFrame else { return }
        let start = interactionStartFrame ?? teleprompterPanel.frame
        interactionStartFrame = start
        let frame = interactionController.resize(
            frame: start,
            edge: edge,
            delta: NSSize(width: translation.width, height: translation.height),
            inside: selectedScreenFrame
        )
        recordAppliedFrame(frame)
    }

    func endInteraction() {
        interactionStartFrame = nil
    }

    private func configureSelectedFrames(
        visibleFrame: NSRect,
        fullFrame: NSRect?,
        displayID: UInt32?
    ) {
        selectedFullScreenFrame = fullFrame ?? visibleFrame
        selectedVisibleScreenFrame = visibleFrame
        selectedScreenFrame = visibleFrame
        selectedDisplayID = displayID
        teleprompterPanel.containmentFrame = visibleFrame
    }

    private func recordAppliedFrame(_ frame: NSRect) {
        guard
            let selectedFullScreenFrame,
            let selectedVisibleScreenFrame,
            let selectedScreenFrame
        else { return }
        appliedFrames.append(frame)
        let record = OverlayAppliedFrameRecord(
            displayID: selectedDisplayID,
            appliedFrame: frame,
            selectedFullFrame: selectedFullScreenFrame,
            selectedVisibleFrame: selectedVisibleScreenFrame,
            containmentFrame: selectedScreenFrame
        )
        appliedFrameRecorder(record)
        onAppliedFrame?(record)
    }

    var configurationSnapshot: OverlayConfigurationSnapshot {
        let mask = teleprompterPanel.styleMask
        let behavior = teleprompterPanel.collectionBehavior
        #if DEBUG
        return OverlayConfigurationSnapshot(
            panelCount: 1,
            isBorderless: !mask.contains(.titled),
            isNonactivating: mask.contains(.nonactivatingPanel),
            isNativelyResizable: mask.contains(.resizable),
            joinsAllSpaces: behavior.contains(.canJoinAllSpaces),
            isFullScreenAuxiliary: behavior.contains(.fullScreenAuxiliary),
            level: OverlayPanelLevel.allCases.first(where: {
                $0.appKitLevel == teleprompterPanel.level
            })?.rawValue ?? "unbounded",
            ordering: orderingMode.rawValue,
            isLocked: teleprompterPanel.isOverlayLocked,
            ignoresMouseEvents: teleprompterPanel.ignoresMouseEvents,
            canBecomeKey: teleprompterPanel.canBecomeKey,
            canBecomeMain: teleprompterPanel.canBecomeMain,
            interiorIsFullyOpaque: OverlayRootView.interiorIsFullyOpaque
        )
        #else
        return OverlayConfigurationSnapshot(
            panelCount: 1,
            isBorderless: !mask.contains(.titled),
            isNonactivating: mask.contains(.nonactivatingPanel),
            isNativelyResizable: mask.contains(.resizable),
            joinsAllSpaces: behavior.contains(.canJoinAllSpaces),
            isFullScreenAuxiliary: behavior.contains(.fullScreenAuxiliary),
            level: OverlayPanelLevel.allCases.first(where: {
                $0.appKitLevel == teleprompterPanel.level
            })?.rawValue ?? "unbounded",
            isLocked: teleprompterPanel.isOverlayLocked,
            ignoresMouseEvents: teleprompterPanel.ignoresMouseEvents,
            canBecomeKey: teleprompterPanel.canBecomeKey,
            canBecomeMain: teleprompterPanel.canBecomeMain,
            interiorIsFullyOpaque: OverlayRootView.interiorIsFullyOpaque
        )
        #endif
    }
}
