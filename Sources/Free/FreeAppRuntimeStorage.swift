import AppKit

enum FreeAppRuntimeStorage {
    static var terminator: (NSApplication, Any?) -> Void {
        get { FreeAppRuntimeTerminatorState.terminator }
        set { FreeAppRuntimeTerminatorState.terminator = newValue }
    }

    @inline(never)
    static func callTerminator(_ app: NSApplication, _ sender: Any?) {
        terminator(app, sender)
    }
}
