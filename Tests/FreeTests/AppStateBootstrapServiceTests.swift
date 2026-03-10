import Foundation
import Testing

@testable import FreeLogic

struct AppStateBootstrapServiceTests {
    @Test("snapshot falls back to defaults when persisted values are missing")
    func snapshotDefaults() {
        let suite = "AppStateBootstrapServiceTests.snapshotDefaults"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)

        let snapshot = AppStateBootstrapService.snapshot(from: store)

        #expect(snapshot.appearanceMode == .system)
        #expect(snapshot.pomodoroFocusDuration == 25)
        #expect(snapshot.pomodoroBreakDuration == 5)
        #expect(snapshot.ruleSets.count == 1)
        #expect(snapshot.ruleSets.first?.name == RuleSet.defaultSet().name)
        #expect(snapshot.ruleSets.first?.urls == RuleSet.defaultSet().urls)
        #expect(snapshot.activeRuleSetId == snapshot.ruleSets.first?.id)
    }

    @Test("snapshot normalizes invalid appearance while preserving persisted rule selection")
    func snapshotInvalidAppearanceFallback() {
        let suite = "AppStateBootstrapServiceTests.snapshotInvalidAppearanceFallback"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let set = RuleSet(name: "Set A", urls: ["example.com"])
        let store = SettingsStore(defaults: defaults)
        store.saveRuleSets([set])
        store.setActiveRuleSetId(set.id)
        store.setAppearanceModeRawValue("INVALID")

        let snapshot = AppStateBootstrapService.snapshot(from: store)

        #expect(snapshot.appearanceMode == .system)
        #expect(snapshot.ruleSets == [set])
        #expect(snapshot.activeRuleSetId == set.id)
    }

    @Test("snapshot prunes one-off schedules older than previous week")
    func snapshotPrunesStaleOneOffSchedules() {
        let suite = "AppStateBootstrapServiceTests.snapshotPrunesStaleOneOffSchedules"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(defaults: defaults)
        let now = Date()
        let staleDate = now.addingTimeInterval(-21 * 24 * 60 * 60)
        let recentDate = now.addingTimeInterval(-2 * 24 * 60 * 60)

        let staleOneOff = Schedule(
            name: "Old one-off",
            days: [Calendar.current.component(.weekday, from: staleDate)],
            date: staleDate,
            startTime: staleDate,
            endTime: staleDate.addingTimeInterval(1800),
            type: .focus
        )
        let recentOneOff = Schedule(
            name: "Recent one-off",
            days: [Calendar.current.component(.weekday, from: recentDate)],
            date: recentDate,
            startTime: recentDate,
            endTime: recentDate.addingTimeInterval(1800),
            type: .focus
        )
        let recurring = Schedule(
            name: "Recurring",
            days: [2],
            date: nil,
            startTime: now,
            endTime: now.addingTimeInterval(1800),
            type: .focus
        )

        store.saveSchedules([staleOneOff, recentOneOff, recurring])

        let snapshot = AppStateBootstrapService.snapshot(from: store)

        #expect(snapshot.schedules.contains(where: { $0.id == staleOneOff.id }) == false)
        #expect(snapshot.schedules.contains(where: { $0.id == recentOneOff.id }))
        #expect(snapshot.schedules.contains(where: { $0.id == recurring.id }))
    }
}
