import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var defaults: UserDefaults = .standard
    public var onShowAlert: (() -> Void)?
    var system: any AppDelegateSystem = DefaultAppDelegateSystem()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        checkLocation()
    }

    private func checkLocation() {
        let bundlePath = system.bundlePath
        if isInApplications(path: bundlePath) || system.processName.contains("Test") {
            return
        }

        system.activateForAlert()

        if system.confirmMoveToApplications() {
            moveToApplications(
                currentPath: bundlePath,
                destinationPath: "/Applications/\(system.bundleName)"
            )
        }
    }

    public func isInApplications(path: String) -> Bool {
        return path.hasPrefix("/Applications") || path.hasPrefix("/System/Applications")
    }

    private func moveToApplications(currentPath: String, destinationPath: String) {
        do {
            if system.fileExists(atPath: destinationPath) {
                try system.removeItem(atPath: destinationPath)
            }

            try system.copyItem(atPath: currentPath, toPath: destinationPath)
            try system.relaunch(destinationPath: destinationPath)
            system.terminate()
        } catch {
            system.showMoveError(error.localizedDescription)
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    {
        if shouldPreventTermination() {
            if let customHandler = onShowAlert {
                customHandler()
            } else {
                system.showBlockingAlert()
            }
            return .terminateCancel
        }

        if shouldConfirmTerminationWhileBlocking() {
            return system.confirmQuitWhileBlocking() ? .terminateNow : .terminateCancel
        }

        return .terminateNow
    }

    public func shouldPreventTermination() -> Bool {
        return defaults.bool(forKey: "IsBlocking") && defaults.bool(forKey: "IsUnblockable")
    }

    public func shouldConfirmTerminationWhileBlocking() -> Bool {
        return defaults.bool(forKey: "IsBlocking") && !defaults.bool(forKey: "IsUnblockable")
    }
}
