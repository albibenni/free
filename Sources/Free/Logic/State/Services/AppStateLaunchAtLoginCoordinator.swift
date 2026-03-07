import Foundation

enum AppStateLaunchAtLoginCoordinator {
    struct Dependencies {
        var preparePromptIfNeeded: () -> Bool
        var isEnabled: () -> Bool
        var enable: () -> Bool
        var setEnabled: (Bool) -> Bool

        static func live(service: LaunchAtLoginService) -> Dependencies {
            Dependencies(
                preparePromptIfNeeded: { service.preparePromptIfNeeded() },
                isEnabled: { service.isEnabled() },
                enable: { service.enable() },
                setEnabled: { service.setEnabled($0) }
            )
        }
    }

    static func preparePromptIfNeeded(dependencies: Dependencies) -> Bool {
        dependencies.preparePromptIfNeeded()
    }

    static func status(dependencies: Dependencies) -> Bool {
        dependencies.isEnabled()
    }

    static func enable(dependencies: Dependencies) -> Bool {
        dependencies.enable()
    }

    static func setEnabled(_ enabled: Bool, dependencies: Dependencies) -> Bool {
        dependencies.setEnabled(enabled)
    }
}
