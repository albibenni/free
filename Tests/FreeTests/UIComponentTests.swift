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
}
