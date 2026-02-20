import Testing
import Foundation
import AppKit
@testable import FreeLogic

private final class BrowserAutomatorRuntimeState {
    var permissionCalls: [Bool] = []
    var scriptCalls: [String] = []
    var scriptResults: [String?] = []
    var applications: [BrowserAutomationApplication] = []
    var arcFallbackURL: String?
    var arcFallbackPIDs: [pid_t] = []

    func makeRuntime() -> DefaultBrowserAutomatorRuntime {
        DefaultBrowserAutomatorRuntime(
            checkPermissions: { [weak self] prompt in
                self?.permissionCalls.append(prompt)
                return prompt
            },
            executeAppleScript: { [weak self] source in
                self?.scriptCalls.append(source)
                guard let self else { return nil }
                if self.scriptResults.isEmpty { return nil }
                return self.scriptResults.removeFirst()
            },
            runningApplications: { [weak self] in
                self?.applications ?? []
            },
            arcAccessibilityURL: { [weak self] pid in
                self?.arcFallbackPIDs.append(pid)
                return self?.arcFallbackURL
            }
        )
    }
}

@Suite(.serialized)
struct DefaultBrowserAutomatorTests {
    @Test("checkPermissions forwards prompt flag to runtime")
    func checkPermissionsForwardsPrompt() {
        let state = BrowserAutomatorRuntimeState()
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let first = automator.checkPermissions(prompt: false)
        let second = automator.checkPermissions(prompt: true)

        #expect(first == false)
        #expect(second == true)
        #expect(state.permissionCalls == [false, true])
    }

    @Test("redirect selects Arc AppleScript for Arc bundle")
    func redirectArcScript() {
        let state = BrowserAutomatorRuntimeState()
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())
        automator.redirect(bundleIdentifier: DefaultBrowserAutomator.arcBundleIdentifier, localizedName: "Arc", to: "https://example.com")

        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0].contains("tell application \"Arc\""))
        #expect(state.scriptCalls[0].contains("https://example.com"))
    }

    @Test("redirect selects Safari script when bundle is Safari or missing")
    func redirectSafariScript() {
        let state = BrowserAutomatorRuntimeState()
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())
        automator.redirect(bundleIdentifier: DefaultBrowserAutomator.safariBundleIdentifier, localizedName: "Safari", to: "https://apple.com")
        automator.redirect(bundleIdentifier: nil, localizedName: nil, to: "https://fallback.com")

        #expect(state.scriptCalls.count == 2)
        #expect(state.scriptCalls[0].contains("tell application \"Safari\""))
        #expect(state.scriptCalls[1].contains("tell application \"Safari\""))
    }

    @Test("redirect selects Chromium-style script for non-Safari browsers")
    func redirectChromiumScript() {
        let state = BrowserAutomatorRuntimeState()
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())
        automator.redirect(bundleIdentifier: "com.google.Chrome", localizedName: "Google Chrome", to: "https://chromium.dev")

        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0].contains("tell application \"Google Chrome\""))
        #expect(state.scriptCalls[0].contains("active tab"))
    }

    @Test("getActiveUrl for Arc returns AppleScript result when non-empty")
    func activeURLArcAppleScriptPath() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = ["https://arc.example"]
        state.arcFallbackURL = "https://fallback.example"
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let result = automator.getActiveUrl(
            bundleIdentifier: DefaultBrowserAutomator.arcBundleIdentifier,
            localizedName: "Arc",
            pid: 42
        )

        #expect(result == "https://arc.example")
        #expect(state.arcFallbackPIDs.isEmpty)
        #expect(state.scriptCalls == [DefaultBrowserAutomator.arcActiveURLScript])
    }

    @Test("getActiveUrl for Arc falls back to Accessibility when AppleScript is empty")
    func activeURLArcAccessibilityFallback() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = [""]
        state.arcFallbackURL = "https://accessibility.example"
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let result = automator.getActiveUrl(
            bundleIdentifier: DefaultBrowserAutomator.arcBundleIdentifier,
            localizedName: "Arc",
            pid: 101
        )

        #expect(result == "https://accessibility.example")
        #expect(state.arcFallbackPIDs == [101])
        #expect(state.scriptCalls == [DefaultBrowserAutomator.arcActiveURLScript])
    }

    @Test("getActiveUrl uses Safari command for Safari")
    func activeURLSafariPath() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = ["https://safari.example"]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let result = automator.getActiveUrl(
            bundleIdentifier: DefaultBrowserAutomator.safariBundleIdentifier,
            localizedName: "Safari",
            pid: 1
        )

        #expect(result == "https://safari.example")
        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0] == "tell application \"Safari\" to return URL of current tab of front window")
    }

    @Test("getActiveUrl uses generic active-tab command for non-Safari browsers")
    func activeURLGenericPath() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = ["https://generic.example"]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let result = automator.getActiveUrl(
            bundleIdentifier: "com.google.Chrome",
            localizedName: "Google Chrome",
            pid: 2
        )

        #expect(result == "https://generic.example")
        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0].contains("tell application \"Google Chrome\""))
    }

    @Test("getActiveUrl falls back to Safari app name when localizedName is missing")
    func activeURLMissingLocalizedName() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = ["https://missing-name.example"]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let result = automator.getActiveUrl(
            bundleIdentifier: "com.google.Chrome",
            localizedName: nil,
            pid: 11
        )

        #expect(result == "https://missing-name.example")
        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0].contains("tell application \"Safari\" to return URL of active tab of front window"))
    }

    @Test("getAllOpenUrls filters unsupported apps, localhost page, empties, and duplicates")
    func allOpenURLsFilteringAndSorting() {
        let state = BrowserAutomatorRuntimeState()
        state.applications = [
            BrowserAutomationApplication(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari",
                processIdentifier: 1
            ),
            BrowserAutomationApplication(
                bundleIdentifier: DefaultBrowserAutomator.arcBundleIdentifier,
                localizedName: "Arc",
                processIdentifier: 2
            ),
            BrowserAutomationApplication(
                bundleIdentifier: "com.unsupported.App",
                localizedName: "Unsupported",
                processIdentifier: 3
            )
        ]
        state.scriptResults = [
            "https://z.com\nhttps://localhost:10000\n\nhttps://a.com",
            "https://a.com\nhttps://b.com\n"
        ]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let urls = automator.getAllOpenUrls(
            applications: state.applications,
            browsers: Set(["com.apple.Safari", DefaultBrowserAutomator.arcBundleIdentifier])
        )

        #expect(urls == ["https://a.com", "https://b.com", "https://z.com"])
        #expect(state.scriptCalls.count == 2)
        #expect(state.scriptCalls[0].contains("tell application \"Safari\""))
        #expect(state.scriptCalls[1].contains("tell application \"Arc\""))
    }

    @Test("getAllOpenUrls wrapper uses runtime-provided app list")
    func allOpenURLsWrapper() {
        let state = BrowserAutomatorRuntimeState()
        state.applications = [
            BrowserAutomationApplication(
                bundleIdentifier: "com.google.Chrome",
                localizedName: "Google Chrome",
                processIdentifier: 1
            )
        ]
        state.scriptResults = ["https://docs.example\n"]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let urls = automator.getAllOpenUrls(browsers: ["com.google.Chrome"])

        #expect(urls == ["https://docs.example"])
    }

    @Test("getAllOpenUrls handles supported apps with missing localizedName")
    func allOpenURLsMissingLocalizedName() {
        let state = BrowserAutomatorRuntimeState()
        state.applications = [
            BrowserAutomationApplication(
                bundleIdentifier: "com.google.Chrome",
                localizedName: nil,
                processIdentifier: 7
            )
        ]
        state.scriptResults = ["https://fallback-name.example\n"]
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        let urls = automator.getAllOpenUrls(
            applications: state.applications,
            browsers: Set(["com.google.Chrome"])
        )

        #expect(urls == ["https://fallback-name.example"])
        #expect(state.scriptCalls.count == 1)
        #expect(state.scriptCalls[0].contains("tell application \"\""))
    }

    @Test("helper functions cover script mappings and parsing edge cases")
    func helperFunctions() {
        let state = BrowserAutomatorRuntimeState()
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())

        #expect(automator.scriptAppName(bundleIdentifier: DefaultBrowserAutomator.safariBundleIdentifier, localizedName: "X") == "Safari")
        #expect(automator.scriptAppName(bundleIdentifier: DefaultBrowserAutomator.arcBundleIdentifier, localizedName: "X") == "Arc")
        #expect(automator.scriptAppName(bundleIdentifier: "com.google.Chrome", localizedName: "Google Chrome") == "Google Chrome")

        #expect(automator.parseScriptOutput(nil).isEmpty)
        #expect(automator.parseScriptOutput("  \nhttps://localhost:10000\nhttps://ok.example\n").count == 1)
        #expect(automator.activeURLScript(bundleIdentifier: DefaultBrowserAutomator.safariBundleIdentifier, appName: "Safari").contains("current tab"))
        #expect(automator.activeURLScript(bundleIdentifier: "com.brave.Browser", appName: "Brave").contains("active tab"))
        #expect(automator.allTabsScript(appName: "Safari").contains("repeat with t in tabs of w"))
        #expect(automator.arcRedirect("https://arc").contains("tell application \"Arc\""))
        #expect(automator.safariRedirect("https://safari").contains("tell application \"Safari\""))
        #expect(automator.chromRedirect("Chrome", "https://chrome").contains("tell application \"Chrome\""))
    }

    @Test("NSRunningApplication protocol wrappers can execute")
    func runningApplicationWrappers() {
        let state = BrowserAutomatorRuntimeState()
        state.scriptResults = ["ignored", "https://wrapper.example"]
        state.arcFallbackURL = "https://fallback.example"
        let automator = DefaultBrowserAutomator(runtime: state.makeRuntime())
        let currentApp = NSRunningApplication.current

        automator.redirect(app: currentApp, to: "https://redirect.example")
        let currentURL = automator.getActiveUrl(for: currentApp)

        #expect(state.scriptCalls.count >= 2)
        #expect(currentURL == "https://wrapper.example" || currentURL == "https://fallback.example")
    }
}
