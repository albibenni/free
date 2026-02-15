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

    @Test("ExternalEvent serialization")
    func eventSerialization() throws {
        let event = ExternalEvent(
            id: "123",
            title: "Meeting",
            startDate: Date(timeIntervalSince1970: 1000),
            endDate: Date(timeIntervalSince1970: 2000)
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(ExternalEvent.self, from: data)
        
        #expect(decoded.id == "123")
        #expect(decoded.title == "Meeting")
        #expect(decoded.startDate.timeIntervalSince1970 == 1000)
        #expect(decoded.endDate.timeIntervalSince1970 == 2000)
    }

    @Test("Zero duration events")
    func zeroDuration() {
        let now = Date()
        let event = ExternalEvent(id: "z", title: "Instant", startDate: now, endDate: now)
        
        #expect(event.isActive(at: now))
        #expect(!event.isActive(at: now.addingTimeInterval(1)))
    }
}
