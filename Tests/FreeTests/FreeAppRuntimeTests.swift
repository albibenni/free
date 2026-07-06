import AppKit
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct FreeAppRuntimeTests {
    @Test("FreeAppRuntimeStorage default terminator path can execute in SwiftPM tests")
    func defaultTerminatorPathExecutes() async throws {
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = originalTerminator
        FreeAppRuntime.quitApplication()
        #expect(Bool(true))
    }

    @Test("FreeAppRuntime.quitApplication delegates to configured terminator")
    func quitApplicationDelegatesToTerminator() async throws {
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
    func usesLatestConfiguredTerminator() async throws {
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

    @Test("FreeApp quit action delegates to FreeAppRuntime")
    func appQuitActionDelegates() async throws {
        var calls = 0
        let originalTerminator = FreeAppRuntimeStorage.terminator
        defer { FreeAppRuntimeStorage.terminator = originalTerminator }

        FreeAppRuntimeStorage.terminator = { _, _ in
            calls += 1
        }

        let action = FreeApp.quitAction()
        action()

        #expect(calls == 1)
    }
}
