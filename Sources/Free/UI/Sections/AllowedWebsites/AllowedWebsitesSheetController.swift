import AppKit

final class AllowedWebsitesSheetController: NSWindowController, NSWindowDelegate {
    private static let windowTitle = "Allowed Websites"

    private let onClose: () -> Void
    private let editorController: AllowedWebsitesFloatingEditorViewController
    private var isClosingProgrammatically = false
    private let desiredContentSize = CGSize(width: 760, height: 520)

    init(appState: AppState, onClose: @escaping () -> Void) {
        self.onClose = onClose
        editorController = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: appState.activeRuleSetId
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: desiredContentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = editorController
        panel.setContentSize(desiredContentSize)
        panel.contentMinSize = CGSize(width: 620, height: 420)
        panel.minSize = CGSize(width: 620, height: 420)
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true
        panel.title = Self.windowTitle
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: panel)
        panel.delegate = self
        editorController.focusOnRuleSet(appState.activeRuleSetId)
        configureAppKitWindowButton(
            in: panel,
            type: .closeButton,
            controlSize: .large
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(for parentWindow: NSWindow, selectedRuleSetId: UUID?) {
        guard let window else { return }
        editorController.focusOnRuleSet(selectedRuleSetId)
        restoreDesiredContentSize()
        if let panel = window as? NSPanel {
            configureAppKitWindowButton(
                in: panel,
                type: .closeButton,
                controlSize: .large
            )
        }
        if !window.isVisible {
            let origin = NSPoint(
                x: parentWindow.frame.midX - (window.frame.width / 2),
                y: parentWindow.frame.midY - (window.frame.height / 2)
            )
            window.setFrameOrigin(origin)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreDesiredContentSize() {
        guard let window else { return }
        window.contentViewController?.preferredContentSize = desiredContentSize
        window.setContentSize(desiredContentSize)
    }

    func dismiss() {
        guard let window else { return }
        isClosingProgrammatically = true
        window.close()
        isClosingProgrammatically = false
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingProgrammatically else { return }
        onClose()
    }
}
