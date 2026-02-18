import AppKit

enum FreeAppRuntime {
    static func quitApplication() {
        FreeAppRuntimeStorage.terminator(NSApplication.shared, nil)
    }
}
