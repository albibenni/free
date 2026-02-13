import Testing
import Foundation
@testable import FreeLogic

struct PersistenceTests {
    
    @Test("Schedule serialization and deserialization")
    func schedulePersistence() throws {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        
        let original = Schedule(
            id: UUID(),
            name: "Work Session",
            days: [2, 3, 4],
            startTime: start,
            endTime: end,
            isEnabled: true,
            colorIndex: 2,
            type: .focus,
            ruleSetId: UUID()
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Schedule.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.days == original.days)
        #expect(decoded.type == original.type)
        #expect(decoded.ruleSetId == original.ruleSetId)
    }
    
    @Test("RuleSet serialization and deserialization")
    func ruleSetPersistence() throws {
        let original = RuleSet(
            id: UUID(),
            name: "Deep Work",
            urls: ["github.com", "stackoverlow.com"]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RuleSet.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.urls == original.urls)
    }
}
