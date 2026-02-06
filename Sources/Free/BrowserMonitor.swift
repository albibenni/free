import Foundation
import AppKit
import ApplicationServices

class BrowserMonitor {
    private var timer: Timer?
    private weak var appState: AppState?
    private let server = LocalServer()
    
    // Supported browsers bundle IDs
    private let browsers = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]

    init(appState: AppState) {
        self.appState = appState
        
        // Check permissions immediately
        checkPermissions()
        
        // Start local blocking server
        server.start()
        
        startMonitoring()
    }

    func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.appState?.isTrusted = trusted
        }
        if !trusted {
            print("WARNING: Accessibility permissions not granted. Blocking will not work.")
        }
    }

    func startMonitoring() {
        // Check every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
            self?.checkActiveTab()
        }
    }

    func log(_ message: String) {
        let entry = "\(Date()): \(message)\n"
        if let data = entry.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/free_app.log")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    func checkActiveTab() {
        guard let appState = appState, appState.isBlocking else { return }

        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        
        // Log non-browser apps only occasionally to avoid spam, but for now log everything relevant
        if let bundleId = frontApp.bundleIdentifier, browsers.contains(bundleId) {
            // Get the URL
            if let currentURL = getActiveUrl(for: frontApp) {
                log("Detected URL: \(currentURL) in \(frontApp.localizedName ?? "Unknown")")
                
                // Check if we are already on our block page to avoid loops
                if currentURL.contains("localhost:10000") {
                    return
                }

                if !isAllowed(currentURL, rules: appState.allowedRules) {
                    log("BLOCKED: \(currentURL) -> Redirecting")
                    redirectTab(app: frontApp, to: "http://localhost:10000")
                } else {
                    log("ALLOWED: \(currentURL)")
                }
            } else {
                log("Could not get URL from \(frontApp.localizedName ?? "Unknown")")
            }
        }
    }

    func isAllowed(_ url: String, rules: [String]) -> Bool {
        for rule in rules {
            if url.contains(rule) {
                return true
            }
        }
        return false
    }

    func redirectTab(app: NSRunningApplication, to url: String) {
        let scriptSource: String
        let appName = app.localizedName ?? "Safari"
        
        if app.bundleIdentifier == "com.apple.Safari" {
             scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set URL of current tab of front window to "\(url)"
                end if
            end tell
            """
        } else {
            // Chromium based browsers (Chrome, Brave, Edge, Arc, Opera, Vivaldi) usually share the same AppleScript suite
            // We just need to target the correct application name.
            scriptSource = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    set URL of active tab of front window to "\(url)"
                end if
            end tell
            """
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            scriptObject.executeAndReturnError(&error)
        }
        
        if let error = error {
            print("Error redirecting tab: \(error)")
        }
    }

    func getActiveUrl(for app: NSRunningApplication) -> String? {
        var scriptSource = ""
        let appName = app.localizedName ?? "Safari"
        
        if app.bundleIdentifier == "com.apple.Safari" {
            scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    get URL of current tab of front window
                end if
            end tell
            """
        } else {
            // Chromium based browsers (Chrome, Brave, Edge, Arc, Opera, Vivaldi)
            scriptSource = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    get URL of active tab of front window
                end if
            end tell
            """
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            if let url = output.stringValue {
                return url
            }
        }
        
        if let error = error {
            log("AppleScript Error: \(error)")
        }
        
        return nil
    }
}