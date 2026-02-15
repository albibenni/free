import Testing
import Foundation
@testable import FreeLogic

struct RuleSetTests {
    
    @Test("RuleSet default initialization")
    func ruleSetDefaults() {
        let defaultSet = RuleSet.defaultSet()
        #expect(defaultSet.name == "Default")
        #expect(!defaultSet.urls.isEmpty)
    }

    @Test("RuleSet Equatable conformance")
    func ruleSetEquatable() {
        let id = UUID()
        let set1 = RuleSet(id: id, name: "Work", urls: ["google.com"])
        let set2 = RuleSet(id: id, name: "Work", urls: ["google.com"])
        let set3 = RuleSet(id: UUID(), name: "Work", urls: ["google.com"])
        
        #expect(set1 == set2)
        #expect(set1 != set3)
    }

    @Test("RuleSet unique IDs on default init")
    func ruleSetUniqueIds() {
        let set1 = RuleSet(name: "A", urls: [])
        let set2 = RuleSet(name: "B", urls: [])
        #expect(set1.id != set2.id)
    }

    @Test("RuleSet serialization")
    func ruleSetSerialization() throws {
        let original = RuleSet(name: "Deep Work", urls: ["github.com", "notion.so"])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RuleSet.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.urls == original.urls)
    }
}
