import AppKit

protocol AppDelegateSystem {
    var bundlePath: String { get }
    var bundleName: String { get }
    var processName: String { get }

    func activateForAlert()
    func confirmMoveToApplications() -> Bool
    func confirmQuitWhileBlocking() -> Bool

    func fileExists(atPath: String) -> Bool
    func removeItem(atPath: String) throws
    func copyItem(atPath: String, toPath: String) throws

    func relaunch(destinationPath: String) throws
    func terminate()
    func showMoveError(_ message: String)
    func showBlockingAlert()
}

protocol AppDelegateAlertPresenting: AnyObject {
    var messageText: String { get set }
    var informativeText: String { get set }
    var alertStyle: NSAlert.Style { get set }
    @discardableResult
    func addButton(withTitle: String) -> NSButton
    func runModal() -> NSApplication.ModalResponse
}

extension NSAlert: AppDelegateAlertPresenting {}

protocol AppDelegateFileManaging {
    func fileExists(atPath: String) -> Bool
    func removeItem(atPath: String) throws
    func copyItem(atPath: String, toPath: String) throws
}

extension FileManager: AppDelegateFileManaging {}

protocol AppDelegateProcessRunning: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    func run() throws
}

extension Process: AppDelegateProcessRunning {}

struct DefaultAppDelegateSystem: AppDelegateSystem {
    private enum ModalDefault {
        static func run(_ alert: any AppDelegateAlertPresenting) -> NSApplication.ModalResponse {
            if isRunningInTestProcess(), alert is NSAlert {
                return .alertSecondButtonReturn
            }
            return alert.runModal()
        }

        private static func isRunningInTestProcess() -> Bool {
            DefaultAppDelegateSystem.isRunningInTestProcess()
        }
    }

    struct Runtime {
        var bundlePathProvider: () -> String
        var bundleNameProvider: () -> String
        var processNameProvider: () -> String
        var activateForAlert: () -> Void
        var makeAlert: () -> any AppDelegateAlertPresenting
        var fileManager: any AppDelegateFileManaging
        var makeProcess: () -> any AppDelegateProcessRunning
        var terminate: () -> Void

        static let live: Runtime = {
#if SWIFT_PACKAGE
            let activate: () -> Void = {}
            let terminate: () -> Void = {}
#else
            let activate: () -> Void = {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            let terminate: () -> Void = { NSApplication.shared.terminate(nil) }
#endif
            return Runtime(
                bundlePathProvider: { Bundle.main.bundlePath },
                bundleNameProvider: { Bundle.main.bundleURL.lastPathComponent },
                processNameProvider: { ProcessInfo.processInfo.processName },
                activateForAlert: activate,
                makeAlert: { NSAlert() },
                fileManager: FileManager.default,
                makeProcess: { Process() },
                terminate: terminate
            )
        }()
    }

    private let runtime: Runtime

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

    init(runtime: Runtime = .live) {
        self.runtime = runtime
    }

    var bundlePath: String { runtime.bundlePathProvider() }
    var bundleName: String { runtime.bundleNameProvider() }
    var processName: String { runtime.processNameProvider() }

    func activateForAlert() {
        runtime.activateForAlert()
    }

    func confirmMoveToApplications() -> Bool {
        let alert = runtime.makeAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText =
            "I can move myself to the Applications folder for you. This helps ensure I have the right permissions to block distractions."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Do Not Move")
        return ModalDefault.run(alert) == .alertFirstButtonReturn
    }

    func confirmQuitWhileBlocking() -> Bool {
        let alert = runtime.makeAlert()
        alert.messageText = "Focus Mode is Active"
        alert.informativeText =
            "Focus Mode is currently active. Closing the app now will stop protection. Do you want to close the app?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close App")
        alert.addButton(withTitle: "Cancel")
        return ModalDefault.run(alert) == .alertFirstButtonReturn
    }

    func fileExists(atPath: String) -> Bool {
        runtime.fileManager.fileExists(atPath: atPath)
    }

    func removeItem(atPath: String) throws {
        try runtime.fileManager.removeItem(atPath: atPath)
    }

    func copyItem(atPath: String, toPath: String) throws {
        try runtime.fileManager.copyItem(atPath: atPath, toPath: toPath)
    }

    func relaunch(destinationPath: String) throws {
        let script = "sleep 1; open \"\(destinationPath)\""
        let process = runtime.makeProcess()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }

    func terminate() {
        runtime.terminate()
    }

    func showMoveError(_ message: String) {
        let alert = runtime.makeAlert()
        alert.messageText = "Could not move app"
        alert.informativeText = message
        _ = ModalDefault.run(alert)
    }

    func showBlockingAlert() {
        let alert = runtime.makeAlert()
        alert.messageText = "Strict Mode is Active"
        alert.informativeText = "Disable Strict Mode in Settings before quitting the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        _ = ModalDefault.run(alert)
    }
}
