import Combine
import Foundation

enum AppKitAppStateObservation {
    typealias VoidPublisher = AnyPublisher<Void, Never>

    static func bind<Signature: Equatable>(
        publisher: VoidPublisher,
        signature: @escaping () -> Signature,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping (_ signature: Signature) -> Void
    ) {
        publisher
            .receive(on: RunLoop.main)
            .map { signature() }
            .prepend(signature())
            .removeDuplicates()
            .dropFirst()
            .sink(receiveValue: onChange)
            .store(in: &cancellables)
    }

    static func bind(
        publisher: VoidPublisher,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping () -> Void
    ) {
        bind(
            publisher: publisher,
            signature: { UUID() },
            cancellables: &cancellables
        ) { _ in
            onChange()
        }
    }

    static func bind<Signature: Equatable>(
        appState: AppState,
        signature: @escaping () -> Signature,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping (_ signature: Signature) -> Void
    ) {
        bind(
            publisher: appStatePublisher(appState: appState),
            signature: signature,
            cancellables: &cancellables,
            onChange: onChange
        )
    }

    static func bind(
        appState: AppState,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping () -> Void
    ) {
        bind(
            appState: appState,
            signature: { UUID() },
            cancellables: &cancellables
        ) { _ in
            onChange()
        }
    }

    static func appStatePublisher(appState: AppState) -> VoidPublisher {
        appState.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    static func settingsPublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$isBlocking.map { _ in () }.eraseToAnyPublisher(),
            appState.$isUnblockable.map { _ in () }.eraseToAnyPublisher(),
            appState.$weekStartsOnMonday.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarIntegrationEnabled.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarImportsBlockTime.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarImportFocusTitleRules.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarImportBreakTitleRules.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarImportedScheduleRuleSetId.map { _ in () }.eraseToAnyPublisher(),
            appState.$ruleSets.map { _ in () }.eraseToAnyPublisher(),
            appState.$blockNewTabs.map { _ in () }.eraseToAnyPublisher(),
            appState.$blockDeveloperHosts.map { _ in () }.eraseToAnyPublisher(),
            appState.$blockLocalNetworkHosts.map { _ in () }.eraseToAnyPublisher(),
            appState.$allowSearchEngineWebsites.map { _ in () }.eraseToAnyPublisher(),
            appState.$allowAIProviderWebsites.map { _ in () }.eraseToAnyPublisher(),
            appState.$appearanceMode.map { _ in () }.eraseToAnyPublisher(),
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    static func schedulesPublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$schedules.map { _ in () }.eraseToAnyPublisher(),
            appState.$appearanceMode.map { _ in () }.eraseToAnyPublisher(),
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
            appState.$weekStartsOnMonday.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarIntegrationEnabled.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarImportsBlockTime.map { _ in () }.eraseToAnyPublisher(),
            appState.calendarProvider.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    static func rulesPublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$ruleSets.map { _ in () }.eraseToAnyPublisher(),
            appState.$activeRuleSetId.map { _ in () }.eraseToAnyPublisher(),
            appState.$currentOpenUrls.map { _ in () }.eraseToAnyPublisher(),
            appState.$isBlocking.map { _ in () }.eraseToAnyPublisher(),
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    static func allowedWebsitesPublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$ruleSets.map { _ in () }.eraseToAnyPublisher(),
            appState.$activeRuleSetId.map { _ in () }.eraseToAnyPublisher(),
            appState.$isBlocking.map { _ in () }.eraseToAnyPublisher(),
            appState.$isUnblockable.map { _ in () }.eraseToAnyPublisher(),
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    static func focusPublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$isBlocking.map { _ in () }.eraseToAnyPublisher(),
            appState.$isUnblockable.map { _ in () }.eraseToAnyPublisher(),
            appState.$isTrusted.map { _ in () }.eraseToAnyPublisher(),
            appState.$isPaused.map { _ in () }.eraseToAnyPublisher(),
            appState.$pauseRemaining.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroStatus.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroRemaining.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroStartedAt.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroFocusDuration.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroBreakDuration.map { _ in () }.eraseToAnyPublisher(),
            appState.$ruleSets.map { _ in () }.eraseToAnyPublisher(),
            appState.$activeRuleSetId.map { _ in () }.eraseToAnyPublisher(),
            appState.$schedules.map { _ in () }.eraseToAnyPublisher(),
            appState.$currentOpenUrls.map { _ in () }.eraseToAnyPublisher(),
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
            appState.$appearanceMode.map { _ in () }.eraseToAnyPublisher(),
            appState.calendarProvider.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    static func shellAppearancePublisher(appState: AppState) -> VoidPublisher {
        merge([
            appState.$accentColorIndex.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarIntegrationEnabled.map { _ in () }.eraseToAnyPublisher(),
        ])
    }

    private static func merge(_ publishers: [VoidPublisher]) -> VoidPublisher {
        Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
}
