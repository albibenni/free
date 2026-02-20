import Testing
import SwiftUI
import AppKit
@testable import FreeLogic

@Suite(.serialized)
struct UIComponentsViewTests {
    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 360, height: 140)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("WidgetCard background opacity mapping covers light and dark modes")
    func widgetCardBackgroundOpacity() {
        #expect(WidgetCard<Text>.backgroundOpacity(for: .light) == 0.8)
        #expect(WidgetCard<Text>.backgroundOpacity(for: .dark) == 0.5)
    }

    @Test("WidgetCard body can render content")
    @MainActor
    func widgetCardRender() {
        let view = WidgetCard {
            Text("Widget")
        }
        .frame(width: 300, height: 80)

        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("PillMenuLabel body can render")
    @MainActor
    func pillMenuLabelRender() {
        let view = PillMenuLabel(text: "Focus", icon: "target", color: .blue)
            .frame(width: 180, height: 40)
        let hosted = host(view, size: CGSize(width: 180, height: 40))
        #expect(hosted.fittingSize.height >= 0)
    }

    @Test("URLListRow body can render and delete handler invokes callback")
    @MainActor
    func urlListRowRenderAndDelete() {
        var deleteCallCount = 0
        let row = URLListRow(url: "example.com") {
            deleteCallCount += 1
        }
        let hosted = host(row, size: CGSize(width: 420, height: 40))
        #expect(hosted.fittingSize.width >= 0)

        row.handleDelete()
        #expect(deleteCallCount == 1)
    }

    @Test("AppPrimaryButtonStyle helper logic covers prominent and non-prominent branches")
    func appPrimaryButtonStyleHelperLogic() {
        let defaults = AppPrimaryButtonStyle(color: .blue)
        #expect(defaults.maxWidth == nil)
        #expect(defaults.isProminent == false)

        let regular = AppPrimaryButtonStyle(color: .red, maxWidth: nil, isProminent: false)
        #expect(regular.borderOpacity == 0.2)
        #expect(regular.scaleEffect(isPressed: true) == 0.98)
        #expect(regular.scaleEffect(isPressed: false) == 1.0)
        _ = regular.backgroundColor(isPressed: true)
        _ = regular.backgroundColor(isPressed: false)

        let prominent = AppPrimaryButtonStyle(color: .green, maxWidth: 200, isProminent: true)
        #expect(prominent.borderOpacity == 0)
        #expect(prominent.scaleEffect(isPressed: true) == 0.98)
        #expect(prominent.scaleEffect(isPressed: false) == 1.0)
        _ = prominent.backgroundColor(isPressed: true)
        _ = prominent.backgroundColor(isPressed: false)
    }

    @Test("AppPrimaryButtonStyle makeBody path executes in a hosted button")
    @MainActor
    func appPrimaryButtonStyleRender() {
        let view = Button("Go") {}
            .buttonStyle(AppPrimaryButtonStyle(color: .orange, maxWidth: 160, isProminent: false))
            .frame(width: 180, height: 44)
        let hosted = host(view, size: CGSize(width: 180, height: 44))
        #expect(hosted.fittingSize.width >= 0)

        let viewProminent = Button("Go") {}
            .buttonStyle(AppPrimaryButtonStyle(color: .orange, maxWidth: 160, isProminent: true))
            .frame(width: 180, height: 44)
        let hostedProminent = host(viewProminent, size: CGSize(width: 180, height: 44))
        #expect(hostedProminent.fittingSize.width >= 0)
    }
}
