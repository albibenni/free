import AppKit
import Foundation

private final class MacInstallerSystem: InstallerSystem {
    var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "InstallerTargetAppName") as? String) ?? "Free"
    }

    var bundleURL: URL {
        Bundle.main.bundleURL
    }

    func fileExists(atPath: String) -> Bool {
        FileManager.default.fileExists(atPath: atPath)
    }

    func confirmReplaceExistingApp() -> Bool {
        let replaceAlert = NSAlert()
        replaceAlert.messageText = "\(appName) is already installed"
        replaceAlert.informativeText = "Replace the existing app in Applications with this version?"
        replaceAlert.addButton(withTitle: "Replace")
        replaceAlert.addButton(withTitle: "Cancel")
        return replaceAlert.runModal() == .alertFirstButtonReturn
    }

    func runShellCommand(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func runShellCommandAsAdmin(_ command: String) -> Bool {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var scriptError: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&scriptError)
        return scriptError == nil
    }

    func launchInstalledApp(at url: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return nil
            }
            return "open exited with status \(process.terminationStatus)"
        } catch {
            return error.localizedDescription
        }
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

final class InstallerDelegate: NSObject, NSApplicationDelegate {
    private let system: any InstallerSystem

    override init() {
        self.system = MacInstallerSystem()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        _ = InstallerFlow(system: system).runInstall()
        terminateInstaller()
    }

    private func terminateInstaller() {
        NSApplication.shared.terminate(nil)
    }
}

@main
struct InstallerMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = InstallerDelegate()
        app.delegate = delegate
        app.run()
    }
}
