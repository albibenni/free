import Combine
import Foundation

enum AppStateLifecycleService {
    struct RuntimeBindings {
        let monitor: BrowserMonitor?
        let calendarCancellable: AnyCancellable
    }

    static func bindPersistence(
        appState: AppState,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        AppStatePersistenceCoordinator.bind(
            appState: appState,
            settingsStore: settingsStore
        )
    }

    static func startRuntime(
        appState: AppState,
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool
    ) -> RuntimeBindings {
        let monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injectedMonitor,
            isTesting: isTesting
        ) {
            BrowserMonitor(appState: appState)
        }

        let calendarCancellable = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: appState.calendarProvider,
            timerCoordinator: appState.timerCoordinator,
            onCalendarChange: { [weak appState] in appState?.checkSchedules() },
            onScheduleTick: { [weak appState] in appState?.checkSchedules() }
        )

        return RuntimeBindings(
            monitor: monitor,
            calendarCancellable: calendarCancellable
        )
    }

    static func teardown(
        timerCoordinator: AppStateTimerCoordinator,
        calendarCancellable: inout AnyCancellable?,
        persistenceCancellables: inout Set<AnyCancellable>
    ) {
        AppStateRuntimeWiringCoordinator.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable
        )
        persistenceCancellables.removeAll()
    }
}
