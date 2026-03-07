import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct AppStateRuntimeMonitorFactoryTests {
    @Test("AppStateRuntimeMonitorFactory builds a monitor and allows teardown")
    func makeMonitorBuildsBrowserMonitor() {
        let monitor = AppStateRuntimeMonitorFactory.makeMonitor(
            stateSnapshotProvider: { nil },
            setTrustedState: { _ in }
        )

        monitor.checkActiveTab()
        monitor.stopMonitoring()

        #expect(type(of: monitor) == BrowserMonitor.self)
    }
}
