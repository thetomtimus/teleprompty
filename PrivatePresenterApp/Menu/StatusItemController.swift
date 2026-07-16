import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let actionItems: [NSMenuItem]
    private(set) var isRemoved = false
    private var actionsReady = false

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu(title: "Private Presenter")
        let definitions: [(String, Selector)] = [
            ("Show Controller", #selector(showController)),
            ("Start", #selector(togglePlayback)),
            ("Show Teleprompter", #selector(toggleVisibility)),
            ("Lock", #selector(toggleLock)),
            ("Quit", #selector(requestQuit)),
        ]
        actionItems = definitions.map { title, selector in
            NSMenuItem(title: title, action: selector, keyEquivalent: "")
        }
        super.init()

        for item in actionItems {
            item.target = self
            menu.addItem(item)
        }
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.title = "Private Presenter"
        statusItem.button?.toolTip = "Private Presenter controls"
        updatePresentation()
    }

    var modelIdentity: ObjectIdentifier { ObjectIdentifier(model) }
    var actionItemCount: Int { actionItems.count }
    var actionTitles: [String] { actionItems.map(\.title) }
    var statusItemTitle: String { statusItem.button?.title ?? "" }
    var statusItemToolTip: String { statusItem.button?.toolTip ?? "" }

    func setActionsReady(_ ready: Bool) {
        actionsReady = ready
        updatePresentation()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updatePresentation()
    }

    func invokeForTesting(index: Int) {
        guard actionItems.indices.contains(index) else { return }
        dispatch(index: index)
    }

    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func showController() { dispatch(index: 0) }
    @objc private func togglePlayback() { dispatch(index: 1) }
    @objc private func toggleVisibility() { dispatch(index: 2) }
    @objc private func toggleLock() { dispatch(index: 3) }
    @objc private func requestQuit() { dispatch(index: 4) }

    private func dispatch(index: Int) {
        let command: AppCommand
        switch index {
        case 0: command = .showController
        case 1: command = .togglePlayback
        case 2: command = .toggleVisibility
        case 3: command = .toggleLock
        case 4: command = .requestQuit
        default: return
        }
        model.send(command)
    }

    private func updatePresentation() {
        actionItems[0].title = "Show Controller"
        actionItems[1].title = model.isPaused ? "Start" : "Pause"
        actionItems[2].title =
            model.overlaySession.visibility == .visible
            ? "Hide Teleprompter" : "Show Teleprompter"
        actionItems[3].title = model.isLocked ? "Unlock" : "Lock"
        actionItems[4].title = "Quit"
        for item in actionItems { item.isEnabled = actionsReady }
    }
}
