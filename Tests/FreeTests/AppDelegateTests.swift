import AppKit
import Foundation
import Testing

@testable import FreeLogic

private enum MockSystemError: Error {
    case removeFailed
    case copyFailed
    case relaunchFailed
}

private final class MockAppDelegateSystem: AppDelegateSystem {
    var bundlePath = "/Users/test/Downloads/Free.app"
    var bundleName = "Free.app"
    var processName = "Free"

    var activateForAlertCalls = 0
    var confirmMoveCalls = 0
    var confirmMoveResult = false
    var confirmQuitCalls = 0
    var confirmQuitResult = false

    var existingPaths: Set<String> = []
    var removedPaths: [String] = []
    var copiedItems: [(from: String, to: String)] = []
    var relaunchedPaths: [String] = []
    var terminateCalls = 0
    var moveErrors: [String] = []
    var blockingAlertCalls = 0

    var removeError: Error?
    var copyError: Error?
    var relaunchError: Error?

    func activateForAlert() {
        activateForAlertCalls += 1
    }

    func confirmMoveToApplications() -> Bool {
        confirmMoveCalls += 1
        return confirmMoveResult
    }

    func confirmQuitWhileBlocking() -> Bool {
        confirmQuitCalls += 1
        return confirmQuitResult
    }

    func fileExists(atPath: String) -> Bool {
        existingPaths.contains(atPath)
    }

    func removeItem(atPath: String) throws {
        if let removeError {
            throw removeError
        }
        removedPaths.append(atPath)
    }

    func copyItem(atPath: String, toPath: String) throws {
        if let copyError {
            throw copyError
        }
        copiedItems.append((from: atPath, to: toPath))
    }

    func relaunch(destinationPath: String) throws {
        if let relaunchError {
            throw relaunchError
        }
        relaunchedPaths.append(destinationPath)
    }

    func terminate() {
        terminateCalls += 1
    }

    func showMoveError(_ message: String) {
        moveErrors.append(message)
    }

    func showBlockingAlert() {
        blockingAlertCalls += 1
    }
}

struct AppDelegateTests {

    private func setupIsolatedDelegate(
        name: String,
        system: MockAppDelegateSystem = MockAppDelegateSystem()
    ) -> (AppDelegate, MockAppDelegateSystem, UserDefaults) {
        let suite = "AppDelegateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let delegate = AppDelegate()
        delegate.defaults = defaults
        delegate.system = system
        return (delegate, system, defaults)
    }

    @Test("AppDelegate launch check returns early when app is already in Applications")
    func launchCheckInApplicationsEarlyReturn() {
        let system = MockAppDelegateSystem()
        system.bundlePath = "/Applications/Free.app"
        let (delegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckInApplicationsEarlyReturn",
            system: system
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(system.activateForAlertCalls == 0)
        #expect(system.confirmMoveCalls == 0)
        #expect(system.copiedItems.isEmpty)
    }

    @Test("AppDelegate launch check returns early in test process")
    func launchCheckTestProcessEarlyReturn() {
        let system = MockAppDelegateSystem()
        system.processName = "FreeTests"
        let (delegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckTestProcessEarlyReturn",
            system: system
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(system.activateForAlertCalls == 0)
        #expect(system.confirmMoveCalls == 0)
        #expect(system.copiedItems.isEmpty)
    }

    @Test("AppDelegate launch check prompts but does not move when user declines")
    func launchCheckDeclineMove() {
        let system = MockAppDelegateSystem()
        system.confirmMoveResult = false
        let (delegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckDeclineMove",
            system: system
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(system.activateForAlertCalls == 1)
        #expect(system.confirmMoveCalls == 1)
        #expect(system.copiedItems.isEmpty)
        #expect(system.terminateCalls == 0)
    }

    @Test("AppDelegate moves app and relaunches when user confirms")
    func launchCheckMoveSuccess() {
        let system = MockAppDelegateSystem()
        system.confirmMoveResult = true
        let destination = "/Applications/\(system.bundleName)"
        system.existingPaths = [destination]
        let (delegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckMoveSuccess",
            system: system
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(system.activateForAlertCalls == 1)
        #expect(system.confirmMoveCalls == 1)
        #expect(system.removedPaths == [destination])
        #expect(system.copiedItems.count == 1)
        #expect(system.copiedItems[0].from == system.bundlePath)
        #expect(system.copiedItems[0].to == destination)
        #expect(system.relaunchedPaths == [destination])
        #expect(system.terminateCalls == 1)
        #expect(system.moveErrors.isEmpty)
    }

    @Test("AppDelegate reports copy errors during move flow")
    func launchCheckMoveCopyError() {
        let system = MockAppDelegateSystem()
        system.confirmMoveResult = true
        system.copyError = MockSystemError.copyFailed
        let (delegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckMoveCopyError",
            system: system
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(system.copiedItems.isEmpty)
        #expect(system.relaunchedPaths.isEmpty)
        #expect(system.terminateCalls == 0)
        #expect(system.moveErrors.count == 1)
    }

    @Test("AppDelegate reports remove and relaunch errors during move flow")
    func launchCheckMoveRemoveAndRelaunchErrors() {
        let removeSystem = MockAppDelegateSystem()
        removeSystem.confirmMoveResult = true
        let removeDestination = "/Applications/\(removeSystem.bundleName)"
        removeSystem.existingPaths = [removeDestination]
        removeSystem.removeError = MockSystemError.removeFailed
        let (removeDelegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckMoveRemoveError",
            system: removeSystem
        )

        removeDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        #expect(removeSystem.moveErrors.count == 1)
        #expect(removeSystem.copiedItems.isEmpty)
        #expect(removeSystem.terminateCalls == 0)

        let relaunchSystem = MockAppDelegateSystem()
        relaunchSystem.confirmMoveResult = true
        relaunchSystem.relaunchError = MockSystemError.relaunchFailed
        let (relaunchDelegate, _, _) = setupIsolatedDelegate(
            name: "launchCheckMoveRelaunchError",
            system: relaunchSystem
        )

        relaunchDelegate.applicationDidFinishLaunching(
            Notification(name: Notification.Name("test")))
        #expect(relaunchSystem.copiedItems.count == 1)
        #expect(relaunchSystem.relaunchedPaths.isEmpty)
        #expect(relaunchSystem.terminateCalls == 0)
        #expect(relaunchSystem.moveErrors.count == 1)
    }

    @Test("AppDelegate prevents termination when blocking is active")
    func terminationPrevention() {
        let (delegate, _, defaults) = setupIsolatedDelegate(name: "terminationPrevention")

        defaults.set(false, forKey: "IsBlocking")
        #expect(delegate.shouldPreventTermination() == false)
        #expect(delegate.shouldConfirmTerminationWhileBlocking() == false)

        defaults.set(true, forKey: "IsBlocking")
        defaults.set(false, forKey: "IsUnblockable")
        #expect(delegate.shouldPreventTermination() == false)
        #expect(delegate.shouldConfirmTerminationWhileBlocking() == true)

        defaults.set(true, forKey: "IsUnblockable")
        #expect(delegate.shouldPreventTermination() == true)
        #expect(delegate.shouldConfirmTerminationWhileBlocking() == false)
    }

    @Test("applicationShouldTerminate blocks strict mode quit and triggers custom alert")
    func applicationTerminationStrictReply() {
        let (delegate, system, defaults) = setupIsolatedDelegate(
            name: "applicationTerminationStrictReply")

        var alertWasShown = false
        delegate.onShowAlert = { alertWasShown = true }

        defaults.set(true, forKey: "IsBlocking")
        defaults.set(true, forKey: "IsUnblockable")
        let reply1 = delegate.applicationShouldTerminate(NSApplication.shared)
        #expect(reply1 == .terminateCancel)
        #expect(alertWasShown == true)
        #expect(system.confirmQuitCalls == 0)

        alertWasShown = false
        defaults.set(false, forKey: "IsBlocking")
        defaults.set(false, forKey: "IsUnblockable")
        let reply2 = delegate.applicationShouldTerminate(NSApplication.shared)
        #expect(reply2 == .terminateNow)
        #expect(alertWasShown == false)
        #expect(system.blockingAlertCalls == 0)
    }

    @Test("applicationShouldTerminate asks confirmation while non-strict blocking and respects confirm")
    func applicationTerminationNonStrictConfirm() {
        let (delegate, system, defaults) = setupIsolatedDelegate(
            name: "applicationTerminationNonStrictConfirm")
        delegate.onShowAlert = nil
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(false, forKey: "IsUnblockable")
        system.confirmQuitResult = true

        let reply = delegate.applicationShouldTerminate(NSApplication.shared)

        #expect(reply == .terminateNow)
        #expect(system.confirmQuitCalls == 1)
        #expect(system.blockingAlertCalls == 0)
    }

    @Test("applicationShouldTerminate asks confirmation while non-strict blocking and respects cancel")
    func applicationTerminationNonStrictCancel() {
        let (delegate, system, defaults) = setupIsolatedDelegate(
            name: "applicationTerminationNonStrictCancel")
        delegate.onShowAlert = nil
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(false, forKey: "IsUnblockable")
        system.confirmQuitResult = false

        let reply = delegate.applicationShouldTerminate(NSApplication.shared)

        #expect(reply == .terminateCancel)
        #expect(system.confirmQuitCalls == 1)
        #expect(system.blockingAlertCalls == 0)
    }

    @Test("applicationShouldTerminate uses default blocking alert when no custom handler")
    func applicationTerminationDefaultAlert() {
        let (delegate, system, defaults) = setupIsolatedDelegate(
            name: "applicationTerminationDefaultAlert")
        delegate.onShowAlert = nil
        defaults.set(true, forKey: "IsBlocking")
        defaults.set(true, forKey: "IsUnblockable")

        let reply = delegate.applicationShouldTerminate(NSApplication.shared)

        #expect(reply == .terminateCancel)
        #expect(system.blockingAlertCalls == 1)
        #expect(system.confirmQuitCalls == 0)
    }

    @Test("isInApplications identifies correct paths")
    func pathDetectionLogic() {
        let delegate = AppDelegate()

        #expect(delegate.isInApplications(path: "/Applications/Free.app"))
        #expect(delegate.isInApplications(path: "/System/Applications/Safari.app"))
        #expect(!delegate.isInApplications(path: "/Users/test/Downloads/Free.app"))
        #expect(!delegate.isInApplications(path: "/Volumes/Free/Free.app"))
    }
}
