import Foundation
import ServiceManagement
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct LaunchAtLoginManagerTests {
    private struct DummyError: Error {}

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

    @Test("DefaultLaunchAtLoginManager rethrows enable/disable runtime errors")
    func enableDisableRethrowRuntimeFailures() {
        let enableManager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .notRegistered },
                register: { throw DummyError() },
                unregister: {}
            )
        )
        #expect(throws: DummyError.self) {
            try enableManager.enable()
        }

        let disableManager = DefaultLaunchAtLoginManager(
            runtime: .init(
                status: { .enabled },
                register: {},
                unregister: { throw DummyError() }
            )
        )
        #expect(throws: DummyError.self) {
            try disableManager.disable()
        }
    }

    @Test("DefaultLaunchAtLoginManager live runtime can be constructed safely")
    func liveRuntimeClosuresInvocable() {
        if ProcessInfo.processInfo.environment["FREE_COVERAGE_MODE"] == "1" {
            // ServiceManagement calls can crash swiftpm-testing-helper under coverage.
            #expect(Bool(true))
            return
        }

        let runtime = DefaultLaunchAtLoginManager.Runtime.live
        // Avoid mutating login items in automated tests.
        _ = runtime.status()

        #expect(Bool(true))
    }
}
