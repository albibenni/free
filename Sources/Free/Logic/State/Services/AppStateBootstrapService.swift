import Foundation

struct AppStateBootstrapService {
    struct Snapshot: Equatable {
        let isBlocking: Bool
        let isUnblockable: Bool
        let weekStartsOnMonday: Bool
        let accentColorIndex: Int
        let appearanceMode: AppearanceMode
        let calendarIntegrationEnabled: Bool
        let calendarImportsBlockTime: Bool
        let blockNewTabs: Bool
        let blockDeveloperHosts: Bool
        let blockLocalNetworkHosts: Bool
        let pomodoroFocusDuration: Double
        let pomodoroBreakDuration: Double
        let ruleSets: [RuleSet]
        let schedules: [Schedule]
        let activeRuleSetId: UUID?
        let wasStartedBySchedule: Bool
        let suppressedImportedCalendarEventKeys: Set<String>
    }

    static func snapshot(from settingsStore: SettingsStore) -> Snapshot {
        let appearanceMode: AppearanceMode = {
            guard let modeStr = settingsStore.appearanceModeRawValue() else { return .system }
            return AppearanceMode(rawValue: modeStr) ?? .system
        }()

        let ruleSets = settingsStore.loadRuleSets() ?? [RuleSet.defaultSet()]

        return Snapshot(
            isBlocking: settingsStore.isBlocking(),
            isUnblockable: settingsStore.isUnblockable(),
            weekStartsOnMonday: settingsStore.weekStartsOnMonday(),
            accentColorIndex: settingsStore.accentColorIndex(),
            appearanceMode: appearanceMode,
            calendarIntegrationEnabled: settingsStore.calendarIntegrationEnabled(),
            calendarImportsBlockTime: settingsStore.calendarImportsBlockTime(),
            blockNewTabs: settingsStore.blockNewTabs(),
            blockDeveloperHosts: settingsStore.blockDeveloperHosts(),
            blockLocalNetworkHosts: settingsStore.blockLocalNetworkHosts(),
            pomodoroFocusDuration: settingsStore.pomodoroFocusDuration(default: 25),
            pomodoroBreakDuration: settingsStore.pomodoroBreakDuration(default: 5),
            ruleSets: ruleSets,
            schedules: settingsStore.loadSchedules() ?? [],
            activeRuleSetId: settingsStore.activeRuleSetId() ?? ruleSets.first?.id,
            wasStartedBySchedule: settingsStore.wasStartedBySchedule(),
            suppressedImportedCalendarEventKeys: settingsStore.suppressedImportedCalendarEventKeys()
        )
    }
}
