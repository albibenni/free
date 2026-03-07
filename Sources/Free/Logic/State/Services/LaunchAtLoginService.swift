import Foundation

struct LaunchAtLoginService {
    private let canPromptForLaunchAtLogin: () -> Bool
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let settingsStore: SettingsStore

    init(
        launchAtLoginManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager(),
        settingsStore: SettingsStore,
        canPromptForLaunchAtLogin: @escaping () -> Bool = {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        }
    ) {
        self.canPromptForLaunchAtLogin = canPromptForLaunchAtLogin
        self.launchAtLoginManager = launchAtLoginManager
        self.settingsStore = settingsStore
    }

    @discardableResult
    func preparePromptIfNeeded() -> Bool {
        guard canPromptForLaunchAtLogin() else { return false }
        if settingsStore.launchAtLoginPromptShown() {
            return false
        }

        settingsStore.setLaunchAtLoginPromptShown(true)
        return !launchAtLoginManager.isEnabled
    }

    func isEnabled() -> Bool {
        launchAtLoginManager.isEnabled
    }

    @discardableResult
    func enable() -> Bool {
        do {
            try launchAtLoginManager.enable()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return enable()
        }

        do {
            try launchAtLoginManager.disable()
            return true
        } catch {
            return false
        }
    }
}
