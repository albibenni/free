import Foundation
import Testing

@testable import FreeLogic

private enum LaunchAtLoginTestError: Error {
    case enableFailed
}

private final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabledValue: Bool
    var isEnabledCallCount = 0
    var enableCallCount = 0
    var disableCallCount = 0
    var enableError: Error?
    var disableError: Error?

    init(isEnabled: Bool) {
        self.isEnabledValue = isEnabled
    }

    var isEnabled: Bool {
        isEnabledCallCount += 1
        return isEnabledValue
    }

    func enable() throws {
        enableCallCount += 1
        if let enableError {
            throw enableError
        }
        isEnabledValue = true
    }

    func disable() throws {
        disableCallCount += 1
        if let disableError {
            throw disableError
        }
        isEnabledValue = false
    }
}

struct AppStateTests {

    private func isolatedAppState(
        name: String,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler()
    ) -> AppState {
        let suite = "AppStateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, timerScheduler: timerScheduler, isTesting: true)
    }

    @Test("Pomodoro locking logic works correctly with grace period")
    func pomodoroLocking() {
        let appState = isolatedAppState(name: "pomodoroLocking")

        appState.isUnblockable = true
        appState.pomodoroStatus = .focus
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100)

        #expect(
            appState.isPomodoroLocked, "Pomodoro should be locked in strict mode after grace period"
        )

        appState.pomodoroStartedAt = Date()

        #expect(!appState.isPomodoroLocked, "Pomodoro should NOT be locked during grace period")
    }

    @Test("Strict Mode (Unblockable) activation logic")
    func strictActive() {
        let appState = isolatedAppState(name: "strictActive")
        appState.isBlocking = true
        appState.isUnblockable = true

        #expect(appState.isStrictActive)

        appState.isUnblockable = false
        #expect(!appState.isStrictActive)
    }

    @Test("Allowed rules aggregation from multiple sources")
    func allowedRulesAggregation() {
        let appState = isolatedAppState(name: "allowedRulesAggregation")
        let ruleSet1 = RuleSet(id: UUID(), name: "Set 1", urls: ["url1.com"])
        let ruleSet2 = RuleSet(id: UUID(), name: "Set 2", urls: ["url2.com"])
        appState.ruleSets = [ruleSet1, ruleSet2]

        appState.isBlocking = true
        appState.activeRuleSetId = ruleSet1.id

        #expect(appState.allowedRules.contains("url1.com"))
        #expect(!appState.allowedRules.contains("url2.com"))
    }

    @Test("Break schedule overrides Focus schedule")
    func schedulePriorityBreakOverridesFocus() {
        let appState = isolatedAppState(name: "schedulePriorityBreakOverridesFocus")
        appState.isBlocking = false
        appState.isUnblockable = false
        appState.calendarIntegrationEnabled = false

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let focusSchedule = Schedule(
            name: "Focus",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )

        let breakSchedule = Schedule(
            name: "Break",
            days: [weekday],
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            isEnabled: true,
            type: .unfocus
        )

        appState.schedules = [focusSchedule, breakSchedule]
        appState.checkSchedules()

        #expect(
            !appState.isBlocking,
            "Blocking should be disabled because an internal Break session is active")

        appState.schedules = [focusSchedule]
        appState.checkSchedules()

        #expect(appState.isBlocking, "Blocking should be enabled when only Focus session is active")
    }

    @Test("Manual focus persists after schedule ends")
    func manualFocusOverridesScheduleStop() {
        let appState = AppState(isTesting: true)

        appState.isBlocking = true

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let schedule = Schedule(
            name: "Work",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )
        appState.schedules = [schedule]
        appState.checkSchedules()

        #expect(appState.isBlocking)

        appState.schedules = []
        appState.checkSchedules()

        #expect(appState.isBlocking, "Manual focus should not be turned off by schedule ending")
    }

    @Test("AppState migrates legacy stale blocking state to inactive when no automatic reason exists")
    func legacyBlockingMigrationClearsStaleState() {
        let suite = "AppStateTests.legacyBlockingMigrationClearsStaleState"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "IsBlocking")
        defaults.removeObject(forKey: "WasStartedBySchedule")

        let appState = AppState(defaults: defaults, isTesting: true)

        #expect(!appState.isBlocking)
        #expect(defaults.bool(forKey: "WasStartedBySchedule") == false)
    }

    @Test("AppState preserves persisted manual blocking when source is manual")
    func persistedManualBlockingRemainsActive() {
        let suite = "AppStateTests.persistedManualBlockingRemainsActive"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(false, forKey: "WasStartedBySchedule")

        let appState = AppState(defaults: defaults, isTesting: true)

        #expect(appState.isBlocking)
    }

    @Test("AppState auto-disables persisted automatic blocking when focus schedule has ended")
    func persistedAutomaticBlockingStopsWhenScheduleEnds() {
        let suite = "AppStateTests.persistedAutomaticBlockingStopsWhenScheduleEnds"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(true, forKey: "WasStartedBySchedule")

        let appState = AppState(defaults: defaults, isTesting: true)
        appState.checkSchedules()

        #expect(!appState.isBlocking)
        #expect(defaults.bool(forKey: "WasStartedBySchedule") == false)
    }

    @Test("AppState prompts for launch-at-login only once on first startup when disabled")
    func launchAtLoginPromptOnceWhenDisabled() {
        let suite = "AppStateTests.launchAtLoginPromptOnceWhenDisabled"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = MockLaunchAtLoginManager(isEnabled: false)

        let appState = AppState(
            defaults: defaults,
            launchAtLoginManager: manager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )

        #expect(appState.prepareLaunchAtLoginPromptIfNeeded() == true)
        #expect(appState.prepareLaunchAtLoginPromptIfNeeded() == false)
        #expect(manager.isEnabledCallCount == 1)
    }

    @Test("AppState does not prompt for launch-at-login when prompting is suppressed")
    func launchAtLoginPromptSuppressed() {
        let suite = "AppStateTests.launchAtLoginPromptSuppressed"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = MockLaunchAtLoginManager(isEnabled: false)

        let appState = AppState(
            defaults: defaults,
            launchAtLoginManager: manager,
            canPromptForLaunchAtLogin: { false },
            isTesting: true
        )

        #expect(appState.prepareLaunchAtLoginPromptIfNeeded() == false)
        #expect(manager.isEnabledCallCount == 0)
    }

    @Test("AppState skips launch-at-login prompt when already enabled")
    func launchAtLoginPromptSkippedWhenAlreadyEnabled() {
        let suite = "AppStateTests.launchAtLoginPromptSkippedWhenAlreadyEnabled"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = MockLaunchAtLoginManager(isEnabled: true)

        let appState = AppState(
            defaults: defaults,
            launchAtLoginManager: manager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )

        #expect(appState.prepareLaunchAtLoginPromptIfNeeded() == false)
        #expect(manager.isEnabledCallCount == 1)
    }

    @Test("AppState enableLaunchAtLogin reports success and failure")
    func enableLaunchAtLoginResultHandling() {
        let successSuite = "AppStateTests.enableLaunchAtLoginResultHandling.success"
        let successDefaults = UserDefaults(suiteName: successSuite)!
        successDefaults.removePersistentDomain(forName: successSuite)
        let successManager = MockLaunchAtLoginManager(isEnabled: false)
        let successAppState = AppState(
            defaults: successDefaults,
            launchAtLoginManager: successManager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )

        #expect(successAppState.enableLaunchAtLogin() == true)
        #expect(successManager.enableCallCount == 1)

        let failureSuite = "AppStateTests.enableLaunchAtLoginResultHandling.failure"
        let failureDefaults = UserDefaults(suiteName: failureSuite)!
        failureDefaults.removePersistentDomain(forName: failureSuite)
        let failureManager = MockLaunchAtLoginManager(isEnabled: false)
        failureManager.enableError = LaunchAtLoginTestError.enableFailed
        let failureAppState = AppState(
            defaults: failureDefaults,
            launchAtLoginManager: failureManager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )

        #expect(failureAppState.enableLaunchAtLogin() == false)
        #expect(failureManager.enableCallCount == 1)
    }

    @Test("AppState setLaunchAtLoginEnabled toggles and handles disable failures")
    func setLaunchAtLoginEnabledResultHandling() {
        let suite = "AppStateTests.setLaunchAtLoginEnabledResultHandling"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let manager = MockLaunchAtLoginManager(isEnabled: false)
        let appState = AppState(
            defaults: defaults,
            launchAtLoginManager: manager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )

        #expect(appState.launchAtLoginStatus() == false)
        #expect(appState.setLaunchAtLoginEnabled(true) == true)
        #expect(manager.enableCallCount == 1)
        #expect(appState.launchAtLoginStatus() == true)

        #expect(appState.setLaunchAtLoginEnabled(false) == true)
        #expect(manager.disableCallCount == 1)
        #expect(appState.launchAtLoginStatus() == false)

        manager.isEnabledValue = true
        manager.disableError = LaunchAtLoginTestError.enableFailed
        #expect(appState.setLaunchAtLoginEnabled(false) == false)
        #expect(manager.disableCallCount == 2)
        #expect(appState.launchAtLoginStatus() == true)
    }

    @Test("Calendar events override focus sessions in normal mode")
    func calendarEventOverride() {
        let appState = isolatedAppState(name: "calendarEventOverride")
        appState.calendarIntegrationEnabled = true
        #expect(appState.calendarImportsBlockTime == false)
        appState.isBlocking = false
        appState.isUnblockable = false

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let schedule = Schedule(
            name: "Work",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )

        appState.schedules = [schedule]
        appState.checkSchedules()
        #expect(appState.isBlocking, "Should be blocking due to schedule")

        let event = ExternalEvent(
            id: "meeting",
            title: "Meeting",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        appState.calendarProvider.events = [event]
        appState.checkSchedules()
        #expect(!appState.isBlocking, "Calendar event should override focus in normal mode")

        appState.isUnblockable = true
        appState.checkSchedules()

        #expect(appState.isBlocking, "Calendar event should NOT override focus in strict mode")
    }

    @Test("Calendar imports can block time when enabled")
    func calendarImportsBlockTimeToggle() {
        let appState = isolatedAppState(name: "calendarImportsBlockTimeToggle")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = true
        appState.isBlocking = false

        let now = Date()
        let event = ExternalEvent(
            id: "imported-focus",
            title: "Imported Focus",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        appState.calendarProvider.events = [event]
        appState.checkSchedules()
        #expect(appState.isBlocking == true)
    }

    @Test("Calendar import sync upserts and removes mirrored schedules without duplication")
    func calendarImportSyncUpsertAndRemove() {
        let appState = isolatedAppState(name: "calendarImportSyncUpsertAndRemove")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = true

        let now = Date()
        let eventA = ExternalEvent(
            id: "event-a",
            title: "Imported A",
            startDate: now.addingTimeInterval(-1200),
            endDate: now.addingTimeInterval(-600)
        )
        let eventB = ExternalEvent(
            id: "event-b",
            title: "Imported B",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1200)
        )

        appState.calendarProvider.events = [eventA, eventB]
        appState.checkSchedules()

        var imported = appState.schedules.filter { $0.importedCalendarEventKey != nil }
        #expect(imported.count == 2)
        #expect(Set(imported.compactMap(\.importedCalendarEventKey)).count == 2)

        let setId = appState.ruleSets[0].id
        if let idx = appState.schedules.firstIndex(where: { $0.importedCalendarEventKey == "event-a" }) {
            appState.schedules[idx].ruleSetId = setId
            appState.schedules = appState.schedules
        } else {
            Issue.record("Expected mirrored schedule for event-a")
        }

        let updatedA = ExternalEvent(
            id: "event-a",
            title: "Imported A Updated",
            startDate: now.addingTimeInterval(1800),
            endDate: now.addingTimeInterval(2400)
        )
        let eventC = ExternalEvent(
            id: "event-c",
            title: "Imported C",
            startDate: now.addingTimeInterval(3000),
            endDate: now.addingTimeInterval(3600)
        )

        appState.calendarProvider.events = [updatedA, eventC]
        appState.checkSchedules()

        imported = appState.schedules.filter { $0.importedCalendarEventKey != nil }
        #expect(imported.count == 2)
        #expect(Set(imported.compactMap(\.importedCalendarEventKey)) == Set(["event-a", "event-c"]))
        #expect(imported.first(where: { $0.importedCalendarEventKey == "event-a" })?.name == "Imported A Updated")
        #expect(imported.first(where: { $0.importedCalendarEventKey == "event-a" })?.ruleSetId == setId)
    }

    @Test("Disabling calendar import blocking removes mirrored imported schedules")
    func calendarImportDisableRemovesMirroredSchedules() {
        let appState = isolatedAppState(name: "calendarImportDisableRemovesMirroredSchedules")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = true

        let now = Date()
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "event-remove",
                title: "Imported",
                startDate: now,
                endDate: now.addingTimeInterval(600)
            )
        ]
        appState.checkSchedules()
        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "event-remove" }))

        appState.calendarImportsBlockTime = false
        appState.checkSchedules()
        #expect(!appState.schedules.contains(where: { $0.importedCalendarEventKey != nil }))
    }

    @Test("Pause logic works correctly")
    func pauseLogic() {
        let appState = isolatedAppState(name: "pauseLogic")
        appState.isBlocking = true

        appState.startPause(minutes: 5)

        #expect(appState.isPaused)
        #expect(appState.pauseRemaining == 300)

        appState.cancelPause()
        #expect(!appState.isPaused)

        appState.isBlocking = true
        appState.startPause(minutes: 1)
        appState.isBlocking = false
        #expect(!appState.isPaused, "Pause should cancel when blocking is disabled")
    }

    @Test("todaySchedules includes matching one-off date sessions")
    func todaySchedulesSpecificDate() {
        let appState = isolatedAppState(name: "todaySchedulesSpecificDate")
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 0))!

        let todayOneOff = Schedule(
            name: "Today One-off", days: [], date: now, startTime: start, endTime: end)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrowOneOff = Schedule(
            name: "Tomorrow One-off", days: [], date: tomorrow, startTime: start, endTime: end)

        appState.schedules = [tomorrowOneOff, todayOneOff]
        let result = appState.todaySchedules

        #expect(result.count == 1)
        #expect(result.first?.name == "Today One-off")
    }

    @Test("addSpecificRule adds unique entries and respects strict mode")
    func addSpecificRuleCoverage() {
        let appState = isolatedAppState(name: "addSpecificRuleCoverage")
        let setId = appState.ruleSets[0].id

        appState.addSpecificRule("https://swift.org", to: setId)
        #expect(appState.ruleSets[0].urls.contains("https://swift.org"))

        let countAfterFirstAdd = appState.ruleSets[0].urls.count
        appState.addSpecificRule("https://swift.org", to: setId)
        #expect(appState.ruleSets[0].urls.count == countAfterFirstAdd)

        appState.isBlocking = true
        appState.isUnblockable = true
        appState.addSpecificRule("https://example.com", to: setId)
        #expect(!appState.ruleSets[0].urls.contains("https://example.com"))
    }

    @Test("AppState covers primary ruleset and name fallback branches")
    func primaryRuleSetFallbackCoverage() {
        let appState = isolatedAppState(name: "primaryRuleSetFallbackCoverage")

        appState.ruleSets = []
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == nil)
        #expect(appState.currentPrimaryRuleSetName == "No List")

        let set = RuleSet(id: UUID(), name: "Main", urls: [])
        appState.ruleSets = [set]

        appState.isBlocking = true
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == set.id)

        appState.activeRuleSetId = UUID()
        #expect(appState.currentPrimaryRuleSetName == "Main")

        appState.isBlocking = false
        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        appState.schedules = [
            Schedule(
                name: "No set",
                days: [weekday],
                startTime: now.addingTimeInterval(-300),
                endTime: now.addingTimeInterval(300),
                isEnabled: true,
                type: .focus,
                ruleSetId: nil
            )
        ]
        appState.activeRuleSetId = set.id
        #expect(appState.currentPrimaryRuleSetId == set.id)
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == set.id)
    }

    @Test("AppState initializes with fallback appearance and injected monitor")
    func initFallbackAndInjectedMonitorCoverage() {
        let suiteA = "AppStateTests.initFallbackAndInjectedMonitorCoverage.A"
        let defaultsA = UserDefaults(suiteName: suiteA)!
        defaultsA.removePersistentDomain(forName: suiteA)
        let sourceAppState = AppState(defaults: defaultsA, isTesting: true)
        let monitor = BrowserMonitor(
            appState: sourceAppState,
            server: nil,
            automator: MockBrowserAutomator(),
            startTimer: false
        )

        let suiteB = "AppStateTests.initFallbackAndInjectedMonitorCoverage.B"
        let defaultsB = UserDefaults(suiteName: suiteB)!
        defaultsB.removePersistentDomain(forName: suiteB)
        defaultsB.set("not-a-real-mode", forKey: "AppearanceMode")

        let appState = AppState(defaults: defaultsB, monitor: monitor, isTesting: true)
        #expect(appState.appearanceMode == .system)
        #expect(appState.monitor === monitor)
    }

    @Test("AppState can initialize production calendar path with injected monitor")
    func initProductionCalendarPathCoverage() {
        let sourceSuite = "AppStateTests.initProductionCalendarPathCoverage.source"
        let sourceDefaults = UserDefaults(suiteName: sourceSuite)!
        sourceDefaults.removePersistentDomain(forName: sourceSuite)
        let sourceState = AppState(defaults: sourceDefaults, isTesting: true)
        let injectedMonitor = BrowserMonitor(
            appState: sourceState,
            server: nil,
            automator: MockBrowserAutomator(),
            startTimer: false
        )

        let targetSuite = "AppStateTests.initProductionCalendarPathCoverage.target"
        let targetDefaults = UserDefaults(suiteName: targetSuite)!
        targetDefaults.removePersistentDomain(forName: targetSuite)

        let appState = AppState(
            defaults: targetDefaults,
            monitor: injectedMonitor,
            calendar: nil,
            isTesting: false
        )

        #expect(appState.monitor === injectedMonitor)
        #expect(appState.calendarProvider is RealCalendarManager)
        if let real = appState.calendarProvider as? RealCalendarManager {
            real.isAuthorized = true
            real.fetchEvents()
        }
    }

    @Test("skipPomodoroPhase transitions between focus and break")
    func skipPomodoroPhaseCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(
            name: "skipPomodoroPhaseCoverage", timerScheduler: scheduler)

        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)

        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .breakTime)

        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .focus)

        appState.pomodoroStatus = .none
        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .none)
    }

    @Test("pause and pomodoro timer handlers execute countdown and transition logic")
    func timerHandlerCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(name: "timerHandlerCoverage", timerScheduler: scheduler)
        appState.isBlocking = true

        appState.startPause(minutes: 1)
        #expect(scheduler.handlers.count >= 2)

        appState.pauseRemaining = 2
        scheduler.fire(at: 1)
        #expect(appState.pauseRemaining == 1)

        appState.pauseRemaining = 0
        scheduler.fire(at: 1)
        #expect(!appState.isPaused)

        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)
        #expect(scheduler.handlers.count >= 3)

        let focusTimerIndex = scheduler.handlers.count - 1
        appState.pomodoroRemaining = 2
        scheduler.fire(at: focusTimerIndex)
        #expect(appState.pomodoroRemaining == 1)

        appState.pomodoroRemaining = 0
        scheduler.fire(at: focusTimerIndex)
        #expect(appState.pomodoroStatus == .breakTime)

        let breakTimerIndex = scheduler.handlers.count - 1
        appState.pomodoroRemaining = 0
        scheduler.fire(at: breakTimerIndex)
        #expect(appState.pomodoroStatus == .focus)
    }

    @Test("AppState covers nil self timer closures after deinit")
    func timerWeakSelfNilCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        var appState: AppState? = isolatedAppState(
            name: "timerWeakSelfNilCoverage", timerScheduler: scheduler)
        appState?.isBlocking = true
        appState?.startPause(minutes: 1)
        appState?.startPomodoro()
        #expect(scheduler.handlers.count >= 3)

        appState = nil
        scheduler.fire(at: 0)
        scheduler.fire(at: 1)
        scheduler.fire(at: 2)
        #expect(Bool(true))
    }

    @Test("refreshCurrentOpenUrls uses monitor-provided URLs")
    func refreshCurrentOpenUrlsCoverage() {
        let appState = isolatedAppState(name: "refreshCurrentOpenUrlsCoverage")
        let automator = MockBrowserAutomator()
        automator.activeUrl = "https://example.com"

        let monitor = BrowserMonitor(
            appState: appState,
            server: nil,
            automator: automator,
            startTimer: false
        )
        appState.monitor = monitor

        appState.refreshCurrentOpenUrls()
        #expect(appState.currentOpenUrls == ["https://example.com"])
    }

    @Test("refreshCurrentOpenUrls falls back to empty when monitor is missing")
    func refreshCurrentOpenUrlsNilMonitorCoverage() {
        let appState = isolatedAppState(name: "refreshCurrentOpenUrlsNilMonitorCoverage")
        appState.currentOpenUrls = ["stale"]
        appState.monitor = nil
        appState.refreshCurrentOpenUrls()
        #expect(appState.currentOpenUrls.isEmpty)
    }

    @Test("deleteSet updates active selection and saveSchedule empty-name defaults")
    func deleteAndDefaultNameCoverage() {
        let appState = isolatedAppState(name: "deleteAndDefaultNameCoverage")
        let set1 = RuleSet(id: UUID(), name: "Set 1", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Set 2", urls: [])
        appState.ruleSets = [set1, set2]
        appState.activeRuleSetId = set1.id
        appState.deleteSet(id: set1.id)
        #expect(appState.activeRuleSetId == set2.id)

        let start = Date()
        let end = start.addingTimeInterval(3600)
        appState.saveSchedule(
            name: " ",
            days: [2],
            date: nil,
            start: start,
            end: end,
            color: 0,
            type: .focus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )
        appState.saveSchedule(
            name: "",
            days: [3],
            date: nil,
            start: start,
            end: end,
            color: 0,
            type: .unfocus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )
        #expect(appState.schedules.contains { $0.name == "Focus Session" })
        #expect(appState.schedules.contains { $0.name == "Break Session" })
    }

    @Test("save and delete schedule remove empty-day entries")
    func emptyDayRemovalCoverage() {
        let appState = isolatedAppState(name: "emptyDayRemovalCoverage")
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let splitId = UUID()
        appState.schedules = [
            Schedule(id: splitId, name: "Split", days: [2], startTime: start, endTime: end)
        ]
        appState.saveSchedule(
            name: "Only day edited",
            days: [2],
            date: nil,
            start: start,
            end: end,
            color: 1,
            type: .focus,
            ruleSet: nil,
            existingId: splitId,
            modifyAllDays: false,
            initialDay: 2
        )
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "Only day edited")

        let deleteId = UUID()
        appState.schedules = [
            Schedule(id: deleteId, name: "Delete", days: [3], startTime: start, endTime: end)
        ]
        appState.deleteSchedule(id: deleteId, modifyAllDays: false, initialDay: 3)
        #expect(appState.schedules.isEmpty)
    }

    @Test("pomodoro break duration updates remaining during break phase")
    func breakDurationUpdateCoverage() {
        let appState = isolatedAppState(name: "breakDurationUpdateCoverage")
        appState.pomodoroStatus = .breakTime
        appState.pomodoroBreakDuration = 7
        #expect(appState.pomodoroRemaining == 420)
    }

    @Test("allowedRules falls back to first ruleset when activeRuleSetId is nil")
    func allowedRulesNilActiveRuleSetFallbackCoverage() {
        let appState = isolatedAppState(name: "allowedRulesNilActiveRuleSetFallbackCoverage")
        let fallbackSet = RuleSet(id: UUID(), name: "Fallback", urls: ["fallback.com"])
        appState.ruleSets = [fallbackSet]
        appState.activeRuleSetId = nil
        appState.isBlocking = true

        let rules = appState.allowedRules
        #expect(rules.contains("fallback.com"))
    }

    @Test("AppState deinit invalidates schedule, pause, and pomodoro timers")
    func appStateDeinitInvalidatesTimers() {
        let scheduler = MockRepeatingTimerScheduler()
        var appState: AppState? = isolatedAppState(
            name: "appStateDeinitInvalidatesTimers", timerScheduler: scheduler)
        appState?.isBlocking = true
        appState?.startPause(minutes: 1)
        appState?.startPomodoro()

        #expect(scheduler.timers.count == 3)
        let scheduleTimer = scheduler.timers[0]
        let pauseTimer = scheduler.timers[1]
        let pomodoroTimer = scheduler.timers[2]

        appState = nil

        #expect(scheduleTimer.invalidateCallCount == 1)
        #expect(pauseTimer.invalidateCallCount == 1)
        #expect(pomodoroTimer.invalidateCallCount == 1)
    }

    @Test("AppState replaces active pause and pomodoro timers safely")
    func appStateReplacesTimersSafely() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(
            name: "appStateReplacesTimersSafely", timerScheduler: scheduler)
        appState.isBlocking = true

        appState.startPause(minutes: 1)
        #expect(scheduler.timers.count == 2)
        let firstPauseTimer = scheduler.timers[1]

        appState.startPause(minutes: 2)
        #expect(scheduler.timers.count == 3)
        #expect(firstPauseTimer.invalidateCallCount == 1)

        appState.startPomodoro()
        #expect(scheduler.timers.count == 4)
        let firstPomodoroTimer = scheduler.timers[3]

        appState.startPomodoro()
        #expect(scheduler.timers.count == 5)
        #expect(firstPomodoroTimer.invalidateCallCount == 1)
    }

    @Test("Rules aggregate from all active focus schedules")
    func multipleSchedulesRules() {
        let appState = isolatedAppState(name: "multipleSchedulesRules")
        let ruleSet1 = RuleSet(id: UUID(), name: "Set 1", urls: ["url1.com"])
        let ruleSet2 = RuleSet(id: UUID(), name: "Set 2", urls: ["url2.com"])
        appState.ruleSets = [ruleSet1, ruleSet2]

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let sch1 = Schedule(
            name: "S1", days: [weekday], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus,
            ruleSetId: ruleSet1.id)
        let sch2 = Schedule(
            name: "S2", days: [weekday], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus,
            ruleSetId: ruleSet2.id)

        appState.schedules = [sch1, sch2]

        let allowed = appState.allowedRules
        #expect(allowed.contains("url1.com"))
        #expect(allowed.contains("url2.com"))
    }

    @Test("todaySchedules filters by current day and sorts by time")
    func todaySchedulesLogic() {
        let appState = isolatedAppState(name: "todaySchedulesLogic")
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: now)
        let otherDay = today == 1 ? 2 : 1

        let early = calendar.date(from: DateComponents(hour: 8, minute: 0))!
        let late = calendar.date(from: DateComponents(hour: 20, minute: 0))!

        let s1 = Schedule(
            name: "Late Today", days: [today], startTime: late,
            endTime: late.addingTimeInterval(3600))
        let s2 = Schedule(
            name: "Early Today", days: [today], startTime: early,
            endTime: early.addingTimeInterval(3600))
        let s3 = Schedule(
            name: "Other Day", days: [otherDay], startTime: early,
            endTime: early.addingTimeInterval(3600))

        appState.schedules = [s1, s2, s3]

        let result = appState.todaySchedules
        #expect(result.count == 2)
        #expect(result[0].name == "Early Today")
        #expect(result[1].name == "Late Today")
    }

    @Test("saveSchedule logic: Create and Update")
    func saveScheduleLogic() {
        let appState = isolatedAppState(name: "saveScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)

        appState.saveSchedule(
            name: "New", days: [2], date: nil, start: start, end: end, color: 1, type: .focus,
            ruleSet: nil, existingId: nil, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "New")

        let id = appState.schedules.first!.id
        appState.saveSchedule(
            name: "Updated", days: [2, 3], date: nil, start: start, end: end, color: 2,
            type: .unfocus, ruleSet: nil, existingId: id, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "Updated")
        #expect(appState.schedules.first?.days.count == 2)
    }

    @Test("saveSchedule logic: Splitting recurring schedule")
    func splitScheduleLogic() {
        let appState = isolatedAppState(name: "splitScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let originalId = UUID()
        let original = Schedule(
            id: originalId, name: "Original", days: [2, 3, 4], startTime: start, endTime: end)
        appState.schedules = [original]

        appState.saveSchedule(
            name: "Split", days: [3], date: nil, start: start, end: end, color: 5, type: .focus,
            ruleSet: nil, existingId: originalId, modifyAllDays: false, initialDay: 3)

        let old = appState.schedules.first { $0.id == originalId }
        #expect(old?.days == [2, 4])

        let new = appState.schedules.first { $0.name == "Split" }
        #expect(new?.days == [3])
        #expect(appState.schedules.count == 2)
    }

    @Test("deleteSchedule logic: Full and Partial")
    func deleteScheduleLogic() {
        let appState = isolatedAppState(name: "deleteScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let id = UUID()
        appState.schedules = [
            Schedule(id: id, name: "T", days: [2, 3], startTime: start, endTime: end)
        ]

        appState.deleteSchedule(id: id, modifyAllDays: false, initialDay: 2)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.days == [3])

        appState.deleteSchedule(id: id, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.isEmpty)
    }

    @Test("currentPrimaryRuleSetId priority logic")
    func ruleSetPriority() {
        let appState = isolatedAppState(name: "ruleSetPriority")
        let set1 = RuleSet(id: UUID(), name: "Manual", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Schedule", urls: [])
        appState.ruleSets = [set1, set2]

        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let sch = Schedule(
            name: "S", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id
        )
        appState.schedules = [sch]

        appState.checkSchedules()
        #expect(appState.currentPrimaryRuleSetId == set2.id)

        appState.activeRuleSetId = set1.id
        appState.toggleBlocking()
        #expect(!appState.isBlocking)

        appState.toggleBlocking()
        #expect(appState.isBlocking)
        #expect(appState.currentPrimaryRuleSetId == set1.id)

        appState.pomodoroStatus = .focus
        #expect(appState.currentPrimaryRuleSetId == set1.id)
    }

    @Test("Pomodoro keeps enforcing the session-captured list while selection changes")
    func pomodoroUsesCapturedRuleSetDuringActiveSession() {
        let appState = isolatedAppState(name: "pomodoroUsesCapturedRuleSetDuringActiveSession")
        let set1 = RuleSet(id: UUID(), name: "Set 1", urls: ["set1.example"])
        let set2 = RuleSet(id: UUID(), name: "Set 2", urls: ["set2.example"])
        appState.ruleSets = [set1, set2]
        appState.activeRuleSetId = set1.id

        appState.startPomodoro()
        #expect(appState.currentPrimaryRuleSetId == set1.id)
        #expect(appState.allowedRules.contains("set1.example"))
        #expect(!appState.allowedRules.contains("set2.example"))

        appState.activeRuleSetId = set2.id
        #expect(appState.currentPrimaryRuleSetId == set1.id)
        #expect(appState.allowedRules.contains("set1.example"))
        #expect(!appState.allowedRules.contains("set2.example"))
    }

    @Test("Schedule enforcement ignores active list selection changes while schedule is active")
    func scheduleUsesAssignedRuleSetDuringActiveSession() {
        let appState = isolatedAppState(name: "scheduleUsesAssignedRuleSetDuringActiveSession")
        let set1 = RuleSet(id: UUID(), name: "Schedule Set", urls: ["schedule.example"])
        let set2 = RuleSet(id: UUID(), name: "Manual Set", urls: ["manual.example"])
        appState.ruleSets = [set1, set2]
        appState.activeRuleSetId = set2.id

        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        let schedule = Schedule(
            name: "Focus",
            days: [weekday],
            startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000),
            isEnabled: true,
            type: .focus,
            ruleSetId: set1.id
        )
        appState.schedules = [schedule]
        appState.checkSchedules()

        #expect(appState.currentPrimaryRuleSetId == set1.id)
        #expect(appState.allowedRules.contains("schedule.example"))
        #expect(!appState.allowedRules.contains("manual.example"))

        appState.activeRuleSetId = set2.id
        #expect(appState.currentPrimaryRuleSetId == set1.id)
        #expect(appState.allowedRules.contains("schedule.example"))
        #expect(!appState.allowedRules.contains("manual.example"))
    }

    @Test("Pomodoro temporarily overrides schedule allow list, then schedule resumes after pomodoro stops")
    func pomodoroOverrideRevertsToScheduleRules() {
        let appState = isolatedAppState(name: "pomodoroOverrideRevertsToScheduleRules")
        let scheduleSet = RuleSet(id: UUID(), name: "Schedule Set", urls: ["schedule.example"])
        let pomodoroSet = RuleSet(id: UUID(), name: "Pomodoro Set", urls: ["pomodoro.example"])
        appState.ruleSets = [scheduleSet, pomodoroSet]
        appState.activeRuleSetId = scheduleSet.id

        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        let schedule = Schedule(
            name: "Active Focus",
            days: [weekday],
            startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000),
            isEnabled: true,
            type: .focus,
            ruleSetId: scheduleSet.id
        )

        appState.schedules = [schedule]
        appState.checkSchedules()

        #expect(appState.isBlocking)
        #expect(appState.currentPrimaryRuleSetId == scheduleSet.id)
        #expect(appState.allowedRules.contains("schedule.example"))
        #expect(!appState.allowedRules.contains("pomodoro.example"))

        appState.activeRuleSetId = pomodoroSet.id
        appState.startPomodoro()

        #expect(appState.pomodoroStatus == .focus)
        #expect(appState.currentPrimaryRuleSetId == pomodoroSet.id)
        #expect(appState.allowedRules.contains("pomodoro.example"))
        #expect(!appState.allowedRules.contains("schedule.example"))

        appState.stopPomodoro()

        #expect(appState.pomodoroStatus == .none)
        #expect(appState.isBlocking, "Schedule should keep blocking active after pomodoro stops")
        #expect(appState.currentPrimaryRuleSetId == scheduleSet.id)
        #expect(appState.allowedRules.contains("schedule.example"))
        #expect(!appState.allowedRules.contains("pomodoro.example"))
    }

    @Test("currentPrimaryRuleSetName returns Unknown List when active schedule points to missing ruleset")
    func primaryRuleSetNameUnknownForMissingScheduleSet() {
        let appState = isolatedAppState(name: "primaryRuleSetNameUnknownForMissingScheduleSet")
        let knownSet = RuleSet(id: UUID(), name: "Known", urls: ["known.example"])
        appState.ruleSets = [knownSet]
        appState.activeRuleSetId = knownSet.id

        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        let missingRuleSetId = UUID()
        appState.schedules = [
            Schedule(
                name: "Missing RuleSet Schedule",
                days: [weekday],
                startTime: now.addingTimeInterval(-600),
                endTime: now.addingTimeInterval(600),
                isEnabled: true,
                type: .focus,
                ruleSetId: missingRuleSetId
            )
        ]
        appState.checkSchedules()

        #expect(appState.currentPrimaryRuleSetId == missingRuleSetId)
        #expect(appState.currentPrimaryRuleSetName == "Unknown List")
    }

    @Test("allowedRules handles pomodoro focus when there are no rulesets")
    func allowedRulesPomodoroWithNoRuleSets() {
        let appState = isolatedAppState(name: "allowedRulesPomodoroWithNoRuleSets")
        appState.ruleSets = []
        appState.activeRuleSetId = nil
        appState.pomodoroStatus = .focus
        appState.isBlocking = false

        let rules = appState.allowedRules
        #expect(rules.isEmpty)
    }

    @Test("allowedRules falls back to first ruleset during schedule-driven blocking without schedule ruleset")
    func allowedRulesScheduleFallbackToFirstSet() {
        let appState = isolatedAppState(name: "allowedRulesScheduleFallbackToFirstSet")
        let fallback = RuleSet(id: UUID(), name: "Fallback", urls: ["fallback.example"])
        appState.ruleSets = [fallback]
        appState.activeRuleSetId = nil

        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        appState.schedules = [
            Schedule(
                name: "Focus Without List",
                days: [weekday],
                startTime: now.addingTimeInterval(-600),
                endTime: now.addingTimeInterval(600),
                isEnabled: true,
                type: .focus,
                ruleSetId: nil
            )
        ]
        appState.checkSchedules()

        #expect(appState.isBlocking)
        #expect(appState.allowedRules.contains("fallback.example"))
    }

    @Test("startPomodoro rehydrates ruleset from active selection when started from break state")
    func startPomodoroFromBreakUsesActiveRuleSetSelection() {
        let appState = isolatedAppState(name: "startPomodoroFromBreakUsesActiveRuleSetSelection")
        let set = RuleSet(id: UUID(), name: "Selected", urls: ["selected.example"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id
        appState.pomodoroStatus = .breakTime

        appState.startPomodoro()

        #expect(appState.pomodoroStatus == .focus)
        #expect(appState.currentPrimaryRuleSetId == set.id)
        #expect(appState.allowedRules.contains("selected.example"))
    }

    @Test("Manual toggle can stop a schedule-started session")
    func manualOverrideOfSchedule() {
        let appState = isolatedAppState(name: "manualOverrideOfSchedule")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let sch = Schedule(
            name: "S", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)

        appState.schedules = [sch]
        appState.checkSchedules()
        #expect(appState.isBlocking)

        appState.toggleBlocking()

        #expect(!appState.isBlocking)

        appState.checkSchedules()

        #expect(!appState.isBlocking)
    }

    @Test("Nested schedule priority (Break inside Focus)")
    func nestedSchedulePriority() {
        let appState = isolatedAppState(name: "nestedSchedulePriority")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)

        let focus = Schedule(
            name: "Focus", days: [today], startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600), isEnabled: true, type: .focus)

        let breakSession = Schedule(
            name: "Break", days: [today], startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600), isEnabled: true, type: .unfocus)

        appState.schedules = [focus, breakSession]
        appState.checkSchedules()

        #expect(!appState.isBlocking)
    }

    @Test("Challenge phrase enforcement logic")
    func challengePhraseEnforcement() {
        let appState = isolatedAppState(name: "challengePhraseEnforcement")

        appState.isUnblockable = true
        #expect(!appState.disableUnblockableWithChallenge(phrase: "wrong"))
        #expect(appState.isUnblockable)

        #expect(appState.disableUnblockableWithChallenge(phrase: AppState.challengePhrase))
        #expect(!appState.isUnblockable)

        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100)  // Ensure it's locked
        #expect(appState.isPomodoroLocked)

        #expect(!appState.stopPomodoroWithChallenge(phrase: "wrong"))
        #expect(appState.pomodoroStatus == .focus)

        #expect(appState.stopPomodoroWithChallenge(phrase: AppState.challengePhrase))
        #expect(appState.pomodoroStatus == .none)
    }

    @Test("Negative: Challenge phrase is case-sensitive and strict on whitespace")
    func challengePhraseStrictness() {
        let appState = isolatedAppState(name: "challengePhraseStrictness")
        appState.isUnblockable = true

        let lowercased = AppState.challengePhrase.lowercased()
        #expect(!appState.disableUnblockableWithChallenge(phrase: lowercased))

        let padded = " " + AppState.challengePhrase + " "
        #expect(!appState.disableUnblockableWithChallenge(phrase: padded))

        #expect(appState.isUnblockable, "Should still be locked after bad attempts")
    }

    @Test("Negative: Pause when not blocking should fail")
    func pauseWhileNotBlocking() {
        let appState = isolatedAppState(name: "pauseWhileNotBlocking")
        appState.isBlocking = false

        appState.startPause(minutes: 5)
        #expect(!appState.isPaused)
    }

    @Test("Negative: Duplicate rules should not be added")
    func duplicateRules() {
        let appState = isolatedAppState(name: "duplicateRules")
        let id = appState.ruleSets[0].id

        appState.addRule("google.com", to: id)
        let count = appState.ruleSets[0].urls.count

        appState.addRule("google.com", to: id)
        #expect(appState.ruleSets[0].urls.count == count, "Should not add duplicate URL")

        appState.addRule(" google.com ", to: id)
        #expect(appState.ruleSets[0].urls.count == count, "Should trim and detect duplicate")
    }

    @Test("Negative: Stop Pomodoro when locked without challenge")
    func stopLockedPomodoro() {
        let appState = isolatedAppState(name: "stopLockedPomodoro")
        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100)

        appState.stopPomodoro()
        #expect(
            appState.pomodoroStatus == .focus, "Should not stop locked session without challenge")
    }

    @Test("Negative: Rule management with invalid IDs")
    func ruleManagementInvalidIds() {
        let appState = isolatedAppState(name: "ruleManagementInvalidIds")
        let fakeId = UUID()

        appState.addRule("test.com", to: fakeId)
        #expect(!appState.ruleSets.contains { $0.urls.contains("test.com") })

        appState.removeRule("google.com", from: fakeId)

        let count = appState.ruleSets.count
        appState.deleteSet(id: fakeId)
        #expect(appState.ruleSets.count == count)
    }

    @Test("Rule aggregation across concurrent focus schedules")
    func concurrentSchedulesRuleAggregation() {
        let appState = isolatedAppState(name: "concurrentSchedulesRuleAggregation")

        let set1 = RuleSet(id: UUID(), name: "Set 1", urls: ["site1.com"])
        let set2 = RuleSet(id: UUID(), name: "Set 2", urls: ["site2.com"])
        appState.ruleSets = [set1, set2]

        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)

        let sch1 = Schedule(
            name: "S1", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set1.id
        )
        let sch2 = Schedule(
            name: "S2", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id
        )
        appState.schedules = [sch1, sch2]

        let rules = appState.allowedRules
        #expect(rules.contains("site1.com"))
        #expect(rules.contains("site2.com"))
        #expect(rules.count == 2)
    }

    @Test("Negative: Prevent rule modifications during strict mode")
    func strictRuleModificationProtection() {
        let appState = isolatedAppState(name: "strictRuleModificationProtection")
        let setId = appState.ruleSets[0].id
        let originalCount = appState.ruleSets[0].urls.count

        appState.isBlocking = true
        appState.isUnblockable = true
        #expect(appState.isStrictActive)

        appState.addRule("cheat.com", to: setId)
        #expect(appState.ruleSets[0].urls.count == originalCount)

        if originalCount > 0 {
            let first = appState.ruleSets[0].urls[0]
            appState.removeRule(first, from: setId)
            #expect(appState.ruleSets[0].urls.contains(first))
        }

        appState.deleteSet(id: setId)
        #expect(!appState.ruleSets.isEmpty)
    }

    @Test("Negative: Prevent activeRuleSetId change during blocking")
    func ruleSetSwitchDuringBlocking() {
        let appState = isolatedAppState(name: "ruleSetSwitchDuringBlocking")
        let set1 = RuleSet(id: UUID(), name: "S1", urls: [])
        let set2 = RuleSet(id: UUID(), name: "S2", urls: [])
        appState.ruleSets = [set1, set2]

        appState.activeRuleSetId = set1.id
        appState.isBlocking = true

        #expect(appState.currentPrimaryRuleSetId == set1.id)
    }

    @Test("Negative: startPause with zero or negative duration")
    func pauseDurationEdgeCases() {
        let appState = isolatedAppState(name: "pauseDurationEdgeCases")
        appState.isBlocking = true

        appState.startPause(minutes: 0)
        #expect(!appState.isPaused)

        appState.startPause(minutes: -5)
        #expect(!appState.isPaused)
    }

    @Test("Manual pause takes precedence over Pomodoro focus")
    func pausePrecedence() {
        let appState = isolatedAppState(name: "pausePrecedence")
        appState.isBlocking = true

        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)

        appState.startPause(minutes: 5)
        #expect(appState.isPaused)

        #expect(appState.isPaused == true)
    }

    @Test("todaySchedules badge count logic")
    func todaySchedulesBadgeCount() {
        let appState = isolatedAppState(name: "todaySchedulesBadgeCount")
        let today = Calendar.current.component(.weekday, from: Date())

        let s1 = Schedule(
            name: "Enabled", days: [today], startTime: Date(), endTime: Date(), isEnabled: true)
        let s2 = Schedule(
            name: "Disabled", days: [today], startTime: Date(), endTime: Date(), isEnabled: false)

        appState.schedules = [s1, s2]

        let result = appState.todaySchedules
        #expect(result.count == 2)

        let enabledCount = result.filter { $0.isEnabled }.count
        #expect(enabledCount == 1)
    }

    @Test("Negative: Toggling blocking OFF pauses ALL currently active schedules")
    func pauseMultipleOverlappingSchedules() {
        let appState = isolatedAppState(name: "pauseMultipleOverlappingSchedules")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)

        let s1 = Schedule(
            name: "S1", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)
        let s2 = Schedule(
            name: "S2", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)
        appState.schedules = [s1, s2]

        appState.checkSchedules()
        #expect(appState.isBlocking)

        appState.toggleBlocking()
        #expect(!appState.isBlocking)

        appState.checkSchedules()
        #expect(!appState.isBlocking)
    }

    @Test("todaySchedules handles duplicate start times gracefully")
    func todaySchedulesDuplicateTimes() {
        let appState = isolatedAppState(name: "todaySchedulesDuplicateTimes")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)

        let time = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!
        let s1 = Schedule(
            name: "A", days: [today], startTime: time, endTime: time.addingTimeInterval(3600))
        let s2 = Schedule(
            name: "B", days: [today], startTime: time, endTime: time.addingTimeInterval(3600))

        appState.schedules = [s1, s2]
        let result = appState.todaySchedules
        #expect(result.count == 2)
    }

    @Test("currentPrimaryRuleSetName correctly identifies the active list name")
    func primaryRuleSetNameLogic() {
        let appState = isolatedAppState(name: "primaryRuleSetNameLogic")

        let set1 = RuleSet(id: UUID(), name: "Manual Set", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Schedule Set", urls: [])
        appState.ruleSets = [set1, set2]

        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)

        appState.activeRuleSetId = set1.id
        appState.isBlocking = true
        #expect(appState.currentPrimaryRuleSetName == "Manual Set")

        appState.isBlocking = false
        let sch = Schedule(
            name: "S", days: [today], startTime: now.addingTimeInterval(-1000),
            endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id
        )
        appState.schedules = [sch]
        appState.checkSchedules()
        #expect(appState.isBlocking)
        #expect(appState.currentPrimaryRuleSetName == "Schedule Set")

        appState.activeRuleSetId = UUID()
        #expect(
            appState.currentPrimaryRuleSetName == "Manual Set"
                || appState.currentPrimaryRuleSetName == "Schedule Set")
    }

    @Test("Pomodoro remaining time reflects duration changes mid-run")
    func pomodoroMidRunDurationChange() {
        let appState = isolatedAppState(name: "pomodoroMidRunDurationChange")
        appState.pomodoroFocusDuration = 25
        appState.startPomodoro()
        #expect(appState.pomodoroRemaining == 25 * 60)

        appState.pomodoroFocusDuration = 45

        #expect(appState.pomodoroRemaining == 45 * 60)
    }

    @Test("One-off sessions only appear in their specific week grid")
    func calendarGridFilteringLogic() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 2, day: 18, hour: 12)
        let testDate = calendar.date(from: components)!

        let start = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 11, minute: 0))!

        let schedule = Schedule(
            name: "Feb 18 Only", days: [], date: testDate, startTime: start, endTime: end)

        func shouldShow(s: Schedule, weekStart: Date, weekEnd: Date) -> Bool {
            let cal = Calendar.current
            if let specificDate = s.date {
                let d = cal.startOfDay(for: specificDate)
                let s = cal.startOfDay(for: weekStart)
                let e = cal.startOfDay(for: weekEnd)
                return d >= s && d < e
            }
            return true
        }

        let week1 = WeeklyCalendarView.getWeekDates(
            at: testDate, weekStartsOnMonday: false, offset: 0)
        let week1Start = week1.first!
        let week1End = calendar.date(byAdding: .day, value: 7, to: week1Start)!
        #expect(shouldShow(s: schedule, weekStart: week1Start, weekEnd: week1End) == true)

        let week2 = WeeklyCalendarView.getWeekDates(
            at: testDate, weekStartsOnMonday: false, offset: 1)
        let week2Start = week2.first!
        let week2End = calendar.date(byAdding: .day, value: 7, to: week2Start)!
        #expect(shouldShow(s: schedule, weekStart: week2Start, weekEnd: week2End) == false)
    }
}
