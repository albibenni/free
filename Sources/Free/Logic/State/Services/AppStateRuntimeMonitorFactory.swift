import Foundation

enum AppStateRuntimeMonitorFactory {
    static func makeMonitor(
        stateSnapshotProvider: @escaping @Sendable () async -> BrowserMonitor.StateSnapshot?,
        onEvent: @escaping @Sendable (BrowserMonitor.Event) -> Void,
        isTesting: Bool
    ) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: stateSnapshotProvider,
            onEvent: onEvent,
            isTesting: isTesting
        )
    }
}
