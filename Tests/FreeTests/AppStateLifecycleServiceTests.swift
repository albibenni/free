import Combine
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct AppStateLifecycleServiceTests {
    private func makeMonitor() -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: {
                BrowserMonitor.StateSnapshot(
                    isBlocking: false,
                    isPaused: false,
                    blockNewTabs: false,
                    blockDeveloperHosts: false,
                    blockLocalNetworkHosts: false,
                    allowedRules: []
                )
            },
            onEvent: { _ in },
            server: nil,
            startTimer: false
        )
    }

    @Test("makeBootstrapProjection maps all snapshot domains")
    func makeBootstrapProjectionMapsSnapshot() {
        let schedule = Schedule(
            name: "Focus",
            days: [2],
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            isEnabled: true,
            colorIndex: 2,
            type: .focus
        )
        let ruleSet = RuleSet(name: "Work", urls: ["swift.org"])
        let importedRuleSetId = UUID()
        let snapshot = AppStateBootstrapService.Snapshot(
            isBlocking: true,
            isStrict: true,
            weekStartsOnMonday: true,
            accentColorIndex: 3,
            appearanceMode: .dark,
            cursorFluidAnimationEnabled: false,
            calendarIntegrationEnabled: true,
            calendarImportsBlockTime: true,
            calendarImportFocusTitleRules: ["Focus", "Deep Work"],
            calendarImportBreakTitleRules: ["Break", "Lunch"],
            calendarImportedScheduleRuleSetId: importedRuleSetId,
            blockNewTabs: true,
            blockDeveloperHosts: true,
            blockLocalNetworkHosts: true,
            allowSearchEngineWebsites: true,
            allowAIProviderWebsites: true,
            pomodoroFocusDuration: 50,
            pomodoroBreakDuration: 10,
            ruleSets: [ruleSet],
            schedules: [schedule],
            activeRuleSetId: ruleSet.id,
            wasStartedBySchedule: true,
            manualBlockingEnabled: false,
            suppressedImportedCalendarEventKeys: ["event-1"]
        )

        let projection = AppStateLifecycleService.makeBootstrapProjection(snapshot: snapshot)

        #expect(projection.session.isBlocking)
        #expect(projection.session.isStrict)
        #expect(projection.session.wasStartedBySchedule)
        #expect(projection.settings.weekStartsOnMonday)
        #expect(projection.settings.accentColorIndex == 3)
        #expect(projection.settings.appearanceMode == .dark)
        #expect(projection.settings.cursorFluidAnimationEnabled == false)
        #expect(projection.settings.calendarImportFocusTitleRules == ["Focus", "Deep Work"])
        #expect(projection.settings.calendarImportBreakTitleRules == ["Break", "Lunch"])
        #expect(projection.settings.calendarImportedScheduleRuleSetId == importedRuleSetId)
        #expect(projection.settings.blockNewTabs)
        #expect(projection.settings.blockDeveloperHosts)
        #expect(projection.settings.blockLocalNetworkHosts)
        #expect(projection.settings.allowSearchEngineWebsites)
        #expect(projection.settings.allowAIProviderWebsites)
        #expect(projection.pomodoro.focusDurationMinutes == 50)
        #expect(projection.pomodoro.breakDurationMinutes == 10)
        #expect(projection.rules.ruleSets == [ruleSet])
        #expect(projection.rules.activeRuleSetId == ruleSet.id)
        #expect(projection.schedule.schedules == [schedule])
        #expect(projection.schedule.calendarIntegrationEnabled)
        #expect(projection.schedule.calendarImportsBlockTime)
        #expect(projection.schedule.suppressedImportedCalendarEventKeys == ["event-1"])
    }

    @Test("resolveLegacyBlockingMigration returns nil when migration is not needed and state when needed")
    func resolveLegacyBlockingMigrationBranches() {
        let facade = AppStateLogicFacade.live
        let current = AppStateLogicFacade.SessionState(
            isBlocking: true,
            wasStartedBySchedule: false,
            manuallyPausedScheduleIds: []
        )

        let alreadyMigrated = AppStateLifecycleService.resolveLegacyBlockingMigration(
            logicFacade: facade,
            hasPersistedWasStartedBySchedule: true,
            current: current,
            schedules: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )
        #expect(alreadyMigrated == nil)

        let migrated = AppStateLifecycleService.resolveLegacyBlockingMigration(
            logicFacade: facade,
            hasPersistedWasStartedBySchedule: false,
            current: current,
            schedules: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )
        #expect(migrated != nil)
        #expect(migrated?.isBlocking == false)
    }

    @MainActor
    @Test("startRuntime and teardown wire monitor, timers, and cancellables")
    func startRuntimeAndTeardown() {
        let injectedMonitor = makeMonitor()
        let calendar = MockCalendarManager()
        let scheduler = MockRepeatingTimerScheduler()
        let timerCoordinator = AppStateTimerCoordinator(timerScheduler: scheduler)

        var scheduleUpdateCount = 0
        let bindings = AppStateLifecycleService.startRuntime(
            injectedMonitor: injectedMonitor,
            isTesting: true,
            calendarProvider: calendar,
            timerCoordinator: timerCoordinator,
            monitorStateSnapshotProvider: { nil },
            onMonitorEvent: { _ in },
            onScheduleUpdate: { scheduleUpdateCount += 1 },
            scheduleTickIntervalProvider: { 600 }
        )

        #expect(bindings.monitor === injectedMonitor)
        #expect(scheduler.intervals == [600])

        scheduler.fire(at: 0)
        #expect(scheduleUpdateCount == 1)

        var calendarCancellable: AnyCancellable? = bindings.calendarCancellable
        var persistenceCancellables: Set<AnyCancellable> = [
            AnyCancellable {}
        ]
        AppStateLifecycleService.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable,
            persistenceCancellables: &persistenceCancellables
        )
        #expect(calendarCancellable == nil)
        #expect(persistenceCancellables.isEmpty)
        #expect(scheduler.timers.first?.invalidateCallCount == 1)
    }

    @MainActor
    @Test("startRuntime builds monitor from factory when not testing and no injected monitor is provided")
    func startRuntimeBuildsMonitorFromFactory() {
        let calendar = MockCalendarManager()
        let scheduler = MockRepeatingTimerScheduler()
        let timerCoordinator = AppStateTimerCoordinator(timerScheduler: scheduler)

        let bindings = AppStateLifecycleService.startRuntime(
            injectedMonitor: nil,
            isTesting: false,
            calendarProvider: calendar,
            timerCoordinator: timerCoordinator,
            monitorStateSnapshotProvider: { nil },
            onMonitorEvent: { _ in },
            onScheduleUpdate: {},
            scheduleTickIntervalProvider: { 600 }
        )

        #expect(bindings.monitor != nil)
        bindings.monitor?.stopMonitoring()

        var calendarCancellable: AnyCancellable? = bindings.calendarCancellable
        var persistenceCancellables: Set<AnyCancellable> = []
        AppStateLifecycleService.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable,
            persistenceCancellables: &persistenceCancellables
        )
        #expect(calendarCancellable == nil)
    }

    @Test("bindPersistence forwards to persistence coordinator and returns cancellables")
    func bindPersistence() {
        let suite = "AppStateLifecycleServiceTests.bindPersistence"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settingsStore = SettingsStore(defaults: defaults)
        let sampleRuleSet = RuleSet(name: "Default", urls: [])

        let bindings = AppStatePersistenceCoordinator.Bindings(
            isBlocking: Just(false).eraseToAnyPublisher(),
            isStrict: Just(false).eraseToAnyPublisher(),
            weekStartsOnMonday: Just(false).eraseToAnyPublisher(),
            accentColorIndex: Just(0).eraseToAnyPublisher(),
            appearanceMode: Just(.system).eraseToAnyPublisher(),
            cursorFluidAnimationEnabled: Just(true).eraseToAnyPublisher(),
            calendarIntegrationEnabled: Just(false).eraseToAnyPublisher(),
            calendarImportsBlockTime: Just(false).eraseToAnyPublisher(),
            calendarImportFocusTitleRules: Just([]).eraseToAnyPublisher(),
            calendarImportBreakTitleRules: Just([]).eraseToAnyPublisher(),
            calendarImportedScheduleRuleSetId: Just(nil).eraseToAnyPublisher(),
            blockNewTabs: Just(false).eraseToAnyPublisher(),
            blockDeveloperHosts: Just(false).eraseToAnyPublisher(),
            blockLocalNetworkHosts: Just(false).eraseToAnyPublisher(),
            allowSearchEngineWebsites: Just(false).eraseToAnyPublisher(),
            allowAIProviderWebsites: Just(false).eraseToAnyPublisher(),
            ruleSets: Just([sampleRuleSet]).eraseToAnyPublisher(),
            activeRuleSetId: Just(sampleRuleSet.id).map(Optional.some).eraseToAnyPublisher(),
            pomodoroFocusDuration: Just(25).eraseToAnyPublisher(),
            pomodoroBreakDuration: Just(5).eraseToAnyPublisher()
        )

        let cancellables = AppStateLifecycleService.bindPersistence(
            bindings: bindings,
            settingsStore: settingsStore
        )
        #expect(cancellables.count == 20)
    }
}
