import Foundation
import Testing

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

    @Test("AppState correctly persists settings to UserDefaults")
    func appStatePersistence() {
        let testSuite = "com.free.test.persistence"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        let defaults = UserDefaults(suiteName: testSuite)!

        var appState: AppState? = AppState(defaults: defaults, isTesting: true)
        appState?.isBlocking = true
        defaults.set(false, forKey: "WasStartedBySchedule")
        appState?.isUnblockable = true
        appState?.accentColorIndex = 5
        appState?.blockNewTabs = true
        appState = nil

        let newAppState = AppState(defaults: defaults, isTesting: true)
        #expect(newAppState.isBlocking == true)
        #expect(newAppState.isUnblockable == true)
        #expect(newAppState.accentColorIndex == 5)
        #expect(newAppState.blockNewTabs == true)

        UserDefaults.standard.removePersistentDomain(forName: testSuite)
    }

    @Test("AppState rule management persists changes")
    func appStateRuleManagement() {
        let testSuite = "com.free.test.rules"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        let defaults = UserDefaults(suiteName: testSuite)!

        let appState = AppState(defaults: defaults, isTesting: true)
        let setId = appState.ruleSets[0].id

        appState.addRule("test.com", to: setId)
        #expect(appState.ruleSets[0].urls.contains("test.com"))

        let newAppState = AppState(defaults: defaults, isTesting: true)
        #expect(newAppState.ruleSets[0].urls.contains("test.com"))

        appState.removeRule("test.com", from: setId)
        #expect(!appState.ruleSets[0].urls.contains("test.com"))

        UserDefaults.standard.removePersistentDomain(forName: testSuite)
    }
}
