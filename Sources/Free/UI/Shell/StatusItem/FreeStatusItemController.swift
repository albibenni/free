import AppKit

final class FreeStatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let statusLabelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")
    private let onQuit: () -> Void
    private var statusButtonProvider: () -> NSStatusBarButton?

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
        statusButtonProvider = { [statusItem] in statusItem.button }
        super.init()

        statusLabelItem.isEnabled = false
        quitItem.target = self
        quitItem.action = #selector(handleQuit)

        statusMenu.addItem(statusLabelItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
    }

    func update(statusText: String, isQuitDisabled: Bool, iconColor: NSColor) {
        statusLabelItem.title = statusText
        quitItem.isEnabled = !isQuitDisabled

        guard let button = statusButtonProvider() else { return }
        let image = appKitSymbolImage(spec: AppKitUISymbols.menuBar)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = iconColor
    }

    @objc
    private func handleQuit() {
        onQuit()
    }
}

extension FreeStatusItemController {
    func setStatusButtonProviderForTesting(_ provider: @escaping () -> NSStatusBarButton?) {
        statusButtonProvider = provider
    }
}
