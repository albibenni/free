import AppKit
import Foundation
import Testing

@testable import FreeLogic

private enum AppDelegateSystemTestError: Error {
    case removeFailed
    case copyFailed
    case processFailed
}

private final class CounterBox {
    var value = 0
}

private final class MockAlertPresenter: AppDelegateAlertPresenting {
    var messageText = ""
    var informativeText = ""
    var alertStyle: NSAlert.Style = .informational
    var buttonTitles: [String] = []
    var modalResponse: NSApplication.ModalResponse = .alertSecondButtonReturn
    var runModalCalls = 0

    func addButton(withTitle: String) -> NSButton {
        buttonTitles.append(withTitle)
        return NSButton(title: withTitle, target: nil, action: nil)
    }

    func runModal() -> NSApplication.ModalResponse {
        runModalCalls += 1
        return modalResponse
    }
}

private final class MockFileManager: AppDelegateFileManaging {
    var existingPaths: Set<String> = []
    var removeError: Error?
    var copyError: Error?
    var removedPaths: [String] = []
    var copiedPaths: [(from: String, to: String)] = []

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
        copiedPaths.append((from: atPath, to: toPath))
    }
}

private final class MockProcessRunner: AppDelegateProcessRunning {
    var executableURL: URL?
    var arguments: [String]?
    var runCalls = 0
    var runError: Error?

    func run() throws {
        if let runError {
            throw runError
        }
        runCalls += 1
    }
}

@Suite(.serialized)
struct AppDelegateSystemTests {

    private func makeSystem(
        bundlePath: String = "/tmp/Free.app",
        bundleName: String = "Free.app",
        processName: String = "Free",
        alert: MockAlertPresenter? = nil,
        fileManager: MockFileManager? = nil,
        process: MockProcessRunner? = nil,
        activateCounter: CounterBox = CounterBox(),
        terminateCounter: CounterBox = CounterBox()
    ) -> (
        DefaultAppDelegateSystem, MockAlertPresenter, MockFileManager, MockProcessRunner,
        CounterBox, CounterBox
    ) {
        let alert = alert ?? MockAlertPresenter()
        let fileManager = fileManager ?? MockFileManager()
        let process = process ?? MockProcessRunner()

        let runtime = DefaultAppDelegateSystem.Runtime(
            bundlePathProvider: { bundlePath },
            bundleNameProvider: { bundleName },
            processNameProvider: { processName },
            activateForAlert: { activateCounter.value += 1 },
            makeAlert: { alert },
            fileManager: fileManager,
            makeProcess: { process },
            terminate: { terminateCounter.value += 1 }
        )

        return (
            DefaultAppDelegateSystem(runtime: runtime), alert, fileManager, process,
            activateCounter, terminateCounter
        )
    }

    @Test("DefaultAppDelegateSystem exposes runtime-provided identifiers")
    func identifiers() {
        let (system, _, _, _, _, _) = makeSystem(
            bundlePath: "/Applications/Test.app",
            bundleName: "Test.app",
            processName: "TestProcess"
        )

        #expect(system.bundlePath == "/Applications/Test.app")
        #expect(system.bundleName == "Test.app")
        #expect(system.processName == "TestProcess")
    }

    @Test("DefaultAppDelegateSystem live runtime path can be instantiated")
    func liveRuntimeInitializationCoverage() {
        let runtime = DefaultAppDelegateSystem.Runtime.live
        let system = DefaultAppDelegateSystem()

        #expect(!runtime.bundlePathProvider().isEmpty)
        #expect(!runtime.bundleNameProvider().isEmpty)
        #expect(!runtime.processNameProvider().isEmpty)
        runtime.activateForAlert()
        runtime.terminate()

        #expect(!system.bundlePath.isEmpty)
        #expect(!system.bundleName.isEmpty)
        #expect(!system.processName.isEmpty)
    }

    @MainActor
    @Test("DefaultAppDelegateSystem live runtime can build alert and process")
    func liveRuntimeFactoriesCoverage() {
        let runtime = DefaultAppDelegateSystem.Runtime.live
        _ = runtime.makeAlert()
        _ = runtime.makeProcess()
        #expect(Bool(true))
    }

    @Test("activateForAlert delegates through runtime")
    func activateForAlert() {
        let (system, _, _, _, activateCounter, _) = makeSystem()

        system.activateForAlert()
        #expect(activateCounter.value == 1)
    }

    @Test("confirmMoveToApplications configures alert and maps modal response")
    func confirmMoveAlertConfiguration() {
        let alert = MockAlertPresenter()
        let (system, capturedAlert, _, _, _, _) = makeSystem(alert: alert)

        capturedAlert.modalResponse = .alertFirstButtonReturn
        #expect(system.confirmMoveToApplications() == true)

        capturedAlert.modalResponse = .alertSecondButtonReturn
        #expect(system.confirmMoveToApplications() == false)

        #expect(
            capturedAlert.messageText == "Move to Applications folder?"
        )
        #expect(
            capturedAlert.informativeText.contains("move myself to the Applications folder")
        )
        #expect(
            capturedAlert.buttonTitles == [
                "Move to Applications", "Do Not Move", "Move to Applications", "Do Not Move",
            ])
        #expect(capturedAlert.runModalCalls == 2)
    }

    @Test("confirmQuitWhileBlocking configures warning alert and maps modal response")
    func confirmQuitWhileBlockingAlertConfiguration() {
        let alert = MockAlertPresenter()
        let (system, capturedAlert, _, _, _, _) = makeSystem(alert: alert)

        capturedAlert.modalResponse = .alertFirstButtonReturn
        #expect(system.confirmQuitWhileBlocking() == true)

        capturedAlert.modalResponse = .alertSecondButtonReturn
        #expect(system.confirmQuitWhileBlocking() == false)

        #expect(capturedAlert.messageText == "Focus Mode is Active")
        #expect(capturedAlert.informativeText.contains("Closing the app now will stop protection"))
        #expect(capturedAlert.alertStyle == .warning)
        #expect(
            capturedAlert.buttonTitles == [
                "Close App", "Cancel", "Close App", "Cancel",
            ])
        #expect(capturedAlert.runModalCalls == 2)
    }

    @Test("file operations delegate to runtime file manager")
    func fileOperations() throws {
        let fileManager = MockFileManager()
        fileManager.existingPaths = ["/Applications/Free.app"]

        let (system, _, capturedFileManager, _, _, _) = makeSystem(fileManager: fileManager)

        #expect(system.fileExists(atPath: "/Applications/Free.app"))
        #expect(!system.fileExists(atPath: "/Missing.app"))

        try system.removeItem(atPath: "/Applications/Free.app")
        try system.copyItem(atPath: "/tmp/Free.app", toPath: "/Applications/Free.app")

        #expect(capturedFileManager.removedPaths == ["/Applications/Free.app"])
        #expect(capturedFileManager.copiedPaths.count == 1)
        #expect(capturedFileManager.copiedPaths[0].from == "/tmp/Free.app")
        #expect(capturedFileManager.copiedPaths[0].to == "/Applications/Free.app")
    }

    @Test("file operations propagate runtime file manager errors")
    func fileOperationErrors() {
        let fileManager = MockFileManager()
        fileManager.removeError = AppDelegateSystemTestError.removeFailed
        fileManager.copyError = AppDelegateSystemTestError.copyFailed
        let (system, _, _, _, _, _) = makeSystem(fileManager: fileManager)

        #expect(throws: AppDelegateSystemTestError.self) {
            try system.removeItem(atPath: "/Applications/Free.app")
        }
        #expect(throws: AppDelegateSystemTestError.self) {
            try system.copyItem(atPath: "/tmp/Free.app", toPath: "/Applications/Free.app")
        }
    }

    @Test("relaunch configures and runs process")
    func relaunchSuccess() throws {
        let process = MockProcessRunner()
        let (system, _, _, capturedProcess, _, _) = makeSystem(process: process)

        try system.relaunch(destinationPath: "/Applications/Free.app")

        #expect(capturedProcess.executableURL == URL(fileURLWithPath: "/bin/sh"))
        #expect(capturedProcess.arguments == ["-c", "sleep 1; open \"/Applications/Free.app\""])
        #expect(capturedProcess.runCalls == 1)
    }

    @Test("relaunch propagates process errors")
    func relaunchError() {
        let process = MockProcessRunner()
        process.runError = AppDelegateSystemTestError.processFailed
        let (system, _, _, _, _, _) = makeSystem(process: process)

        #expect(throws: AppDelegateSystemTestError.self) {
            try system.relaunch(destinationPath: "/Applications/Free.app")
        }
    }

    @Test("terminate delegates through runtime")
    func terminate() {
        let (system, _, _, _, _, terminateCounter) = makeSystem()

        system.terminate()
        #expect(terminateCounter.value == 1)
    }

    @Test("showMoveError configures alert and shows it")
    func showMoveError() {
        let alert = MockAlertPresenter()
        let (system, capturedAlert, _, _, _, _) = makeSystem(alert: alert)

        system.showMoveError("Copy failed")

        #expect(capturedAlert.messageText == "Could not move app")
        #expect(capturedAlert.informativeText == "Copy failed")
        #expect(capturedAlert.runModalCalls == 1)
    }

    @Test("showBlockingAlert configures warning alert")
    func showBlockingAlert() {
        let alert = MockAlertPresenter()
        let (system, capturedAlert, _, _, _, _) = makeSystem(alert: alert)

        system.showBlockingAlert()

        #expect(capturedAlert.messageText == "Unblockable Mode is Active")
        #expect(
            capturedAlert.informativeText
                == "Disable Unblockable Mode in Settings before quitting the app.")
        #expect(capturedAlert.alertStyle == .warning)
        #expect(capturedAlert.buttonTitles == ["OK"])
        #expect(capturedAlert.runModalCalls == 1)
    }
}
