import Foundation
import Combine
import Observation

enum AppStatePersistenceCoordinator {
    static func persistSchedulesSynchronously(
        _ schedules: [Schedule],
        settingsStore: SettingsStore
    ) {
        settingsStore.saveSchedules(schedules)
    }

    @MainActor
    static func bind(
        appState: AppState,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        var cancellables = Set<AnyCancellable>()
        observeAndSave(appState: appState, keyPath: \.isBlocking) { settingsStore.setIsBlocking($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.isStrict) { settingsStore.setIsStrict($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.weekStartsOnMonday) { settingsStore.setWeekStartsOnMonday($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.accentColorIndex) { settingsStore.setAccentColorIndex($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.appearanceMode) { settingsStore.setAppearanceModeRawValue($0.rawValue) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.cursorFluidAnimationEnabled) { settingsStore.setCursorFluidAnimationEnabled($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.calendarIntegrationEnabled) { settingsStore.setCalendarIntegrationEnabled($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.calendarImportFocusTitleRules) { settingsStore.setCalendarImportFocusTitleRules($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.calendarImportBreakTitleRules) { settingsStore.setCalendarImportBreakTitleRules($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.calendarImportedScheduleRuleSetId) { settingsStore.setCalendarImportedScheduleRuleSetId($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.blockNewTabs) { settingsStore.setBlockNewTabs($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.blockDeveloperHosts) { settingsStore.setBlockDeveloperHosts($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.blockLocalNetworkHosts) { settingsStore.setBlockLocalNetworkHosts($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.allowSearchEngineWebsites) { settingsStore.setAllowSearchEngineWebsites($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.allowAIProviderWebsites) { settingsStore.setAllowAIProviderWebsites($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.ruleSets) { settingsStore.saveRuleSets($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.activeRuleSetId) { settingsStore.setActiveRuleSetId($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.pomodoroFocusDuration) { settingsStore.setPomodoroFocusDuration($0) }.store(in: &cancellables)
        observeAndSave(appState: appState, keyPath: \.pomodoroBreakDuration) { settingsStore.setPomodoroBreakDuration($0) }.store(in: &cancellables)
        return cancellables
    }

    @MainActor
    private static func observeAndSave<T: Equatable>(
        appState: AppState,
        keyPath: KeyPath<AppState, T>,
        save: @escaping @MainActor (T) -> Void
    ) -> AnyCancellable {
        let tracker = Tracker(keyPath: keyPath, save: save)
        tracker.startTracking(appState: appState)
        return AnyCancellable {
            _ = tracker // Retain tracker until cancelled
        }
    }

    // @MainActor class: implicitly Sendable, so it can re-arm from
    // withObservationTracking's @Sendable onChange without an escape hatch.
    @MainActor
    private final class Tracker<T: Equatable> {
        private let keyPath: KeyPath<AppState, T>
        private let save: @MainActor (T) -> Void
        private var lastValue: T?

        init(keyPath: KeyPath<AppState, T>, save: @escaping @MainActor (T) -> Void) {
            self.keyPath = keyPath
            self.save = save
        }

        func startTracking(appState: AppState?) {
            guard let appState else { return }
            let current = appState[keyPath: keyPath]
            if let last = lastValue, last != current {
                save(current)
            }
            lastValue = current

            withObservationTracking {
                _ = appState[keyPath: keyPath]
            } onChange: { [weak self, weak appState] in
                Task { @MainActor [weak appState] in
                    self?.startTracking(appState: appState)
                }
            }
        }
    }
}
