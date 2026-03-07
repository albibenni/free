import Foundation

extension AppStateLogicFacade {
    func prepareLaunchAtLoginPromptIfNeeded(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.preparePromptIfNeeded(
            dependencies: .live(service: service)
        )
    }

    func launchAtLoginStatus(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.status(
            dependencies: .live(service: service)
        )
    }

    func enableLaunchAtLogin(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.enable(
            dependencies: .live(service: service)
        )
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool, service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.setEnabled(
            enabled,
            dependencies: .live(service: service)
        )
    }
}
