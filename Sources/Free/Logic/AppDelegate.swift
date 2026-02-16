import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var defaults: UserDefaults = .standard
    public var onShowAlert: (() -> Void)?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        checkLocation()
    }

    private func checkLocation() {
        if isInApplications(path: Bundle.main.bundlePath) || ProcessInfo.processInfo.processName.contains("Test") {
            return
        }
        
        // Ensure app is in front to show the alert
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "I can move myself to the Applications folder for you. This helps ensure I have the right permissions to block distractions."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Do Not Move")
        
        if alert.runModal() == .alertFirstButtonReturn {
            moveToApplications(currentPath: Bundle.main.bundlePath, destinationPath: "/Applications/\(Bundle.main.bundleURL.lastPathComponent)")
        }
    }

    public func isInApplications(path: String) -> Bool {
        return path.hasPrefix("/Applications") || path.hasPrefix("/System/Applications")
    }

    private func moveToApplications(currentPath: String, destinationPath: String) {
        let fileManager = FileManager.default
        
        do {
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            
            try fileManager.copyItem(atPath: currentPath, toPath: destinationPath)
            
            // Relaunch from the new location
            let script = "sleep 1; open \"\(destinationPath)\""
            let process = Process()
            process.launchPath = "/bin/sh"
            process.arguments = ["-c", script]
            process.launch()
            
            NSApplication.shared.terminate(nil)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Could not move app"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.runModal()
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldPreventTermination() {
            if let customHandler = onShowAlert {
                customHandler()
            } else {
                showBlockingAlert()
            }
            return .terminateCancel
        }
        return .terminateNow
    }

    public func shouldPreventTermination() -> Bool {
        return defaults.bool(forKey: "IsBlocking")
    }

    private func showBlockingAlert() {
        let alert = NSAlert()
        alert.messageText = "Focus Mode is Active"
        alert.informativeText = "You must disable Focus Mode before quitting the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
