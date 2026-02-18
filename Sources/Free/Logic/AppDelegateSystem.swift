import AppKit

protocol AppDelegateSystem {
    var bundlePath: String { get }
    var bundleName: String { get }
    var processName: String { get }

    func activateForAlert()
    func confirmMoveToApplications() -> Bool

    func fileExists(atPath: String) -> Bool
    func removeItem(atPath: String) throws
    func copyItem(atPath: String, toPath: String) throws

    func relaunch(destinationPath: String) throws
    func terminate()
    func showMoveError(_ message: String)
    func showBlockingAlert()
}

struct DefaultAppDelegateSystem: AppDelegateSystem {
    var bundlePath: String { Bundle.main.bundlePath }
    var bundleName: String { Bundle.main.bundleURL.lastPathComponent }
    var processName: String { ProcessInfo.processInfo.processName }

    func activateForAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func confirmMoveToApplications() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText =
            "I can move myself to the Applications folder for you. This helps ensure I have the right permissions to block distractions."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Do Not Move")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func fileExists(atPath: String) -> Bool {
        FileManager.default.fileExists(atPath: atPath)
    }

    func removeItem(atPath: String) throws {
        try FileManager.default.removeItem(atPath: atPath)
    }

    func copyItem(atPath: String, toPath: String) throws {
        try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
    }

    func relaunch(destinationPath: String) throws {
        let script = "sleep 1; open \"\(destinationPath)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }

    func terminate() {
        NSApplication.shared.terminate(nil)
    }

    func showMoveError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not move app"
        alert.informativeText = message
        alert.runModal()
    }

    func showBlockingAlert() {
        let alert = NSAlert()
        alert.messageText = "Focus Mode is Active"
        alert.informativeText = "You must disable Focus Mode before quitting the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
