import Testing
import SwiftUI
import AppKit
@testable import FreeLogic

@Suite(.serialized)
struct SheetWrapperTests {
    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 420, height: 220)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("SheetWrapper renders header and content")
    @MainActor
    func renderSheetWrapper() {
        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let view = SheetWrapper(title: "Settings", isPresented: binding) {
            Text("Hello")
        }
        let hosted = host(view)

        #expect(hosted.fittingSize.width >= 0)
        #expect(view.title == "Settings")
        #expect(isPresented == true)
    }

    @Test("SheetWrapper dismissSheet updates the presentation binding")
    func dismissSheetAction() {
        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let view = SheetWrapper(title: "Settings", isPresented: binding) {
            VStack {
                Text("Advanced")
                Divider()
            }
        }
        view.dismissSheet()
        #expect(isPresented == false)
    }
}
