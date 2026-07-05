import Foundation
import AppKit
import ApplicationServices
import os

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
        // Shared between the two closures below: a denied Automation permission
        // (detected when a script fails) makes the overall permission check fail,
        // which surfaces the existing "grant permissions" warning in the UI.
        // Cleared again by the next successful script, so it self-heals after
        // the user re-grants access in System Settings.
        let automationDenied = OSAllocatedUnfairLock(initialState: false)
        return DefaultBrowserAutomatorSystemDependencies(
            checkPermissions: { prompt in
                let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
                let axTrusted = AXIsProcessTrustedWithOptions(options)
                return axTrusted && !automationDenied.withLock { $0 }
            },
            executeAppleScript: { source in
                var errorInfo: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo).stringValue
                if let errorInfo {
                    // errAEEventNotPermitted (-1743) means the Automation permission
                    // was denied or revoked: blocking cannot work until it is restored.
                    let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                    let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown"
                    let logger = Logger(subsystem: "com.benni.Free", category: "BrowserAutomation")
                    if number == -1743 {
                        automationDenied.withLock { $0 = true }
                        logger.fault("Apple Events permission denied; browser blocking is inactive: \(message, privacy: .public)")
                    } else {
                        logger.error("AppleScript failed (\(number)): \(message, privacy: .public)")
                    }
                } else {
                    automationDenied.withLock { $0 = false }
                }
                return result
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
