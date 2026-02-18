import AppKit

enum FreeAppRuntimeStorage {
    static var terminator: (NSApplication, Any?) -> Void = { app, sender in
        app.terminate(sender)
    }
}
