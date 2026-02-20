import Foundation
import AppKit
import ApplicationServices

struct DefaultBrowserAutomatorAXAPI {
    var makeApplication: (pid_t) -> AnyObject
    var copyAttribute: (_ element: AnyObject, _ attribute: CFString) -> (AXError, Any?)

    static func live() -> DefaultBrowserAutomatorAXAPI {
        DefaultBrowserAutomatorAXAPI(
            makeApplication: { pid in
                AXUIElementCreateApplication(pid) as AnyObject
            },
            copyAttribute: { element, attribute in
                var value: CFTypeRef?
                let axElement = element as! AXUIElement
                let error = AXUIElementCopyAttributeValue(axElement, attribute, &value)
                return (error, value)
            }
        )
    }
}

struct DefaultBrowserAutomatorSystemDependencies {
    var checkPermissions: (_ prompt: Bool) -> Bool
    var executeAppleScript: (_ source: String) -> String?
    var runningApplications: () -> [NSRunningApplication]
    var axAPI: DefaultBrowserAutomatorAXAPI

    static func live() -> DefaultBrowserAutomatorSystemDependencies {
        DefaultBrowserAutomatorSystemDependencies(
            checkPermissions: { prompt in
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
                return AXIsProcessTrustedWithOptions(options)
            },
            executeAppleScript: { source in
                NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
            },
            runningApplications: {
                NSWorkspace.shared.runningApplications
            },
            axAPI: .live()
        )
    }
}

extension DefaultBrowserAutomatorRuntimeBridge {
    static func liveSystem() -> DefaultBrowserAutomatorRuntimeBridge {
        liveSystem(dependencies: .live())
    }

    static func liveSystem(dependencies: DefaultBrowserAutomatorSystemDependencies) -> DefaultBrowserAutomatorRuntimeBridge {
        DefaultBrowserAutomatorRuntimeBridge(
            checkPermissions: { prompt in
                dependencies.checkPermissions(prompt)
            },
            executeAppleScript: { source in
                dependencies.executeAppleScript(source)
            },
            runningApplications: {
                dependencies.runningApplications()
            },
            arcAccessibilityURL: { pid in
                DefaultBrowserAutomatorAccessibility.arcURL(pid: pid, axAPI: dependencies.axAPI)
            }
        )
    }
}

enum DefaultBrowserAutomatorAccessibility {
    static func arcURL(pid: pid_t, axAPI: DefaultBrowserAutomatorAXAPI) -> String? {
        let application = axAPI.makeApplication(pid)

        let focusedWindowResult = axAPI.copyAttribute(application, kAXFocusedWindowAttribute as CFString)
        if focusedWindowResult.0 == .success,
           let focusedWindow = focusedWindowResult.1 as AnyObject?,
           let url = findURL(in: focusedWindow, axAPI: axAPI) {
            return url
        }

        let windowsResult = axAPI.copyAttribute(application, kAXWindowsAttribute as CFString)
        if windowsResult.0 == .success,
           let windows = windowsResult.1 as? [AnyObject],
           let firstWindow = windows.first {
            return findURL(in: firstWindow, axAPI: axAPI)
        }

        return nil
    }

    static func findURL(in element: AnyObject, depth: Int = 0, axAPI: DefaultBrowserAutomatorAXAPI) -> String? {
        if depth > 15 { return nil }

        let role = (axAPI.copyAttribute(element, kAXRoleAttribute as CFString).1 as? String) ?? ""
        let title = (axAPI.copyAttribute(element, kAXTitleAttribute as CFString).1 as? String) ?? ""
        let value = ((axAPI.copyAttribute(element, kAXValueAttribute as CFString).1 as? String) ?? "")
            .trimmingCharacters(in: .whitespaces)

        if ["AXTextField", "AXStaticText", "AXComboBox"].contains(role), !value.isEmpty {
            if value.lowercased().hasPrefix("http") { return value }
            if value.contains("."), !value.contains(" "), value.count > 3 { return "https://" + value }
        }

        if depth == 0, title.hasPrefix("http") || (title.contains(".") && !title.contains(" ")) {
            return title.hasPrefix("http") ? title : "https://" + title
        }

        let childrenResult = axAPI.copyAttribute(element, kAXChildrenAttribute as CFString)
        if childrenResult.0 == .success,
           let children = childrenResult.1 as? [AnyObject] {
            for child in children {
                if let found = findURL(in: child, depth: depth + 1, axAPI: axAPI) {
                    return found
                }
            }
        }

        return nil
    }
}
