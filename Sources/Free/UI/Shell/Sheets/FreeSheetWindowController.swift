import AppKit

final class FreeSheetWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void
    private let desiredContentSize: CGSize
    private var isClosingProgrammatically = false
    private let showsNativeCloseButton: Bool
    private let nativeCloseButtonSize: CGFloat?
    private let nativeCloseButtonXOffset: CGFloat
    private let presentsAsSheet: Bool

    init(
        contentViewController: NSViewController,
        contentSize: CGSize,
        presentsAsSheet: Bool = true,
        showsNativeCloseButton: Bool = false,
        nativeCloseButtonSize: CGFloat? = nil,
        nativeCloseButtonXOffset: CGFloat = 0,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        desiredContentSize = contentSize
        self.presentsAsSheet = presentsAsSheet
        self.showsNativeCloseButton = showsNativeCloseButton
        self.nativeCloseButtonSize = nativeCloseButtonSize
        self.nativeCloseButtonXOffset = nativeCloseButtonXOffset
        contentViewController.preferredContentSize = contentSize

        let window: NSWindow
        if presentsAsSheet {
            window = NSWindow(contentViewController: contentViewController)
        } else {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = contentViewController
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            window = panel
        }
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.minSize = contentSize
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.titleVisibility = presentsAsSheet ? .hidden : .visible
        window.titlebarAppearsTransparent = presentsAsSheet
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = !showsNativeCloseButton

        super.init(window: window)
        window.delegate = self
        if showsNativeCloseButton {
            configureAppKitWindowButton(
                in: window,
                type: .closeButton,
                controlSize: .large,
                targetSize: nativeCloseButtonSize,
                xOffset: nativeCloseButtonXOffset
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(for parentWindow: NSWindow) {
        guard let window else { return }
        if showsNativeCloseButton {
            configureAppKitWindowButton(
                in: window,
                type: .closeButton,
                controlSize: .large,
                targetSize: nativeCloseButtonSize,
                xOffset: nativeCloseButtonXOffset
            )
        }
        restoreDesiredContentSize()
        if presentsAsSheet {
            parentWindow.beginSheet(window)
            restoreDesiredContentSize()
            return
        }
        if !window.isVisible {
            let origin = NSPoint(
                x: parentWindow.frame.midX - (window.frame.width / 2),
                y: parentWindow.frame.midY - (window.frame.height / 2)
            )
            window.setFrameOrigin(origin)
        }
        if window.parent !== parentWindow {
            parentWindow.addChildWindow(window, ordered: .above)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func restoreDesiredContentSize() {
        guard let window else { return }
        window.contentViewController?.preferredContentSize = desiredContentSize
        window.setContentSize(desiredContentSize)
        window.contentMinSize = desiredContentSize
        window.minSize = desiredContentSize
        let frameRect = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: desiredContentSize)
        )
        reconcileWindowFrameIfNeeded(window, targetFrameRect: frameRect)
        window.layoutIfNeeded()
    }

    func dismiss() {
        guard let window else { return }
        isClosingProgrammatically = true
        if presentsAsSheet {
            if let parentWindow = window.sheetParent {
                parentWindow.endSheet(window)
            }
        } else if let parentWindow = window.parent {
            parentWindow.removeChildWindow(window)
        }
        window.orderOut(nil)
        isClosingProgrammatically = false
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingProgrammatically else { return }
        onClose()
    }

    private func reconcileWindowFrameIfNeeded(
        _ window: NSWindow,
        targetFrameRect: NSRect
    ) {
        if abs(window.frame.width - targetFrameRect.width) > 0.5
            || abs(window.frame.height - targetFrameRect.height) > 0.5
        {
            window.setFrame(
                NSRect(origin: window.frame.origin, size: targetFrameRect.size),
                display: true
            )
        }
    }
}

extension FreeSheetWindowController {
    func reconcileWindowFrameForTesting() {
        guard let window else { return }
        let target = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: desiredContentSize)
        )
        reconcileWindowFrameIfNeeded(window, targetFrameRect: target)
    }

    func setClosingProgrammaticallyForTesting(_ value: Bool) {
        isClosingProgrammatically = value
    }
}
