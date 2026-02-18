import AppKit
import Testing

@testable import FreeLogic

struct FreeAppRuntimeTests {
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
}
