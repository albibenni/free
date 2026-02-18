import AppKit

enum FreeAppRuntimeTerminatorState {
#if SWIFT_PACKAGE
    static var terminator: (NSApplication, Any?) -> Void = { _, _ in }
#else
    static var terminator: (NSApplication, Any?) -> Void = { app, sender in
        app.terminate(sender)
    }
#endif
}
