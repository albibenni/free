import Testing
import Foundation
@testable import FreeLogic

struct DataIntegrityTests {
    
    @Test("AppState recovers from corrupted RuleSets JSON")
    func corruptedRuleSets() {
        let suite = "DataIntegrityTests.corruptedRuleSets"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        
        // Write invalid data
        defaults.set("not-json".data(using: .utf8), forKey: "RuleSets")
        
        let appState = AppState(defaults: defaults, isTesting: true)
        
        // Should fallback to default set
        #expect(!appState.ruleSets.isEmpty)
        #expect(appState.ruleSets.first?.name == "Default")
    }

    @Test("AppState recovers from missing activeRuleSetId")
    func missingActiveSet() {
        let suite = "DataIntegrityTests.missingActiveSet"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        
        // Setup state with rule sets but NO active ID
        let ruleSet = RuleSet(name: "T", urls: [])
        if let encoded = try? JSONEncoder().encode([ruleSet]) {
            defaults.set(encoded, forKey: "RuleSets")
        }
        
        let appState = AppState(defaults: defaults, isTesting: true)
        
        // Should fallback to first set ID
        #expect(appState.activeRuleSetId == ruleSet.id)
    }

    @Test("AppState recovers from corrupted Schedules JSON")
    func corruptedSchedules() {
        let suite = "DataIntegrityTests.corruptedSchedules"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        
        // Write invalid data
        defaults.set("bad-data".data(using: .utf8), forKey: "Schedules")
        
        let appState = AppState(defaults: defaults, isTesting: true)
        
        // Should fallback to empty array
        #expect(appState.schedules.isEmpty)
    }
}
