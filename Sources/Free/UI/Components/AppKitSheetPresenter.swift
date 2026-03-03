import AppKit
import SwiftUI

struct AppKitSheetPresenter<SheetContent: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let contentSize: CGSize
    let content: () -> SheetContent

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SheetAnchorNSView {
        let view = SheetAnchorNSView()
        view.onWindowChange = { [weak coordinator = context.coordinator] in
            coordinator?.syncPresentation()
        }
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: SheetAnchorNSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.isPresented = $isPresented
        context.coordinator.contentSize = contentSize
        context.coordinator.makeContent = content
        context.coordinator.syncPresentation()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var anchorView: SheetAnchorNSView?
        var isPresented: Binding<Bool>?
        var contentSize: CGSize = .zero
        var makeContent: (() -> SheetContent)?

        private var sheetWindow: NSWindow?
        private var isDismissingProgrammatically = false

        func syncPresentation() {
            guard let isPresented else { return }
            if isPresented.wrappedValue {
                presentIfNeeded()
            } else {
                dismissIfNeeded()
            }
        }

        private func presentIfNeeded() {
            guard
                sheetWindow == nil,
                let anchorView,
                let parentWindow = anchorView.window,
                let makeContent
            else {
                return
            }

            let hostingController = NSHostingController(rootView: contentView(from: makeContent))
            let sheetWindow = NSWindow(contentViewController: hostingController)
            sheetWindow.delegate = self
            sheetWindow.setContentSize(contentSize)
            sheetWindow.styleMask.insert(.fullSizeContentView)
            sheetWindow.titleVisibility = .hidden
            sheetWindow.titlebarAppearsTransparent = true
            sheetWindow.isReleasedWhenClosed = false
            sheetWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            sheetWindow.standardWindowButton(.zoomButton)?.isHidden = true
            sheetWindow.standardWindowButton(.closeButton)?.isHidden = true

            parentWindow.beginSheet(sheetWindow)
            self.sheetWindow = sheetWindow
        }

        private func dismissIfNeeded() {
            guard let sheetWindow else { return }

            isDismissingProgrammatically = true
            if let parentWindow = sheetWindow.sheetParent {
                parentWindow.endSheet(sheetWindow)
            }
            sheetWindow.orderOut(nil)
            self.sheetWindow = nil
            isDismissingProgrammatically = false
        }

        func windowWillClose(_ notification: Notification) {
            sheetWindow = nil
            guard !isDismissingProgrammatically else { return }
            isPresented?.wrappedValue = false
        }

        private func contentView(from makeContent: () -> SheetContent) -> some View {
            makeContent()
        }
    }
}

final class SheetAnchorNSView: NSView {
    var onWindowChange: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?()
    }
}
