import AppKit

final class FreeStatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let statusLabelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var statusDetailItems: [NSMenuItem] = []
    private let statusSeparatorItem = NSMenuItem.separator()
    private let openAppItem = NSMenuItem(title: "Open App", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")
    private let onQuit: () -> Void
    private var onOpenApp: () -> Void = {}
    private var statusButtonProvider: () -> NSStatusBarButton?

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
        statusButtonProvider = { [statusItem] in statusItem.button }
        super.init()

        statusLabelItem.isEnabled = false
        openAppItem.target = self
        openAppItem.action = #selector(handleOpenApp)
        quitItem.target = self
        quitItem.action = #selector(handleQuit)

        statusMenu.addItem(statusLabelItem)
        statusMenu.addItem(statusSeparatorItem)
        statusMenu.addItem(openAppItem)
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
    }

    func update(statusText: String, topBarText: String, isQuitDisabled: Bool, iconColor: NSColor) {
        let statusLines = statusText
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.isEmpty }
        statusLabelItem.title = statusLines.first ?? statusText
        statusDetailItems.forEach { statusMenu.removeItem($0) }
        statusDetailItems.removeAll()
        if statusLines.count > 1 {
            for line in statusLines.dropFirst() {
                let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                item.isEnabled = false
                statusMenu.insertItem(item, at: statusMenu.index(of: statusSeparatorItem))
                statusDetailItems.append(item)
            }
        }
        quitItem.isEnabled = !isQuitDisabled

        guard let button = statusButtonProvider() else { return }
        let image = appKitSymbolImage(spec: AppKitUISymbols.menuBar)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = iconColor
        button.title = topBarText
        button.imagePosition = topBarText.isEmpty ? .imageOnly : .imageLeading
    }

    @objc
    private func handleOpenApp() {
        onOpenApp()
    }

    @objc
    private func handleQuit() {
        onQuit()
    }
}

extension FreeStatusItemController {
    func setOpenAppHandler(_ handler: @escaping () -> Void) {
        onOpenApp = handler
    }

    func setStatusButtonProviderForTesting(_ provider: @escaping () -> NSStatusBarButton?) {
        statusButtonProvider = provider
    }
}
