import Combine
import Foundation

@MainActor
enum AppStateLifecycleService {
    struct BootstrapProjection {
        let session: AppSessionDomainState
        let settings: AppSettingsDomainState
        let pomodoro: AppPomodoroDomainState
        let rules: AppRulesDomainState
        let schedule: AppScheduleDomainState
    }

    struct RuntimeBindings {
        let monitor: BrowserMonitor?
        let calendarCancellable: AnyCancellable
        let rescheduleScheduleTimer: @MainActor () -> Void
    }

    @MainActor
    static func bindPersistence(
        appState: AppState,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        return AppStatePersistenceCoordinator.bind(
            appState: appState,
            settingsStore: settingsStore
        )
    }

    static func makeBootstrapProjection(
        snapshot: AppStateBootstrapService.Snapshot
    ) -> BootstrapProjection {
        BootstrapProjection(
            session: AppSessionDomainState(
            isBlocking: snapshot.isBlocking,
            isStrict: snapshot.isStrict,
            isPaused: false,
            pauseRemaining: 0,
            wasStartedBySchedule: snapshot.wasStartedBySchedule,
            manuallyPausedScheduleIds: []
        ),
            settings: AppSettingsDomainState(
            weekStartsOnMonday: snapshot.weekStartsOnMonday,
            accentColorIndex: snapshot.accentColorIndex,
            appearanceMode: snapshot.appearanceMode,
            cursorFluidAnimationEnabled: snapshot.cursorFluidAnimationEnabled,
            calendarImportFocusTitleRules: snapshot.calendarImportFocusTitleRules,
            calendarImportBreakTitleRules: snapshot.calendarImportBreakTitleRules,
            calendarImportedScheduleRuleSetId: snapshot.calendarImportedScheduleRuleSetId,
            blockNewTabs: snapshot.blockNewTabs,
            blockDeveloperHosts: snapshot.blockDeveloperHosts,
            blockLocalNetworkHosts: snapshot.blockLocalNetworkHosts,
            allowSearchEngineWebsites: snapshot.allowSearchEngineWebsites,
            allowAIProviderWebsites: snapshot.allowAIProviderWebsites
        ),
            pomodoro: AppPomodoroDomainState(
            status: .none,
            remaining: 0,
            startedAt: nil,
            focusDurationMinutes: snapshot.pomodoroFocusDuration,
            breakDurationMinutes: snapshot.pomodoroBreakDuration,
            ruleSetId: nil
        ),
            rules: AppRulesDomainState(
            ruleSets: snapshot.ruleSets,
            activeRuleSetId: snapshot.activeRuleSetId
        ),
            schedule: AppScheduleDomainState(
            schedules: snapshot.schedules,
            calendarIntegrationEnabled: snapshot.calendarIntegrationEnabled,
            isSynchronizingImportedSchedules: false,
            suppressedImportedCalendarEventKeys: snapshot.suppressedImportedCalendarEventKeys
        )
        )
    }

    static func resolveLegacyBlockingMigration(
        logicFacade: AppStateLogicFacade,
        hasPersistedWasStartedBySchedule: Bool,
        current: AppStateLogicFacade.SessionState,
        schedules: [Schedule],
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarEvents: [ExternalEvent]
    ) -> AppStateLogicFacade.SessionState? {
        logicFacade.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: hasPersistedWasStartedBySchedule,
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarEvents: calendarEvents
        )
    }

    static func startRuntime(
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool,
        calendarProvider: any CalendarProvider,
        timerCoordinator: AppStateTimerCoordinator,
        monitorStateSnapshotProvider: @escaping @Sendable () async -> BrowserMonitor.StateSnapshot?,
        onMonitorEvent: @escaping @Sendable (BrowserMonitor.Event) -> Void,
        onScheduleUpdate: @escaping @MainActor () -> Void,
        scheduleTickIntervalProvider: @escaping @MainActor () -> TimeInterval
    ) -> RuntimeBindings {
        let monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injectedMonitor,
            isTesting: isTesting
        ) {
            AppStateRuntimeMonitorFactory.makeMonitor(
                stateSnapshotProvider: monitorStateSnapshotProvider,
                onEvent: onMonitorEvent,
                isTesting: isTesting
            )
        }

        let runtimeWiring = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: calendarProvider,
            timerCoordinator: timerCoordinator,
            onCalendarChange: onScheduleUpdate,
            onScheduleTick: onScheduleUpdate,
            scheduleTickIntervalProvider: scheduleTickIntervalProvider
        )

        return RuntimeBindings(
            monitor: monitor,
            calendarCancellable: runtimeWiring.calendarCancellable,
            rescheduleScheduleTimer: runtimeWiring.rescheduleScheduleTimer
        )
    }

    static func teardown(
        timerCoordinator: AppStateTimerCoordinator
    ) {
        AppStateRuntimeWiringCoordinator.teardown(
            timerCoordinator: timerCoordinator
        )
    }
}
