import Foundation

struct AppSessionDomainState: Equatable {
    var isBlocking: Bool
    var isStrict: Bool
    var isPaused: Bool
    var pauseRemaining: TimeInterval
    var wasStartedBySchedule: Bool
    var manuallyPausedScheduleIds: Set<UUID>

    var pauseEngineState: PauseEngine.State {
        PauseEngine.State(isPaused: isPaused, remaining: pauseRemaining)
    }
}

struct AppPomodoroDomainState: Equatable {
    var status: PomodoroStatus
    var remaining: TimeInterval
    var startedAt: Date?
    var focusDurationMinutes: Double
    var breakDurationMinutes: Double
    var ruleSetId: UUID?

    var pomodoroEngineState: PomodoroEngine.State {
        PomodoroEngine.State(
            status: status,
            remaining: remaining,
            startedAt: startedAt,
            ruleSetId: ruleSetId
        )
    }
}

struct AppRulesDomainState: Equatable {
    var ruleSets: [RuleSet]
    var activeRuleSetId: UUID?
}

struct AppScheduleDomainState: Equatable {
    var schedules: [Schedule]
    var calendarIntegrationEnabled: Bool
    var isSynchronizingImportedSchedules: Bool
    var suppressedImportedCalendarEventKeys: Set<String>
}

struct AppSettingsDomainState: Equatable {
    var weekStartsOnMonday: Bool
    var accentColorIndex: Int
    var appearanceMode: AppearanceMode
    var cursorFluidAnimationEnabled: Bool
    var calendarImportFocusTitleRules: [String]
    var calendarImportBreakTitleRules: [String]
    var calendarImportedScheduleRuleSetId: UUID? = nil
    var blockNewTabs: Bool
    var blockDeveloperHosts: Bool
    var blockLocalNetworkHosts: Bool
    var allowSearchEngineWebsites: Bool
    var allowAIProviderWebsites: Bool
}
