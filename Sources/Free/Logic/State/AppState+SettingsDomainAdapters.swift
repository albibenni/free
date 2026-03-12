import Foundation

extension AppState {
    var settingsDomainState: AppSettingsDomainState {
        AppSettingsDomainState(
            weekStartsOnMonday: weekStartsOnMonday,
            accentColorIndex: accentColorIndex,
            appearanceMode: appearanceMode,
            calendarImportFocusTitleRules: calendarImportFocusTitleRules,
            calendarImportBreakTitleRules: calendarImportBreakTitleRules,
            calendarImportedScheduleRuleSetId: calendarImportedScheduleRuleSetId,
            blockNewTabs: blockNewTabs,
            blockDeveloperHosts: blockDeveloperHosts,
            blockLocalNetworkHosts: blockLocalNetworkHosts,
            allowSearchEngineWebsites: allowSearchEngineWebsites,
            allowAIProviderWebsites: allowAIProviderWebsites
        )
    }

    func applySettingsDomainState(_ state: AppSettingsDomainState) {
        if weekStartsOnMonday != state.weekStartsOnMonday {
            weekStartsOnMonday = state.weekStartsOnMonday
        }
        if accentColorIndex != state.accentColorIndex { accentColorIndex = state.accentColorIndex }
        if appearanceMode != state.appearanceMode { appearanceMode = state.appearanceMode }
        if calendarImportFocusTitleRules != state.calendarImportFocusTitleRules {
            calendarImportFocusTitleRules = state.calendarImportFocusTitleRules
        }
        if calendarImportBreakTitleRules != state.calendarImportBreakTitleRules {
            calendarImportBreakTitleRules = state.calendarImportBreakTitleRules
        }
        if calendarImportedScheduleRuleSetId != state.calendarImportedScheduleRuleSetId {
            calendarImportedScheduleRuleSetId = state.calendarImportedScheduleRuleSetId
        }
        if blockNewTabs != state.blockNewTabs { blockNewTabs = state.blockNewTabs }
        if blockDeveloperHosts != state.blockDeveloperHosts {
            blockDeveloperHosts = state.blockDeveloperHosts
        }
        if blockLocalNetworkHosts != state.blockLocalNetworkHosts {
            blockLocalNetworkHosts = state.blockLocalNetworkHosts
        }
        if allowSearchEngineWebsites != state.allowSearchEngineWebsites {
            allowSearchEngineWebsites = state.allowSearchEngineWebsites
        }
        if allowAIProviderWebsites != state.allowAIProviderWebsites {
            allowAIProviderWebsites = state.allowAIProviderWebsites
        }
    }
}
