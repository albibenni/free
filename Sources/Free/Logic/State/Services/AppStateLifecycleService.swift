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
    }

    static func bindPersistence(
        appState: AppState,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        AppStatePersistenceCoordinator.bind(
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
            isUnblockable: snapshot.isUnblockable,
            isPaused: false,
            pauseRemaining: 0,
            wasStartedBySchedule: snapshot.wasStartedBySchedule,
            manuallyPausedScheduleIds: []
        ),
            settings: AppSettingsDomainState(
            weekStartsOnMonday: snapshot.weekStartsOnMonday,
            accentColorIndex: snapshot.accentColorIndex,
            appearanceMode: snapshot.appearanceMode,
            blockNewTabs: snapshot.blockNewTabs,
            blockDeveloperHosts: snapshot.blockDeveloperHosts,
            blockLocalNetworkHosts: snapshot.blockLocalNetworkHosts
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
            calendarImportsBlockTime: snapshot.calendarImportsBlockTime,
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
        pomodoroStatus: AppState.PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isUnblockable: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> AppStateLogicFacade.SessionState? {
        logicFacade.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: hasPersistedWasStartedBySchedule,
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )
    }

    static func startRuntime(
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool,
        calendarProvider: any CalendarProvider,
        timerCoordinator: AppStateTimerCoordinator,
        buildMonitor: () -> BrowserMonitor,
        onScheduleUpdate: @escaping () -> Void
    ) -> RuntimeBindings {
        let monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injectedMonitor,
            isTesting: isTesting
        ) { buildMonitor() }

        let calendarCancellable = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: calendarProvider,
            timerCoordinator: timerCoordinator,
            onCalendarChange: onScheduleUpdate,
            onScheduleTick: onScheduleUpdate
        )

        return RuntimeBindings(
            monitor: monitor,
            calendarCancellable: calendarCancellable
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
