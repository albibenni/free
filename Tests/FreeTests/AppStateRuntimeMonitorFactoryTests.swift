import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AppStateRuntimeMonitorFactoryTests {
    @Test("AppStateRuntimeMonitorFactory builds a monitor and allows teardown")
    func makeMonitorBuildsBrowserMonitor() async {
        let monitor = AppStateRuntimeMonitorFactory.makeMonitor(
            stateSnapshotProvider: { nil as BrowserMonitor.StateSnapshot? },
            onEvent: { _ in },
            isTesting: false
        )

        await monitor.checkActiveTab()
        await monitor.stopMonitoring()

        #expect(type(of: monitor) == BrowserMonitor.self)
    }
}
