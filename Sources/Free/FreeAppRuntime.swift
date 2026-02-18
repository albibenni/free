import AppKit

enum FreeAppRuntime {
    static func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
