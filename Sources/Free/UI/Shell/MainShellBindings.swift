import Foundation
import Observation

@MainActor
final class MainShellBindings {
    // Incremented on every bind; observation re-arm loops from a previous bind
    // check it and stop, replacing the cancellable-set teardown Combine provided.
    private var bindGeneration = 0

    func bind(
        appStateChanges: (@escaping @MainActor () -> Void) -> Void,
        shellState: FreeShellState,
        onSelectedSectionChanged: @escaping @MainActor () -> Void,
        onAppStateChanged: @escaping @MainActor () -> Void,
        onShowRulesChanged: @escaping @MainActor (Bool) -> Void,
        onShowSchedulesChanged: @escaping @MainActor (Bool) -> Void
    ) {
        bindGeneration += 1
        let generation = bindGeneration

        // Matches the previous @Published behavior: each handler fires once with
        // the current value at bind time, then again on changes.
        onSelectedSectionChanged()
        onShowRulesChanged(shellState.showRules)
        onShowSchedulesChanged(shellState.showSchedules)

        observeSelectedSection(
            shellState: shellState,
            generation: generation,
            onChange: onSelectedSectionChanged
        )
        observeFlag(
            read: { shellState.showRules },
            generation: generation,
            last: shellState.showRules,
            onChange: onShowRulesChanged
        )
        observeFlag(
            read: { shellState.showSchedules },
            generation: generation,
            last: shellState.showSchedules,
            onChange: onShowSchedulesChanged
        )

        appStateChanges {
            onAppStateChanged()
        }
    }

    private func observeSelectedSection(
        shellState: FreeShellState,
        generation: Int,
        onChange: @escaping @MainActor () -> Void
    ) {
        withObservationTracking {
            _ = shellState.selectedSection
        } onChange: { [self] in
            Task { @MainActor in
                guard generation == self.bindGeneration else { return }
                onChange()
                self.observeSelectedSection(
                    shellState: shellState,
                    generation: generation,
                    onChange: onChange
                )
            }
        }
    }

    // Deduplicated by value, mirroring the removeDuplicates() the Combine
    // pipeline applied to the sheet-visibility flags.
    private func observeFlag(
        read: @escaping @MainActor () -> Bool,
        generation: Int,
        last: Bool,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        withObservationTracking {
            _ = read()
        } onChange: { [self] in
            Task { @MainActor in
                guard generation == self.bindGeneration else { return }
                let value = read()
                if value != last {
                    onChange(value)
                }
                self.observeFlag(
                    read: read,
                    generation: generation,
                    last: value,
                    onChange: onChange
                )
            }
        }
    }
}
