import Combine
import Foundation

@MainActor
final class MainShellBindings {
    private var cancellables: Set<AnyCancellable> = []

    func bind(
        appStateChanges: (@escaping () -> Void) -> Void,
        shellState: FreeShellState,
        onSelectedSectionChanged: @escaping () -> Void,
        onAppStateChanged: @escaping () -> Void,
        onShowRulesChanged: @escaping (Bool) -> Void,
        onShowSchedulesChanged: @escaping (Bool) -> Void
    ) {
        cancellables.removeAll()

        shellState.$selectedSection
            .sink { _ in
                onSelectedSectionChanged()
            }
            .store(in: &cancellables)

        appStateChanges {
            onAppStateChanged()
        }

        shellState.$showRules
            .removeDuplicates()
            .sink { isShown in
                onShowRulesChanged(isShown)
            }
            .store(in: &cancellables)

        shellState.$showSchedules
            .removeDuplicates()
            .sink { isShown in
                onShowSchedulesChanged(isShown)
            }
            .store(in: &cancellables)
    }
}
