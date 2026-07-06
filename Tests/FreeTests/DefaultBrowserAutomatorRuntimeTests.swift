import Testing
import Foundation
import AppKit
@testable import FreeLogic

private final class BrowserAutomatorRuntimeBridgeState {
    var permissionPrompts: [Bool] = []
    var permissionResult = false

    var scriptSources: [String] = []
    var scriptResult: String?

    var runningAppsCalls = 0
    var runningApps: [NSRunningApplication] = []

    var arcPIDs: [pid_t] = []
    var arcResult: String?

    func makeBridge() -> DefaultBrowserAutomatorRuntimeBridge {
        DefaultBrowserAutomatorRuntimeBridge(
            checkPermissions: { [weak self] prompt in
                self?.permissionPrompts.append(prompt)
                return self?.permissionResult ?? false
            },
            executeAppleScript: { [weak self] source in
                self?.scriptSources.append(source)
                return self?.scriptResult
            },
            runningApplications: { [weak self] in
                guard let self else { return [] }
                self.runningAppsCalls += 1
                return self.runningApps
            },
            arcAccessibilityURL: { [weak self] pid in
                self?.arcPIDs.append(pid)
                return self?.arcResult
            }
        )
    }
}

@Suite(.serialized)
@MainActor
struct DefaultBrowserAutomatorRuntimeTests {
    @Test("live(bridge:) forwards all runtime calls")
    func liveBridgeForwarding() async throws {
        let state = BrowserAutomatorRuntimeBridgeState()
        state.permissionResult = true
        state.scriptResult = "script-result"
        state.arcResult = "arc-url"
        let currentApp = NSRunningApplication.current
        state.runningApps = [currentApp]

        let runtime = DefaultBrowserAutomatorRuntime.live(bridge: state.makeBridge())

        let permissions = runtime.checkPermissions(true)
        let script = runtime.executeAppleScript("return \"ok\"")
        let mapped = runtime.runningApplications()
        let arc = runtime.arcAccessibilityURL(987)

        #expect(permissions == true)
        #expect(script == "script-result")
        #expect(state.permissionPrompts == [true])
        #expect(state.scriptSources == ["return \"ok\""])
        #expect(state.runningAppsCalls == 1)
        #expect(mapped.count == 1)
        #expect(mapped[0].bundleIdentifier == currentApp.bundleIdentifier)
        #expect(mapped[0].localizedName == currentApp.localizedName)
        #expect(mapped[0].processIdentifier == currentApp.processIdentifier)
        #expect(arc == "arc-url")
        #expect(state.arcPIDs == [987])
    }

    @Test("mapRunningApplication preserves key NSRunningApplication properties")
    func mapRunningApplicationProperties() async throws {
        let app = NSRunningApplication.current
        let mapped = DefaultBrowserAutomatorRuntime.mapRunningApplication(app)

        #expect(mapped.bundleIdentifier == app.bundleIdentifier)
        #expect(mapped.localizedName == app.localizedName)
        #expect(mapped.processIdentifier == app.processIdentifier)
    }

    @Test("live() can be constructed and invoked on all closures")
    func liveDefaultBridgePath() async throws {
        let runtime = DefaultBrowserAutomatorRuntime.live()

        _ = runtime.checkPermissions(false)
        _ = runtime.executeAppleScript("return \"hello\"")
        let applications = runtime.runningApplications()
        let arcURL = runtime.arcAccessibilityURL(0)

        #expect(applications.count >= 0)
        #expect(arcURL == nil || !arcURL!.isEmpty)
    }
}
