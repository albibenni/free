import Foundation

extension AppState {
    func applyBootstrapSnapshot(_ snapshot: AppStateBootstrapService.Snapshot) {
        applySessionDomainState(
            AppSessionDomainState(
                isBlocking: snapshot.isBlocking,
                isUnblockable: snapshot.isUnblockable,
                isPaused: false,
                pauseRemaining: 0,
                wasStartedBySchedule: snapshot.wasStartedBySchedule,
                manuallyPausedScheduleIds: []
            )
        )
        applySettingsDomainState(
            AppSettingsDomainState(
                weekStartsOnMonday: snapshot.weekStartsOnMonday,
                accentColorIndex: snapshot.accentColorIndex,
                appearanceMode: snapshot.appearanceMode,
                blockNewTabs: snapshot.blockNewTabs,
                blockDeveloperHosts: snapshot.blockDeveloperHosts,
                blockLocalNetworkHosts: snapshot.blockLocalNetworkHosts
            )
        )
        applyPomodoroDomainState(
            AppPomodoroDomainState(
                status: .none,
                remaining: 0,
                startedAt: nil,
                focusDurationMinutes: snapshot.pomodoroFocusDuration,
                breakDurationMinutes: snapshot.pomodoroBreakDuration,
                ruleSetId: nil
            )
        )
        applyRulesDomainState(
            AppRulesDomainState(
                ruleSets: snapshot.ruleSets,
                activeRuleSetId: snapshot.activeRuleSetId
            )
        )
        applyScheduleDomainState(
            AppScheduleDomainState(
                schedules: snapshot.schedules,
                calendarIntegrationEnabled: snapshot.calendarIntegrationEnabled,
                calendarImportsBlockTime: snapshot.calendarImportsBlockTime,
                isSynchronizingImportedSchedules: false,
                suppressedImportedCalendarEventKeys: snapshot.suppressedImportedCalendarEventKeys
            )
        )
    }

    func performLegacyBlockingMigrationIfNeeded() {
        if let migration = logicFacade.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: settingsStore.hasPersistedWasStartedBySchedule(),
            current: sessionState,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarProvider.events
        ) {
            applySessionState(migration)
        }
    }
}
