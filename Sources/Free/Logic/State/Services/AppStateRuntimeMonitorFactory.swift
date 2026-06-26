import Foundation

enum AppStateRuntimeMonitorFactory {
    static func makeMonitor(
        stateSnapshotProvider: @escaping @Sendable () async -> BrowserMonitor.StateSnapshot?,
        onEvent: @escaping @Sendable (BrowserMonitor.Event) -> Void
    ) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: stateSnapshotProvider,
            onEvent: onEvent
        )
    }
}
