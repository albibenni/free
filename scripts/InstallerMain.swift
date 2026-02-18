import AppKit
import Foundation

final class InstallerDelegate: NSObject, NSApplicationDelegate {
    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "InstallerTargetAppName") as? String) ?? "Free"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        runInstallFlow()
    }

    private func runInstallFlow() {
        let sourceURL = sourceAppURL()
        let targetURL = URL(fileURLWithPath: "/Applications/\(appName).app")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            showAlert(
                title: "Could not find \(appName).app",
                message:
                    "Please open Install \(appName).app from the disk image that contains \(appName).app."
            )
            terminateInstaller()
            return
        }

        if FileManager.default.fileExists(atPath: targetURL.path) {
            let replaceAlert = NSAlert()
            replaceAlert.messageText = "\(appName) is already installed"
            replaceAlert.informativeText =
                "Replace the existing app in Applications with this version?"
            replaceAlert.addButton(withTitle: "Replace")
            replaceAlert.addButton(withTitle: "Cancel")
            if replaceAlert.runModal() != .alertFirstButtonReturn {
                terminateInstaller()
                return
            }
        }

        let installCommand = [
            "/bin/rm -rf \(shellQuote(targetURL.path))",
            "/usr/bin/ditto \(shellQuote(sourceURL.path)) \(shellQuote(targetURL.path))",
            "/usr/bin/xattr -d -r com.apple.quarantine \(shellQuote(targetURL.path)) >/dev/null 2>&1 || true",
        ].joined(separator: "; ")

        if !runShellCommand(installCommand) {
            if !runShellCommandAsAdmin(installCommand) {
                showAlert(
                    title: "Installation failed",
                    message:
                        "Free could not be copied to /Applications. Please check permissions and try again."
                )
                terminateInstaller()
                return
            }
        }

        NSWorkspace.shared.openApplication(
            at: targetURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                self.showAlert(
                    title: "Installed, but launch failed",
                    message:
                        "Free was installed to /Applications, but could not be launched automatically.\n\n\(error.localizedDescription)"
                )
            }
            self.terminateInstaller()
        }
    }

    private func sourceAppURL() -> URL {
        let installerURL = Bundle.main.bundleURL
        let volumeRoot = installerURL.deletingLastPathComponent()
        return volumeRoot.appendingPathComponent("\(appName).app")
    }

    private func runShellCommand(_ command: String) -> Bool {
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

    private func runShellCommandAsAdmin(_ command: String) -> Bool {
        let escaped =
            command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var scriptError: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&scriptError)
        return scriptError == nil
    }

    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
