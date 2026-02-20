import Testing
import Foundation
import AppKit
import ApplicationServices
@testable import FreeLogic

private final class FakeAXElement: NSObject {}

private final class FakeAXState {
    var appByPID: [pid_t: FakeAXElement] = [:]
    var attributes: [ObjectIdentifier: [String: (AXError, Any?)]] = [:]
    var requested: [(ObjectIdentifier, String)] = []

    func setAttribute(_ element: FakeAXElement, _ attribute: CFString, result: (AXError, Any?)) {
        let key = ObjectIdentifier(element)
        var map = attributes[key] ?? [:]
        map[attribute as String] = result
        attributes[key] = map
    }

    func makeAPI() -> DefaultBrowserAutomatorAXAPI {
        DefaultBrowserAutomatorAXAPI(
            makeApplication: { [weak self] pid in
                if let app = self?.appByPID[pid] {
                    return app
                }
                return FakeAXElement()
            },
            copyAttribute: { [weak self] element, attribute in
                guard let self, let fake = element as? FakeAXElement else {
                    return (.invalidUIElement, nil)
                }
                let id = ObjectIdentifier(fake)
                self.requested.append((id, attribute as String))
                return self.attributes[id]?[attribute as String] ?? (.attributeUnsupported, nil)
            }
        )
    }
}

@Suite(.serialized)
struct DefaultBrowserAutomatorSystemBridgeTests {
    @Test("liveSystem(dependencies:) forwards dependency closures")
    func bridgeDependencyForwarding() {
        var promptCalls: [Bool] = []
        var scriptCalls: [String] = []
        var runningCalls = 0
        let running = [NSRunningApplication.current]

        let axState = FakeAXState()
        let app = FakeAXElement()
        let focused = FakeAXElement()
        axState.appByPID[77] = app
        axState.setAttribute(app, kAXFocusedWindowAttribute as CFString, result: (.success, focused))
        axState.setAttribute(focused, kAXRoleAttribute as CFString, result: (.success, "AXTextField"))
        axState.setAttribute(focused, kAXTitleAttribute as CFString, result: (.success, ""))
        axState.setAttribute(focused, kAXValueAttribute as CFString, result: (.success, "https://focused.example"))

        let dependencies = DefaultBrowserAutomatorSystemDependencies(
            checkPermissions: { prompt in
                promptCalls.append(prompt)
                return true
            },
            executeAppleScript: { source in
                scriptCalls.append(source)
                return "script-result"
            },
            runningApplications: {
                runningCalls += 1
                return running
            },
            axAPI: axState.makeAPI()
        )

        let bridge = DefaultBrowserAutomatorRuntimeBridge.liveSystem(dependencies: dependencies)

        #expect(bridge.checkPermissions(true) == true)
        #expect(bridge.executeAppleScript("return 1") == "script-result")
        #expect(bridge.runningApplications().count == 1)
        #expect(bridge.arcAccessibilityURL(77) == "https://focused.example")
        #expect(promptCalls == [true])
        #expect(scriptCalls == ["return 1"])
        #expect(runningCalls == 1)
    }

    @Test("arcURL uses focused window URL before windows fallback")
    func arcURLFocusedWindowPreferred() {
        let state = FakeAXState()
        let app = FakeAXElement()
        let focused = FakeAXElement()
        let fallbackWindow = FakeAXElement()
        state.appByPID[1] = app
        state.setAttribute(app, kAXFocusedWindowAttribute as CFString, result: (.success, focused))
        state.setAttribute(app, kAXWindowsAttribute as CFString, result: (.success, [fallbackWindow]))

        state.setAttribute(focused, kAXRoleAttribute as CFString, result: (.success, "AXTextField"))
        state.setAttribute(focused, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(focused, kAXValueAttribute as CFString, result: (.success, "https://focused-url.example"))

        let result = DefaultBrowserAutomatorAccessibility.arcURL(pid: 1, axAPI: state.makeAPI())
        #expect(result == "https://focused-url.example")
        #expect(!state.requested.contains { $0.1 == (kAXWindowsAttribute as String) })
    }

    @Test("arcURL falls back to first window when focused window has no URL")
    func arcURLWindowsFallback() {
        let state = FakeAXState()
        let app = FakeAXElement()
        let focused = FakeAXElement()
        let window = FakeAXElement()
        state.appByPID[2] = app
        state.setAttribute(app, kAXFocusedWindowAttribute as CFString, result: (.success, focused))
        state.setAttribute(app, kAXWindowsAttribute as CFString, result: (.success, [window]))

        state.setAttribute(focused, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(focused, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(focused, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(focused, kAXChildrenAttribute as CFString, result: (.success, []))

        state.setAttribute(window, kAXRoleAttribute as CFString, result: (.success, "AXTextField"))
        state.setAttribute(window, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(window, kAXValueAttribute as CFString, result: (.success, "fallback.example"))

        let result = DefaultBrowserAutomatorAccessibility.arcURL(pid: 2, axAPI: state.makeAPI())
        #expect(result == "https://fallback.example")
        #expect(state.requested.contains { $0.1 == (kAXWindowsAttribute as String) })
    }

    @Test("arcURL returns nil when neither focused window nor windows can provide URL")
    func arcURLNoData() {
        let state = FakeAXState()
        let app = FakeAXElement()
        state.appByPID[3] = app
        state.setAttribute(app, kAXFocusedWindowAttribute as CFString, result: (.attributeUnsupported, nil))
        state.setAttribute(app, kAXWindowsAttribute as CFString, result: (.attributeUnsupported, nil))

        let result = DefaultBrowserAutomatorAccessibility.arcURL(pid: 3, axAPI: state.makeAPI())
        #expect(result == nil)
    }

    @Test("findURL handles role/value parsing and title parsing branches")
    func findURLRoleAndTitlePaths() {
        let state = FakeAXState()
        let element = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(element, kAXRoleAttribute as CFString, result: (.success, "AXStaticText"))
        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, "title.example"))
        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, "  https://value.example  "))
        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == "https://value.example")

        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, "domain.example"))
        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == "https://domain.example")

        state.setAttribute(element, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, "https://title.example"))
        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == "https://title.example")

        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, "title2.example"))
        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == "https://title2.example")
    }

    @Test("findURL recurses through children and respects depth limit")
    func findURLRecursionAndDepth() {
        let state = FakeAXState()
        let parent = FakeAXElement()
        let child = FakeAXElement()
        let grandchild = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(parent, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(parent, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(parent, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(parent, kAXChildrenAttribute as CFString, result: (.success, [child]))

        state.setAttribute(child, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(child, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(child, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(child, kAXChildrenAttribute as CFString, result: (.success, [grandchild]))

        state.setAttribute(grandchild, kAXRoleAttribute as CFString, result: (.success, "AXComboBox"))
        state.setAttribute(grandchild, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(grandchild, kAXValueAttribute as CFString, result: (.success, "deep.example"))

        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: parent, axAPI: api) == "https://deep.example")
        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: parent, depth: 16, axAPI: api) == nil)
    }

    @Test("findURL returns nil when children attribute is unavailable")
    func findURLChildrenUnavailable() {
        let state = FakeAXState()
        let element = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(element, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(element, kAXChildrenAttribute as CFString, result: (.attributeUnsupported, nil))

        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == nil)
    }

    @Test("findURL defaults missing role/title/value attributes to empty strings")
    func findURLMissingStringAttributes() {
        let state = FakeAXState()
        let element = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(element, kAXRoleAttribute as CFString, result: (.success, nil))
        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, nil))
        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, nil))
        state.setAttribute(element, kAXChildrenAttribute as CFString, result: (.success, []))

        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == nil)
    }

    @Test("findURL falls through when supported role value is not a URL")
    func findURLSupportedRoleNonURLValue() {
        let state = FakeAXState()
        let element = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(element, kAXRoleAttribute as CFString, result: (.success, "AXTextField"))
        state.setAttribute(element, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(element, kAXValueAttribute as CFString, result: (.success, "not a url"))
        state.setAttribute(element, kAXChildrenAttribute as CFString, result: (.success, []))

        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: element, axAPI: api) == nil)
    }

    @Test("findURL checks later children when earlier child has no match")
    func findURLContinuesAcrossChildren() {
        let state = FakeAXState()
        let parent = FakeAXElement()
        let firstChild = FakeAXElement()
        let secondChild = FakeAXElement()
        let api = state.makeAPI()

        state.setAttribute(parent, kAXRoleAttribute as CFString, result: (.success, "AXButton"))
        state.setAttribute(parent, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(parent, kAXValueAttribute as CFString, result: (.success, ""))
        state.setAttribute(parent, kAXChildrenAttribute as CFString, result: (.success, [firstChild, secondChild]))

        state.setAttribute(firstChild, kAXRoleAttribute as CFString, result: (.success, "AXTextField"))
        state.setAttribute(firstChild, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(firstChild, kAXValueAttribute as CFString, result: (.success, "invalid value"))
        state.setAttribute(firstChild, kAXChildrenAttribute as CFString, result: (.success, []))

        state.setAttribute(secondChild, kAXRoleAttribute as CFString, result: (.success, "AXComboBox"))
        state.setAttribute(secondChild, kAXTitleAttribute as CFString, result: (.success, ""))
        state.setAttribute(secondChild, kAXValueAttribute as CFString, result: (.success, "later.example"))

        #expect(DefaultBrowserAutomatorAccessibility.findURL(in: parent, axAPI: api) == "https://later.example")
    }

    @Test("liveSystem and live dependency constructors can execute without crashing")
    func liveConstructorsExecute() {
        let dependencies = DefaultBrowserAutomatorSystemDependencies.live()
        let axAPI = dependencies.axAPI
        let app = axAPI.makeApplication(0)
        let result = axAPI.copyAttribute(app, kAXRoleAttribute as CFString)

        _ = dependencies.checkPermissions(false)
        _ = dependencies.executeAppleScript("return \"ok\"")
        let running = dependencies.runningApplications()

        let bridge = DefaultBrowserAutomatorRuntimeBridge.liveSystem()
        _ = bridge.checkPermissions(false)
        _ = bridge.executeAppleScript("return \"ok\"")
        let bridgeApps = bridge.runningApplications()
        let arc = bridge.arcAccessibilityURL(0)

        #expect("\(result.0)".isEmpty == false)
        #expect(running.count >= 0)
        #expect(bridgeApps.count >= 0)
        #expect(arc == nil || !arc!.isEmpty)
    }
}
