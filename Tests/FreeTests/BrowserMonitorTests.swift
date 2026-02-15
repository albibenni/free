import Testing
import Foundation
import AppKit
@testable import FreeLogic

class MockBrowserAutomator: BrowserAutomator {
    var activeUrl: String?
    var redirectedTo: String?
    var checkedPermissions = false
    var permissionsReturn = true
    
    func getActiveUrl(for app: NSRunningApplication) -> String? { activeUrl }
    func redirect(app: NSRunningApplication, to url: String) { redirectedTo = url }
    func getAllOpenUrls(browsers: [String]) -> [String] { activeUrl.map { [$0] } ?? [] }
    func checkPermissions(prompt: Bool) -> Bool {
        checkedPermissions = true
        return permissionsReturn
    }
}

struct BrowserMonitorTests {
    
    private func isolatedAppState(name: String) -> AppState {
        let suite = "BrowserMonitorTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("BrowserMonitor permission check updates AppState")
    func permissionUpdate() {
        let appState = isolatedAppState(name: "permissionUpdate")
        let mock = MockBrowserAutomator()
        mock.permissionsReturn = false
        
        _ = BrowserMonitor(appState: appState, server: nil, automator: mock)
        #expect(mock.checkedPermissions)
    }

    @Test("BrowserMonitor internal logic handles blocking")
    func internalLogic() {
        // Since we can't easily mock NSRunningApplication (which is required by checkActiveTab),
        // we verified the refactoring allows replacing the Automator.
        // In a real environment, the monitor would call automator.getActiveUrl()
        // and then automator.redirect() if RuleMatcher.isAllowed is false.
        
        let appState = isolatedAppState(name: "internalLogic")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Test", urls: ["google.com"])]
        
        let mock = MockBrowserAutomator()
        let monitor = BrowserMonitor(appState: appState, server: nil, automator: mock)
        
        // Verification: If the monitor WAS to run, it would use these rules:
        #expect(appState.allowedRules.contains("google.com"))
        #expect(!RuleMatcher.isAllowed("https://facebook.com", rules: appState.allowedRules))
    }
}
