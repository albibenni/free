import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct PersistenceTests {

    @Test("Schedule serialization and deserialization")
    func schedulePersistence() async throws {
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
    func ruleSetPersistence() async throws {
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

    @Test("AppState correctly persists settings to UserDefaults")
    func appStatePersistence() async throws {
        let testSuite = "com.free.test.persistence"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        let defaults = UserDefaults(suiteName: testSuite)!

        var appState: AppState? = AppState(defaults: defaults, isTesting: true)
        appState?.toggleBlocking()
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(false, forKey: "WasStartedBySchedule")
        defaults.set(true, forKey: "ManualBlockingEnabled")
        appState?.isStrict = true
        appState?.accentColorIndex = 5
        appState?.blockNewTabs = true
        appState?.blockDeveloperHosts = true
        appState?.blockLocalNetworkHosts = true
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        appState = nil

        let newAppState = AppState(defaults: defaults, isTesting: true)
        #expect(newAppState.isBlocking == true)
        #expect(newAppState.isStrict == true)
        #expect(newAppState.accentColorIndex == 5)
        #expect(newAppState.blockNewTabs == true)
        #expect(newAppState.blockDeveloperHosts == true)
        #expect(newAppState.blockLocalNetworkHosts == true)

        UserDefaults.standard.removePersistentDomain(forName: testSuite)
    }

    @Test("AppState rule management persists changes")
    func appStateRuleManagement() async throws {
        let testSuite = "com.free.test.rules"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        let defaults = UserDefaults(suiteName: testSuite)!

        let appState = AppState(defaults: defaults, isTesting: true)
        let setId = appState.ruleSets[0].id

        appState.addRule("test.com", to: setId)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(appState.ruleSets[0].urls.contains("test.com"))

        let newAppState = AppState(defaults: defaults, isTesting: true)
        #expect(newAppState.ruleSets[0].urls.contains("test.com"))

        appState.removeRule("test.com", from: setId)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(!appState.ruleSets[0].urls.contains("test.com"))

        UserDefaults.standard.removePersistentDomain(forName: testSuite)
    }
}
