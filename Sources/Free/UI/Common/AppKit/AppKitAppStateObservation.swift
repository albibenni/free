import Combine
import Foundation

enum AppKitAppStateObservation {
    static func bind(
        appState: AppState,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping () -> Void
    ) {
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { _ in
                onChange()
            }
            .store(in: &cancellables)
    }
}
