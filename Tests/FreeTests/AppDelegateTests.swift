import Testing
import Foundation
import AppKit
@testable import FreeLogic

struct AppDelegateTests {
    
    private func setupIsolatedDelegate(name: String) -> (AppDelegate, UserDefaults) {
        let suite = "AppDelegateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let delegate = AppDelegate()
        delegate.defaults = defaults
        return (delegate, defaults)
    }

    @Test("AppDelegate prevents termination when blocking is active")
    func terminationPrevention() {
        let (delegate, defaults) = setupIsolatedDelegate(name: "terminationPrevention")
        
        // 1. Blocking OFF
        defaults.set(false, forKey: "IsBlocking")
        #expect(delegate.shouldPreventTermination() == false)
        
        // 2. Blocking ON
        defaults.set(true, forKey: "IsBlocking")
        #expect(delegate.shouldPreventTermination() == true)
    }

    @Test("applicationShouldTerminate returns correct reply and triggers alert")
    func applicationTerminationReply() {
        let (delegate, defaults) = setupIsolatedDelegate(name: "applicationTerminationReply")
        
        var alertWasShown = false
        delegate.onShowAlert = { alertWasShown = true }
        
        // 1. Case: Blocking Active
        defaults.set(true, forKey: "IsBlocking")
        let reply1 = delegate.applicationShouldTerminate(NSApplication.shared)
        #expect(reply1 == .terminateCancel)
        #expect(alertWasShown == true)
        
        // 2. Case: Blocking Inactive
        alertWasShown = false
        defaults.set(false, forKey: "IsBlocking")
        let reply2 = delegate.applicationShouldTerminate(NSApplication.shared)
        #expect(reply2 == .terminateNow)
        #expect(alertWasShown == false)
    }
}
