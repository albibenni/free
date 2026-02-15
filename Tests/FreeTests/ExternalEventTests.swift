import Testing
import Foundation
@testable import FreeLogic

struct ExternalEventTests {
    
    @Test("ExternalEvent isActive logic")
    func eventActive() {
        let now = Date()
        let event = ExternalEvent(
            id: "test",
            title: "Meeting",
            startDate: now.addingTimeInterval(-300), // 5m ago
            endDate: now.addingTimeInterval(300)    // 5m from now
        )
        
        #expect(event.isActive(at: now))
        #expect(event.isActive(at: now.addingTimeInterval(-300)))
        #expect(event.isActive(at: now.addingTimeInterval(300)))
        #expect(!event.isActive(at: now.addingTimeInterval(-301)))
        #expect(!event.isActive(at: now.addingTimeInterval(301)))
    }
}
