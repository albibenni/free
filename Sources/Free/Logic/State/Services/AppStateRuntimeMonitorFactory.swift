import Foundation

enum AppStateRuntimeMonitorFactory {
    static func makeMonitor(
        stateSnapshotProvider: @escaping () -> BrowserMonitor.StateSnapshot?,
        setTrustedState: @escaping (Bool) -> Void
    ) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: stateSnapshotProvider,
            setTrustedState: setTrustedState
        )
    }
}
