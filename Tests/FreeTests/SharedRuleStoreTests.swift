import Testing
import Foundation

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct SharedRuleStoreTests {
    private func clearSharedStore() {
        UserDefaults(suiteName: SharedRuleStore.appGroupID)?
            .removePersistentDomain(forName: SharedRuleStore.appGroupID)
    }

    private func isolatedAppState(name: String, startBrowserMonitor: Bool) -> AppState {
        let suite = "SharedRuleStoreTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true, startBrowserMonitor: startBrowserMonitor)
    }

    @Test("publish then snapshot round-trips the blocking flag and rules")
    func roundTrip() {
        clearSharedStore()
        defer { clearSharedStore() }

        SharedRuleStore.publish(isBlocking: true, allowedRules: ["example.com", "*.docs.com"])
        let snapshot = SharedRuleStore.snapshot()

        #expect(snapshot.isBlocking == true)
        #expect(snapshot.allowedRules == ["example.com", "*.docs.com"])
    }

    @Test("v2 AppState publishes effective blocking; pause counts as not blocking")
    func v2Publishes() {
        clearSharedStore()
        defer { clearSharedStore() }

        let appState = isolatedAppState(name: "v2Publishes", startBrowserMonitor: false)
        appState.isBlocking = true
        #expect(SharedRuleStore.snapshot().isBlocking == true)

        appState.isPaused = true
        #expect(SharedRuleStore.snapshot().isBlocking == false)
    }

    @Test("v1 AppState leaves the shared store untouched")
    func v1DoesNotPublish() {
        clearSharedStore()
        defer { clearSharedStore() }

        // Seed a known state; the v1 app state must not overwrite it.
        SharedRuleStore.publish(isBlocking: false, allowedRules: [])
        let appState = isolatedAppState(name: "v1DoesNotPublish", startBrowserMonitor: true)
        appState.isBlocking = true

        #expect(SharedRuleStore.snapshot().isBlocking == false)
    }
}
