import XCTest
@testable import FreeLogic

final class RuleSetTests: XCTestCase {
    
    // Since RuleSet is a simple struct, we mostly test its creation and Equatable conformance if needed,
    // but the main logic is likely in AppState or BrowserMonitor which uses the rules.
    // However, we can test the `isAllowed` logic if we extract it or test BrowserMonitor.
    // `BrowserMonitor` has `isAllowed`.
    
    // For now, let's assume we can instantiate BrowserMonitor or extract the logic.
    // Ideally, `isAllowed` should be a static method or part of a RuleMatching logic struct.
    // But it's currently an instance method on BrowserMonitor.
    
    // Let's create a test that verifies RuleSet struct integrity.
    
    func testRuleSetDefaults() {
        let defaultSet = RuleSet.defaultSet()
        XCTAssertEqual(defaultSet.name, "Default")
        XCTAssertFalse(defaultSet.urls.isEmpty)
    }
}
