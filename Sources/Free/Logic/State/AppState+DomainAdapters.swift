import Foundation

extension AppState {
    var wasStartedBySchedule: Bool {
        get { internalState.wasStartedBySchedule }
        set { internalState.wasStartedBySchedule = newValue }
    }

    var manuallyPausedScheduleIds: Set<UUID> {
        get { internalState.manuallyPausedScheduleIds }
        set { internalState.manuallyPausedScheduleIds = newValue }
    }

    var pomodoroRuleSetId: UUID? {
        get { internalState.pomodoroRuleSetId }
        set { internalState.pomodoroRuleSetId = newValue }
    }

    var isSynchronizingImportedSchedules: Bool {
        get { internalState.isSynchronizingImportedSchedules }
        set { internalState.isSynchronizingImportedSchedules = newValue }
    }

    var suppressedImportedCalendarEventKeys: Set<String> {
        get { internalState.suppressedImportedCalendarEventKeys }
        set { internalState.suppressedImportedCalendarEventKeys = newValue }
    }

    func setWasStartedBySchedule(_ value: Bool) {
        wasStartedBySchedule = value
        settingsStore.setWasStartedBySchedule(value)
    }

    var sessionState: AppStateLogicFacade.SessionState {
        logicFacade.makeSessionState(
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule,
            manuallyPausedScheduleIds: sessionDomainState.manuallyPausedScheduleIds
        )
    }

    func applySessionState(_ state: AppStateLogicFacade.SessionState) {
        manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        if state.isBlocking != isBlocking {
            isBlocking = state.isBlocking
        }
        if state.wasStartedBySchedule != wasStartedBySchedule {
            setWasStartedBySchedule(state.wasStartedBySchedule)
        }
    }

    func applyPauseEngineState(_ state: PauseEngine.State) {
        var domainState = sessionDomainState
        domainState.isPaused = state.isPaused
        domainState.pauseRemaining = state.remaining
        applySessionDomainState(domainState)
    }

    var pomodoroEngineState: PomodoroEngine.State {
        pomodoroDomainState.pomodoroEngineState
    }

    var ruleContext: AppStateLogicFacade.RuleContext {
        logicFacade.makeRuleContext(
            ruleSets: rulesDomainState.ruleSets,
            schedules: scheduleDomainState.schedules,
            activeRuleSetId: rulesDomainState.activeRuleSetId,
            pomodoroRuleSetId: pomodoroDomainState.ruleSetId,
            isPomodoroFocus: pomodoroDomainState.status == .focus,
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule
        )
    }

    func applyPomodoroEngineState(_ state: PomodoroEngine.State) {
        var domainState = pomodoroDomainState
        domainState.status = state.status
        domainState.remaining = state.remaining
        domainState.startedAt = state.startedAt
        domainState.ruleSetId = state.ruleSetId
        applyPomodoroDomainState(domainState)
    }

    var sessionDomainState: AppSessionDomainState {
        AppSessionDomainState(
            isBlocking: isBlocking,
            isUnblockable: isUnblockable,
            isPaused: isPaused,
            pauseRemaining: pauseRemaining,
            wasStartedBySchedule: wasStartedBySchedule,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds
        )
    }

    func applySessionDomainState(_ state: AppSessionDomainState) {
        if isBlocking != state.isBlocking { isBlocking = state.isBlocking }
        if isUnblockable != state.isUnblockable { isUnblockable = state.isUnblockable }
        if isPaused != state.isPaused { isPaused = state.isPaused }
        if pauseRemaining != state.pauseRemaining { pauseRemaining = state.pauseRemaining }
        if wasStartedBySchedule != state.wasStartedBySchedule {
            wasStartedBySchedule = state.wasStartedBySchedule
        }
        if manuallyPausedScheduleIds != state.manuallyPausedScheduleIds {
            manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        }
    }

    var settingsDomainState: AppSettingsDomainState {
        AppSettingsDomainState(
            weekStartsOnMonday: weekStartsOnMonday,
            accentColorIndex: accentColorIndex,
            appearanceMode: appearanceMode,
            blockNewTabs: blockNewTabs,
            blockDeveloperHosts: blockDeveloperHosts,
            blockLocalNetworkHosts: blockLocalNetworkHosts
        )
    }

    func applySettingsDomainState(_ state: AppSettingsDomainState) {
        if weekStartsOnMonday != state.weekStartsOnMonday {
            weekStartsOnMonday = state.weekStartsOnMonday
        }
        if accentColorIndex != state.accentColorIndex { accentColorIndex = state.accentColorIndex }
        if appearanceMode != state.appearanceMode { appearanceMode = state.appearanceMode }
        if blockNewTabs != state.blockNewTabs { blockNewTabs = state.blockNewTabs }
        if blockDeveloperHosts != state.blockDeveloperHosts {
            blockDeveloperHosts = state.blockDeveloperHosts
        }
        if blockLocalNetworkHosts != state.blockLocalNetworkHosts {
            blockLocalNetworkHosts = state.blockLocalNetworkHosts
        }
    }

    var rulesDomainState: AppRulesDomainState {
        AppRulesDomainState(ruleSets: ruleSets, activeRuleSetId: activeRuleSetId)
    }

    func applyRulesDomainState(_ state: AppRulesDomainState) {
        if ruleSets != state.ruleSets { ruleSets = state.ruleSets }
        if activeRuleSetId != state.activeRuleSetId { activeRuleSetId = state.activeRuleSetId }
    }

    var scheduleDomainState: AppScheduleDomainState {
        AppScheduleDomainState(
            schedules: schedules,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            calendarImportsBlockTime: calendarImportsBlockTime,
            isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    func applyScheduleDomainState(_ state: AppScheduleDomainState) {
        if schedules != state.schedules { schedules = state.schedules }
        if calendarIntegrationEnabled != state.calendarIntegrationEnabled {
            calendarIntegrationEnabled = state.calendarIntegrationEnabled
        }
        if calendarImportsBlockTime != state.calendarImportsBlockTime {
            calendarImportsBlockTime = state.calendarImportsBlockTime
        }
        if isSynchronizingImportedSchedules != state.isSynchronizingImportedSchedules {
            isSynchronizingImportedSchedules = state.isSynchronizingImportedSchedules
        }
        if suppressedImportedCalendarEventKeys != state.suppressedImportedCalendarEventKeys {
            suppressedImportedCalendarEventKeys = state.suppressedImportedCalendarEventKeys
        }
    }

    var pomodoroDomainState: AppPomodoroDomainState {
        AppPomodoroDomainState(
            status: pomodoroStatus,
            remaining: pomodoroRemaining,
            startedAt: pomodoroStartedAt,
            focusDurationMinutes: pomodoroFocusDuration,
            breakDurationMinutes: pomodoroBreakDuration,
            ruleSetId: pomodoroRuleSetId
        )
    }

    func applyPomodoroDomainState(_ state: AppPomodoroDomainState) {
        if pomodoroStatus != state.status { pomodoroStatus = state.status }
        if pomodoroRemaining != state.remaining { pomodoroRemaining = state.remaining }
        if pomodoroStartedAt != state.startedAt { pomodoroStartedAt = state.startedAt }
        if pomodoroFocusDuration != state.focusDurationMinutes {
            pomodoroFocusDuration = state.focusDurationMinutes
        }
        if pomodoroBreakDuration != state.breakDurationMinutes {
            pomodoroBreakDuration = state.breakDurationMinutes
        }
        if pomodoroRuleSetId != state.ruleSetId { pomodoroRuleSetId = state.ruleSetId }
    }
}
