import Testing

@testable import FreeLogic

struct AppStateLegacyBlockingMigrationCoordinatorTests {
    @Test("resolve returns nil when source metadata already exists")
    func resolveWithPersistedSource() {
        let result = AppStateLegacyBlockingMigrationCoordinator.resolve(
            hasPersistedWasStartedBySchedule: true,
            isBlocking: true,
            shouldBeBlockingNow: true
        )
        #expect(result == nil)
    }

    @Test("resolve returns nil when blocking is already disabled")
    func resolveWhenBlockingDisabled() {
        let result = AppStateLegacyBlockingMigrationCoordinator.resolve(
            hasPersistedWasStartedBySchedule: false,
            isBlocking: false,
            shouldBeBlockingNow: false
        )
        #expect(result == nil)
    }

    @Test("resolve maps legacy state to automatic blocking decision")
    func resolveLegacyDecision() {
        let active = AppStateLegacyBlockingMigrationCoordinator.resolve(
            hasPersistedWasStartedBySchedule: false,
            isBlocking: true,
            shouldBeBlockingNow: true
        )
        #expect(active?.isBlocking == true)
        #expect(active?.wasStartedBySchedule == true)

        let inactive = AppStateLegacyBlockingMigrationCoordinator.resolve(
            hasPersistedWasStartedBySchedule: false,
            isBlocking: true,
            shouldBeBlockingNow: false
        )
        #expect(inactive?.isBlocking == false)
        #expect(inactive?.wasStartedBySchedule == false)
    }
}
