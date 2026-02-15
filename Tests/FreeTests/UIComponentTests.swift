import Testing
import SwiftUI
import Foundation
@testable import FreeLogic

struct UIComponentTests {
    
    @Test("SheetWrapper initialization and binding")
    func sheetWrapperLogic() {
        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        
        let view = SheetWrapper(title: "Settings", isPresented: binding) {
            Text("Hello")
        }
        
        #expect(view.title == "Settings")
        
        // Verify binding mutation
        view.isPresented = false
        #expect(presented == false)
    }

    @Test("URLListRow property integrity")
    func urlListRowProperties() {
        var deleted = false
        let view = URLListRow(url: "test.com") {
            deleted = true
        }
        
        #expect(view.url == "test.com")
        
        // Verify callback
        view.onDelete()
        #expect(deleted == true)
    }

    @Test("PillMenuLabel property integrity")
    func pillMenuLabelProperties() {
        let view = PillMenuLabel(text: "Test", icon: "star", color: .blue)
        
        #expect(view.text == "Test")
        #expect(view.icon == "star")
        #expect(view.color == .blue)
    }

    @Test("AppPrimaryButtonStyle property integrity")
    func buttonStyleProperties() {
        let style = AppPrimaryButtonStyle(color: .red, maxWidth: 200, isProminent: true)
        
        #expect(style.color == .red)
        #expect(style.maxWidth == 200)
        #expect(style.isProminent == true)
    }
}
