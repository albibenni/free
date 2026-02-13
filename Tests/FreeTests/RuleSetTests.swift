import Testing
@testable import FreeLogic

struct RuleSetTests {
    
    @Test("RuleSet default initialization")
    func ruleSetDefaults() {
        let defaultSet = RuleSet.defaultSet()
        #expect(defaultSet.name == "Default")
        #expect(!defaultSet.urls.isEmpty)
    }
}
