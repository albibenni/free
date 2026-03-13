import Foundation

final class SettingsStore {
    enum Key {
        static let isBlocking = "IsBlocking"
        static let isUnblockable = "IsUnblockable"
        static let weekStartsOnMonday = "WeekStartsOnMonday"
        static let accentColorIndex = "AccentColorIndex"
        static let appearanceMode = "AppearanceMode"
        static let cursorFluidAnimationEnabled = "CursorFluidAnimationEnabled"
        static let calendarIntegrationEnabled = "CalendarIntegrationEnabled"
        static let calendarImportsBlockTime = "CalendarImportsBlockTime"
        static let calendarImportFocusTitleRules = "CalendarImportFocusTitleRules"
        static let calendarImportBreakTitleRules = "CalendarImportBreakTitleRules"
        static let calendarImportedScheduleRuleSetId = "CalendarImportedScheduleRuleSetId"
        static let blockNewTabs = "BlockNewTabs"
        static let blockDeveloperHosts = "BlockDeveloperHosts"
        static let blockLocalNetworkHosts = "BlockLocalNetworkHosts"
        static let allowSearchEngineWebsites = "AllowSearchEngineWebsites"
        static let allowAIProviderWebsites = "AllowAIProviderWebsites"
        static let ruleSets = "RuleSets"
        static let activeRuleSetId = "ActiveRuleSetId"
        static let schedules = "Schedules"
        static let pomodoroFocusDuration = "PomodoroFocusDuration"
        static let pomodoroBreakDuration = "PomodoroBreakDuration"
        static let wasStartedBySchedule = "WasStartedBySchedule"
        static let manualBlockingEnabled = "ManualBlockingEnabled"
        static let launchAtLoginPromptShown = "LaunchAtLoginPromptShown"
        static let suppressedImportedCalendarEventKeys = "SuppressedImportedCalendarEventKeys"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isBlocking() -> Bool { defaults.bool(forKey: Key.isBlocking) }
    func setIsBlocking(_ value: Bool) { defaults.set(value, forKey: Key.isBlocking) }

    func isUnblockable() -> Bool { defaults.bool(forKey: Key.isUnblockable) }
    func setIsUnblockable(_ value: Bool) { defaults.set(value, forKey: Key.isUnblockable) }

    func weekStartsOnMonday() -> Bool { defaults.bool(forKey: Key.weekStartsOnMonday) }
    func setWeekStartsOnMonday(_ value: Bool) { defaults.set(value, forKey: Key.weekStartsOnMonday) }

    func accentColorIndex() -> Int { defaults.integer(forKey: Key.accentColorIndex) }
    func setAccentColorIndex(_ value: Int) { defaults.set(value, forKey: Key.accentColorIndex) }

    func appearanceModeRawValue() -> String? { defaults.string(forKey: Key.appearanceMode) }
    func setAppearanceModeRawValue(_ value: String) { defaults.set(value, forKey: Key.appearanceMode) }

    func cursorFluidAnimationEnabled() -> Bool {
        guard defaults.object(forKey: Key.cursorFluidAnimationEnabled) != nil else { return true }
        return defaults.bool(forKey: Key.cursorFluidAnimationEnabled)
    }
    func setCursorFluidAnimationEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.cursorFluidAnimationEnabled)
    }

    func calendarIntegrationEnabled() -> Bool { defaults.bool(forKey: Key.calendarIntegrationEnabled) }
    func setCalendarIntegrationEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.calendarIntegrationEnabled)
    }

    func calendarImportsBlockTime() -> Bool { defaults.bool(forKey: Key.calendarImportsBlockTime) }
    func setCalendarImportsBlockTime(_ value: Bool) {
        defaults.set(value, forKey: Key.calendarImportsBlockTime)
    }

    func calendarImportFocusTitleRules() -> [String] {
        defaults.stringArray(forKey: Key.calendarImportFocusTitleRules) ?? []
    }
    func setCalendarImportFocusTitleRules(_ value: [String]) {
        defaults.set(value, forKey: Key.calendarImportFocusTitleRules)
    }

    func calendarImportBreakTitleRules() -> [String] {
        defaults.stringArray(forKey: Key.calendarImportBreakTitleRules) ?? []
    }
    func setCalendarImportBreakTitleRules(_ value: [String]) {
        defaults.set(value, forKey: Key.calendarImportBreakTitleRules)
    }

    func calendarImportedScheduleRuleSetId() -> UUID? {
        UUID(uuidString: defaults.string(forKey: Key.calendarImportedScheduleRuleSetId) ?? "")
    }
    func setCalendarImportedScheduleRuleSetId(_ value: UUID?) {
        defaults.set(value?.uuidString, forKey: Key.calendarImportedScheduleRuleSetId)
    }

    func blockNewTabs() -> Bool { defaults.bool(forKey: Key.blockNewTabs) }
    func setBlockNewTabs(_ value: Bool) { defaults.set(value, forKey: Key.blockNewTabs) }

    func blockDeveloperHosts() -> Bool { defaults.bool(forKey: Key.blockDeveloperHosts) }
    func setBlockDeveloperHosts(_ value: Bool) { defaults.set(value, forKey: Key.blockDeveloperHosts) }

    func blockLocalNetworkHosts() -> Bool { defaults.bool(forKey: Key.blockLocalNetworkHosts) }
    func setBlockLocalNetworkHosts(_ value: Bool) {
        defaults.set(value, forKey: Key.blockLocalNetworkHosts)
    }

    func allowSearchEngineWebsites() -> Bool { defaults.bool(forKey: Key.allowSearchEngineWebsites) }
    func setAllowSearchEngineWebsites(_ value: Bool) {
        defaults.set(value, forKey: Key.allowSearchEngineWebsites)
    }

    func allowAIProviderWebsites() -> Bool { defaults.bool(forKey: Key.allowAIProviderWebsites) }
    func setAllowAIProviderWebsites(_ value: Bool) {
        defaults.set(value, forKey: Key.allowAIProviderWebsites)
    }

    func activeRuleSetId() -> UUID? {
        UUID(uuidString: defaults.string(forKey: Key.activeRuleSetId) ?? "")
    }
    func setActiveRuleSetId(_ value: UUID?) {
        defaults.set(value?.uuidString, forKey: Key.activeRuleSetId)
    }

    func pomodoroFocusDuration(default defaultValue: Double) -> Double {
        let value = defaults.double(forKey: Key.pomodoroFocusDuration)
        return value == 0 ? defaultValue : value
    }
    func setPomodoroFocusDuration(_ value: Double) {
        defaults.set(value, forKey: Key.pomodoroFocusDuration)
    }

    func pomodoroBreakDuration(default defaultValue: Double) -> Double {
        let value = defaults.double(forKey: Key.pomodoroBreakDuration)
        return value == 0 ? defaultValue : value
    }
    func setPomodoroBreakDuration(_ value: Double) {
        defaults.set(value, forKey: Key.pomodoroBreakDuration)
    }

    func wasStartedBySchedule() -> Bool { defaults.bool(forKey: Key.wasStartedBySchedule) }
    func setWasStartedBySchedule(_ value: Bool) {
        defaults.set(value, forKey: Key.wasStartedBySchedule)
    }
    func hasPersistedWasStartedBySchedule() -> Bool {
        defaults.object(forKey: Key.wasStartedBySchedule) != nil
    }

    func manualBlockingEnabled() -> Bool { defaults.bool(forKey: Key.manualBlockingEnabled) }
    func setManualBlockingEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.manualBlockingEnabled)
    }

    func launchAtLoginPromptShown() -> Bool {
        defaults.bool(forKey: Key.launchAtLoginPromptShown)
    }
    func setLaunchAtLoginPromptShown(_ value: Bool) {
        defaults.set(value, forKey: Key.launchAtLoginPromptShown)
    }

    func suppressedImportedCalendarEventKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.suppressedImportedCalendarEventKeys) ?? [])
    }
    func setSuppressedImportedCalendarEventKeys(_ value: Set<String>) {
        defaults.set(Array(value).sorted(), forKey: Key.suppressedImportedCalendarEventKeys)
    }

    func saveRuleSets(_ value: [RuleSet]) {
        saveCodable(value, forKey: Key.ruleSets)
    }
    func loadRuleSets() -> [RuleSet]? {
        loadCodable(forKey: Key.ruleSets, as: [RuleSet].self)
    }

    func saveSchedules(_ value: [Schedule]) {
        saveCodable(value, forKey: Key.schedules)
    }
    func loadSchedules() -> [Schedule]? {
        loadCodable(forKey: Key.schedules, as: [Schedule].self)
    }

    func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            defaults.set(encoded, forKey: key)
        }
    }

    func loadCodable<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
