import ServiceManagement
import Testing

@testable import FreeLogic

struct LaunchAtLoginManagerTests {
    @Test("DefaultLaunchAtLoginManager isEnabled mirrors runtime status")
    func isEnabledFromRuntimeStatus() {
        let enabledManager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .enabled },
                register: {},
                unregister: {}
            )
        )
        #expect(enabledManager.isEnabled == true)

        let disabledManager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .notRegistered },
                register: {},
                unregister: {}
            )
        )
        #expect(disabledManager.isEnabled == false)
    }

    @Test("DefaultLaunchAtLoginManager enable delegates to runtime register")
    func enableDelegatesToRuntimeRegister() throws {
        final class Box {
            var registerCallCount = 0
        }
        let box = Box()
        let manager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .notRegistered },
                register: {
                    box.registerCallCount += 1
                },
                unregister: {}
            )
        )

        try manager.enable()
        #expect(box.registerCallCount == 1)
    }

    @Test("DefaultLaunchAtLoginManager disable delegates to runtime unregister")
    func disableDelegatesToRuntimeUnregister() throws {
        final class Box {
            var unregisterCallCount = 0
        }
        let box = Box()
        let manager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .enabled },
                register: {},
                unregister: {
                    box.unregisterCallCount += 1
                }
            )
        )

        try manager.disable()
        #expect(box.unregisterCallCount == 1)
    }
}
