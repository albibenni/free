import Foundation
import Testing

@testable import FreeLogic

private final class MockInstallerSystem: InstallerSystem {
    var appName = "Free"
    var bundleURL = URL(fileURLWithPath: "/Volumes/Free/Install Free.app")

    var existingPaths: Set<String> = []
    var replaceConfirmation = true
    var shellResult = true
    var adminShellResult = true
    var launchError: String?

    var replacePromptCalls = 0
    var shellCommands: [String] = []
    var adminShellCommands: [String] = []
    var launchTargets: [URL] = []
    var alerts: [(title: String, message: String)] = []

    func fileExists(atPath: String) -> Bool {
        existingPaths.contains(atPath)
    }

    func confirmReplaceExistingApp() -> Bool {
        replacePromptCalls += 1
        return replaceConfirmation
    }

    func runShellCommand(_ command: String) -> Bool {
        shellCommands.append(command)
        return shellResult
    }

    func runShellCommandAsAdmin(_ command: String) -> Bool {
        adminShellCommands.append(command)
        return adminShellResult
    }

    func launchInstalledApp(at url: URL) -> String? {
        launchTargets.append(url)
        return launchError
    }

    func showAlert(title: String, message: String) {
        alerts.append((title: title, message: message))
    }
}

struct InstallerFlowTests {
    @Test("InstallerFlow handles missing source app")
    func sourceMissing() {
        let system = MockInstallerSystem()
        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .sourceMissing)
        #expect(system.shellCommands.isEmpty)
        #expect(system.alerts.count == 1)
        #expect(system.alerts[0].title.contains("Could not find"))
    }

    @Test("InstallerFlow cancels when replacing existing app is declined")
    func cancelReplace() {
        let system = MockInstallerSystem()
        let source = "/Volumes/Free/Free.app"
        let target = "/Applications/Free.app"
        system.existingPaths = [source, target]
        system.replaceConfirmation = false

        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .cancelled)
        #expect(system.replacePromptCalls == 1)
        #expect(system.shellCommands.isEmpty)
        #expect(system.alerts.isEmpty)
    }

    @Test("InstallerFlow installs and launches via standard permissions")
    func standardInstallSuccess() {
        let system = MockInstallerSystem()
        let source = "/Volumes/Free/Free.app"
        system.existingPaths = [source]
        system.shellResult = true

        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .installed)
        #expect(system.replacePromptCalls == 0)
        #expect(system.shellCommands.count == 1)
        #expect(system.adminShellCommands.isEmpty)
        #expect(system.launchTargets.map(\.path) == ["/Applications/Free.app"])
        #expect(system.alerts.isEmpty)
    }

    @Test("InstallerFlow falls back to admin install when direct copy fails")
    func adminFallbackInstallSuccess() {
        let system = MockInstallerSystem()
        let source = "/Volumes/Free/Free.app"
        system.existingPaths = [source]
        system.shellResult = false
        system.adminShellResult = true

        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .installed)
        #expect(system.shellCommands.count == 1)
        #expect(system.adminShellCommands.count == 1)
        #expect(system.launchTargets.count == 1)
        #expect(system.alerts.isEmpty)
    }

    @Test("InstallerFlow surfaces install failure after both copy attempts fail")
    func installFailure() {
        let system = MockInstallerSystem()
        let source = "/Volumes/Free/Free.app"
        system.existingPaths = [source]
        system.shellResult = false
        system.adminShellResult = false

        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .installFailed)
        #expect(system.shellCommands.count == 1)
        #expect(system.adminShellCommands.count == 1)
        #expect(system.launchTargets.isEmpty)
        #expect(system.alerts.count == 1)
        #expect(system.alerts[0].title == "Installation failed")
    }

    @Test("InstallerFlow reports launch failure after successful install")
    func launchFailure() {
        let system = MockInstallerSystem()
        let source = "/Volumes/Free/Free.app"
        system.existingPaths = [source]
        system.shellResult = true
        system.launchError = "open exited with status 1"

        let result = InstallerFlow(system: system).runInstall()

        #expect(result == .installedLaunchFailed)
        #expect(system.launchTargets.count == 1)
        #expect(system.alerts.count == 1)
        #expect(system.alerts[0].title == "Installed, but launch failed")
    }

    @Test("InstallerFlow install command escapes single quotes in paths")
    func commandQuoting() {
        let source = URL(fileURLWithPath: "/Volumes/Free's/Free.app")
        let target = URL(fileURLWithPath: "/Applications/Free's.app")
        let command = InstallerFlow.installCommand(sourceURL: source, targetURL: target)

        #expect(command.contains("'/Volumes/Free'\\''s/Free.app'"))
        #expect(command.contains("'/Applications/Free'\\''s.app'"))
    }
}
