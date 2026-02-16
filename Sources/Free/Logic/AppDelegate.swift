import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var defaults: UserDefaults = .standard

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldPreventTermination() {
            showBlockingAlert()
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
