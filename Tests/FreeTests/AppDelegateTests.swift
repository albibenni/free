import Testing
import Foundation
import AppKit
@testable import FreeLogic

struct AppDelegateTests {
    
    @Test("AppDelegate prevents termination when blocking is active")
    func terminationPrevention() {
        let suite = "AppDelegateTests.termination"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        
        let delegate = AppDelegate()
        delegate.defaults = defaults
        
        // 1. Blocking OFF
        defaults.set(false, forKey: "IsBlocking")
        #expect(delegate.shouldPreventTermination() == false)
        
        // 2. Blocking ON
        defaults.set(true, forKey: "IsBlocking")
        #expect(delegate.shouldPreventTermination() == true)
        
        defaults.removePersistentDomain(forName: suite)
    }
}
