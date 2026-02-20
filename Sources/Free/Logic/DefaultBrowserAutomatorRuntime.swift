import Foundation
import AppKit
import ApplicationServices

extension DefaultBrowserAutomatorRuntime {
    static func live() -> DefaultBrowserAutomatorRuntime {
        DefaultBrowserAutomatorRuntime(
            checkPermissions: { prompt in
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
                return AXIsProcessTrustedWithOptions(options)
            },
            executeAppleScript: { source in
                NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
            },
            runningApplications: {
                NSWorkspace.shared.runningApplications.map {
                    BrowserAutomationApplication(
                        bundleIdentifier: $0.bundleIdentifier,
                        localizedName: $0.localizedName,
                        processIdentifier: $0.processIdentifier
                    )
                }
            },
            arcAccessibilityURL: { pid in
                DefaultBrowserAutomatorAccessibility.arcURL(pid: pid)
            }
        )
    }
}

private enum DefaultBrowserAutomatorAccessibility {
    static func arcURL(pid: pid_t) -> String? {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?

        if AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let focusedWindow = value,
           let url = findURL(in: focusedWindow as! AXUIElement) {
            return url
        }

        if AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement],
           let firstWindow = windows.first {
            return findURL(in: firstWindow)
        }

        return nil
    }

    static func findURL(in element: AXUIElement, depth: Int = 0) -> String? {
        if depth > 15 { return nil }

        var roleRef: CFTypeRef?
        var titleRef: CFTypeRef?
        var valueRef: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)

        let role = roleRef as? String ?? ""
        let title = titleRef as? String ?? ""
        let value = (valueRef as? String ?? "").trimmingCharacters(in: .whitespaces)

        if ["AXTextField", "AXStaticText", "AXComboBox"].contains(role), !value.isEmpty {
            if value.lowercased().hasPrefix("http") { return value }
            if value.contains("."), !value.contains(" "), value.count > 3 { return "https://" + value }
        }

        if depth == 0, title.hasPrefix("http") || (title.contains(".") && !title.contains(" ")) {
            return title.hasPrefix("http") ? title : "https://" + title
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findURL(in: child, depth: depth + 1) {
                    return found
                }
            }
        }

        return nil
    }
}
