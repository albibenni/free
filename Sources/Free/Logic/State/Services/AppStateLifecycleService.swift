import Combine
import Foundation

enum AppStateLifecycleService {
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

    static func applyBootstrapSnapshot(
        appState: AppState,
        snapshot: AppStateBootstrapService.Snapshot
    ) {
        appState.applySessionDomainState(
            AppSessionDomainState(
                isBlocking: snapshot.isBlocking,
                isUnblockable: snapshot.isUnblockable,
                isPaused: false,
                pauseRemaining: 0,
                wasStartedBySchedule: snapshot.wasStartedBySchedule,
                manuallyPausedScheduleIds: []
            )
        )
        appState.applySettingsDomainState(
            AppSettingsDomainState(
                weekStartsOnMonday: snapshot.weekStartsOnMonday,
                accentColorIndex: snapshot.accentColorIndex,
                appearanceMode: snapshot.appearanceMode,
                blockNewTabs: snapshot.blockNewTabs,
                blockDeveloperHosts: snapshot.blockDeveloperHosts,
                blockLocalNetworkHosts: snapshot.blockLocalNetworkHosts
            )
        )
        appState.applyPomodoroDomainState(
            AppPomodoroDomainState(
                status: .none,
                remaining: 0,
                startedAt: nil,
                focusDurationMinutes: snapshot.pomodoroFocusDuration,
                breakDurationMinutes: snapshot.pomodoroBreakDuration,
                ruleSetId: nil
            )
        )
        appState.applyRulesDomainState(
            AppRulesDomainState(
                ruleSets: snapshot.ruleSets,
                activeRuleSetId: snapshot.activeRuleSetId
            )
        )
        appState.applyScheduleDomainState(
            AppScheduleDomainState(
                schedules: snapshot.schedules,
                calendarIntegrationEnabled: snapshot.calendarIntegrationEnabled,
                calendarImportsBlockTime: snapshot.calendarImportsBlockTime,
                isSynchronizingImportedSchedules: false,
                suppressedImportedCalendarEventKeys: snapshot.suppressedImportedCalendarEventKeys
            )
        )
    }

    static func performLegacyBlockingMigrationIfNeeded(appState: AppState) {
        if let migration = appState.logicFacade.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: appState.settingsStore.hasPersistedWasStartedBySchedule(),
            current: appState.sessionState,
            schedules: appState.schedules,
            pomodoroStatus: appState.pomodoroStatus,
            calendarIntegrationEnabled: appState.calendarIntegrationEnabled,
            isUnblockable: appState.isUnblockable,
            calendarImportsBlockTime: appState.calendarImportsBlockTime,
            calendarEvents: appState.calendarProvider.events
        ) {
            appState.applySessionState(migration)
        }
    }

    static func startRuntime(
        appState: AppState,
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool
    ) -> RuntimeBindings {
        let monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injectedMonitor,
            isTesting: isTesting
        ) {
            BrowserMonitor(appState: appState)
        }

        let calendarCancellable = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: appState.calendarProvider,
            timerCoordinator: appState.timerCoordinator,
            onCalendarChange: { [weak appState] in appState?.checkSchedules() },
            onScheduleTick: { [weak appState] in appState?.checkSchedules() }
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
