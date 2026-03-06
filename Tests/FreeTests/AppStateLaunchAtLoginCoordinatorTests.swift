import Testing

@testable import FreeLogic

struct AppStateLaunchAtLoginCoordinatorTests {
    @Test("preparePromptIfNeeded delegates and returns dependency result")
    func preparePromptDelegates() {
        var called = false
        let deps = AppStateLaunchAtLoginCoordinator.Dependencies(
            preparePromptIfNeeded: {
                called = true
                return true
            },
            isEnabled: { false },
            enable: { false },
            setEnabled: { _ in false }
        )

        let result = AppStateLaunchAtLoginCoordinator.preparePromptIfNeeded(
            dependencies: deps
        )
        #expect(called)
        #expect(result)
    }

    @Test("status and enable delegate to dependency closures")
    func statusAndEnableDelegate() {
        var statusCalled = false
        var enableCalled = false
        let deps = AppStateLaunchAtLoginCoordinator.Dependencies(
            preparePromptIfNeeded: { false },
            isEnabled: {
                statusCalled = true
                return true
            },
            enable: {
                enableCalled = true
                return true
            },
            setEnabled: { _ in false }
        )

        #expect(AppStateLaunchAtLoginCoordinator.status(dependencies: deps))
        #expect(AppStateLaunchAtLoginCoordinator.enable(dependencies: deps))
        #expect(statusCalled)
        #expect(enableCalled)
    }

    @Test("setEnabled forwards the boolean parameter")
    func setEnabledForwardsParameter() {
        var captured = false
        let deps = AppStateLaunchAtLoginCoordinator.Dependencies(
            preparePromptIfNeeded: { false },
            isEnabled: { false },
            enable: { false },
            setEnabled: {
                captured = $0
                return true
            }
        )

        let result = AppStateLaunchAtLoginCoordinator.setEnabled(
            true,
            dependencies: deps
        )
        #expect(result)
        #expect(captured)
    }
}
