import AppKit

@MainActor
enum FreeAppRuntime {
    static func quitApplication() {
        FreeAppRuntimeStorage.callTerminator(NSApplication.shared, nil)
    }
}
