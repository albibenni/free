import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var defaults: UserDefaults = .standard
    public var onShowAlert: (() -> Void)?
    public var onApplicationDidFinishLaunching: (() -> Void)?
    var system: any AppDelegateSystem = DefaultAppDelegateSystem()
    var isRelaunching = false

    public func applicationDidFinishLaunching(_ notification: Notification) {
        checkLocation()
        onApplicationDidFinishLaunching?()
    }

    private func checkLocation() {
        if Self.isRunningInTestProcess(), system is DefaultAppDelegateSystem { return }
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

    static func isRunningInTestProcess(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        classLookup: (String) -> AnyClass? = NSClassFromString
    ) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES"] != nil { return true }
        if environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil { return true }
        return classLookup("XCTestCase") != nil
    }

    private func moveToApplications(currentPath: String, destinationPath: String) {
        do {
            if system.fileExists(atPath: destinationPath) {
                try system.removeItem(atPath: destinationPath)
            }

            try system.copyItem(atPath: currentPath, toPath: destinationPath)
            try system.relaunch(destinationPath: destinationPath)
            isRelaunching = true
            system.terminate()
        } catch {
            system.showMoveError(error.localizedDescription)
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    {
        if isRelaunching { return .terminateNow }
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
        return defaults.bool(forKey: "IsStrict")
    }

    public func shouldConfirmTerminationWhileBlocking() -> Bool {
        return defaults.bool(forKey: "IsBlocking") && !defaults.bool(forKey: "IsStrict")
    }
}
