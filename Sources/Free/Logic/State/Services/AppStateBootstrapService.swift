import Foundation

struct AppStateBootstrapService {
    struct Snapshot: Equatable {
        let isBlocking: Bool
        let isUnblockable: Bool
        let weekStartsOnMonday: Bool
        let accentColorIndex: Int
        let appearanceMode: AppearanceMode
        let cursorFluidAnimationEnabled: Bool
        let calendarIntegrationEnabled: Bool
        let calendarImportsBlockTime: Bool
        let calendarImportFocusTitleRules: [String]
        let calendarImportBreakTitleRules: [String]
        let calendarImportedScheduleRuleSetId: UUID?
        let blockNewTabs: Bool
        let blockDeveloperHosts: Bool
        let blockLocalNetworkHosts: Bool
        let allowSearchEngineWebsites: Bool
        let allowAIProviderWebsites: Bool
        let pomodoroFocusDuration: Double
        let pomodoroBreakDuration: Double
        let ruleSets: [RuleSet]
        let schedules: [Schedule]
        let activeRuleSetId: UUID?
        let wasStartedBySchedule: Bool
        let manualBlockingEnabled: Bool
        let suppressedImportedCalendarEventKeys: Set<String>
    }

    static func snapshot(from settingsStore: SettingsStore) -> Snapshot {
        let appearanceMode: AppearanceMode = {
            guard let modeStr = settingsStore.appearanceModeRawValue() else { return .system }
            return AppearanceMode(rawValue: modeStr) ?? .system
        }()

        let ruleSets = settingsStore.loadRuleSets() ?? [RuleSet.defaultSet()]
        let weekStartsOnMonday = settingsStore.weekStartsOnMonday()
        let persistedSchedules = settingsStore.loadSchedules() ?? []
        let schedules = CalendarImportService.pruneSchedulesOlderThanPreviousWeek(
            schedules: persistedSchedules,
            weekStartsOnMonday: weekStartsOnMonday
        )

        return Snapshot(
            isBlocking: settingsStore.isBlocking(),
            isUnblockable: settingsStore.isUnblockable(),
            weekStartsOnMonday: weekStartsOnMonday,
            accentColorIndex: settingsStore.accentColorIndex(),
            appearanceMode: appearanceMode,
            cursorFluidAnimationEnabled: settingsStore.cursorFluidAnimationEnabled(),
            calendarIntegrationEnabled: settingsStore.calendarIntegrationEnabled(),
            calendarImportsBlockTime: settingsStore.calendarImportsBlockTime(),
            calendarImportFocusTitleRules: settingsStore.calendarImportFocusTitleRules(),
            calendarImportBreakTitleRules: settingsStore.calendarImportBreakTitleRules(),
            calendarImportedScheduleRuleSetId: settingsStore.calendarImportedScheduleRuleSetId(),
            blockNewTabs: settingsStore.blockNewTabs(),
            blockDeveloperHosts: settingsStore.blockDeveloperHosts(),
            blockLocalNetworkHosts: settingsStore.blockLocalNetworkHosts(),
            allowSearchEngineWebsites: settingsStore.allowSearchEngineWebsites(),
            allowAIProviderWebsites: settingsStore.allowAIProviderWebsites(),
            pomodoroFocusDuration: settingsStore.pomodoroFocusDuration(default: 25),
            pomodoroBreakDuration: settingsStore.pomodoroBreakDuration(default: 5),
            ruleSets: ruleSets,
            schedules: schedules,
            activeRuleSetId: settingsStore.activeRuleSetId() ?? ruleSets.first?.id,
            wasStartedBySchedule: settingsStore.wasStartedBySchedule(),
            manualBlockingEnabled: settingsStore.manualBlockingEnabled(),
            suppressedImportedCalendarEventKeys: settingsStore.suppressedImportedCalendarEventKeys()
        )
    }
}
