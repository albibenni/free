import Foundation

enum AppStateRuntimeMonitorFactory {
    static func makeMonitor(
        stateSnapshotProvider: @escaping () -> BrowserMonitor.StateSnapshot?,
        onEvent: @escaping (BrowserMonitor.Event) -> Void
    ) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: stateSnapshotProvider,
            onEvent: onEvent
        )
    }
}
