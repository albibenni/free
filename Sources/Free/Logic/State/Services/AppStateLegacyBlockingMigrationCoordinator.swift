import Foundation

enum AppStateLegacyBlockingMigrationCoordinator {
    struct Result: Equatable {
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
    }

    static func resolve(
        hasPersistedWasStartedBySchedule: Bool,
        isBlocking: Bool,
        shouldBeBlockingNow: Bool
    ) -> Result? {
        guard !hasPersistedWasStartedBySchedule, isBlocking else { return nil }
        return Result(
            isBlocking: shouldBeBlockingNow,
            wasStartedBySchedule: shouldBeBlockingNow
        )
    }
}
