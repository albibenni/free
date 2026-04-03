import Combine
import Foundation

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
        let rescheduleScheduleTimer: () -> Void
    }

    static func bindPersistence(
        bindings: AppStatePersistenceCoordinator.Bindings,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        AppStatePersistenceCoordinator.bind(
            bindings: bindings,
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
        monitorStateSnapshotProvider: @escaping () -> BrowserMonitor.StateSnapshot?,
        onMonitorEvent: @escaping (BrowserMonitor.Event) -> Void,
        onScheduleUpdate: @escaping () -> Void,
        scheduleTickIntervalProvider: @escaping () -> TimeInterval
    ) -> RuntimeBindings {
        let monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injectedMonitor,
            isTesting: isTesting
        ) {
            AppStateRuntimeMonitorFactory.makeMonitor(
                stateSnapshotProvider: monitorStateSnapshotProvider,
                onEvent: onMonitorEvent
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
        timerCoordinator: AppStateTimerCoordinator,
        calendarCancellable: inout AnyCancellable?,
        persistenceCancellables: inout Set<AnyCancellable>
    ) {
        AppStateRuntimeWiringCoordinator.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable
        )
        persistenceCancellables.removeAll()
    }
}
