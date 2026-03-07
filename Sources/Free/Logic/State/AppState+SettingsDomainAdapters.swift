import Foundation

extension AppState {
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
}
