import Foundation
import AppKit

struct DefaultBrowserAutomatorRuntimeBridge {
    var checkPermissions: (_ prompt: Bool) -> Bool
    var executeAppleScript: (_ source: String) -> String?
    var runningApplications: () -> [NSRunningApplication]
    var arcAccessibilityURL: (_ pid: pid_t) -> String?
}

extension DefaultBrowserAutomatorRuntime {
    static func live() -> DefaultBrowserAutomatorRuntime {
        live(bridge: .liveSystem())
    }

    static func live(bridge: DefaultBrowserAutomatorRuntimeBridge) -> DefaultBrowserAutomatorRuntime {
        DefaultBrowserAutomatorRuntime(
            checkPermissions: { prompt in
                bridge.checkPermissions(prompt)
            },
            executeAppleScript: { source in
                bridge.executeAppleScript(source)
            },
            runningApplications: {
                bridge.runningApplications().map(mapRunningApplication)
            },
            arcAccessibilityURL: { pid in
                bridge.arcAccessibilityURL(pid)
            }
        )
    }

    static func mapRunningApplication(_ app: NSRunningApplication) -> BrowserAutomationApplication {
        BrowserAutomationApplication(
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName,
            processIdentifier: app.processIdentifier
        )
    }
}
