import Combine
import Foundation

enum AppKitAppStateObservation {
    static func bind<Signature: Equatable>(
        appState: AppState,
        signature: @escaping () -> Signature,
        cancellables: inout Set<AnyCancellable>,
        onChange: @escaping (_ signature: Signature) -> Void
    ) {
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .map { signature() }
            .prepend(signature())
            .removeDuplicates()
            .dropFirst()
            .sink { updatedSignature in
                onChange(updatedSignature)
            }
            .store(in: &cancellables)
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
}
