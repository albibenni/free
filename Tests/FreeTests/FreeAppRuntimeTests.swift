import AppKit
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct FreeAppRuntimeTests {
    @Test("FreeAppRuntimeStorage default terminator path can execute in SwiftPM tests")
    func defaultTerminatorPathExecutes() {
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = originalTerminator
        FreeAppRuntime.quitApplication()
        #expect(Bool(true))
    }

    @Test("FreeAppRuntime.quitApplication delegates to configured terminator")
    func quitApplicationDelegatesToTerminator() {
        var capturedApp: NSApplication?
        var capturedSender: Any?
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = { app, sender in
            capturedApp = app
            capturedSender = sender
        }

        FreeAppRuntime.quitApplication()

        #expect(capturedApp === NSApplication.shared)
        #expect(capturedSender == nil)
    }

    @Test("FreeAppRuntime uses latest configured terminator")
    func usesLatestConfiguredTerminator() {
        var calls = 0
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = { app, sender in
            calls += 1
            #expect(app === NSApplication.shared)
            #expect(sender == nil)
        }
        FreeAppRuntime.quitApplication()

        FreeAppRuntimeStorage.terminator = { _, _ in
            calls += 10
        }
        FreeAppRuntime.quitApplication()

        #expect(calls == 11)
    }

    @Test("FreeAppSceneFactory quit action delegates to FreeAppRuntime")
    func sceneFactoryQuitActionDelegates() {
        var calls = 0
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = { _, _ in
            calls += 1
        }

        let action = FreeAppSceneFactory.quitAction()
        action()

        #expect(calls == 1)
    }
}
