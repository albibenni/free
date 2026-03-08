import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct LogicServicesCoverageBoostTests {
    private final class LaunchAtLoginManagerMock: LaunchAtLoginManaging {
        var isEnabled: Bool = false
        var enableError: Error?
        var disableError: Error?

        func enable() throws {
            if let enableError { throw enableError }
            isEnabled = true
        }

        func disable() throws {
            if let disableError { throw disableError }
            isEnabled = false
        }
    }

    private enum DummyError: Error {
        case failure
    }

    @Test("AppStateScheduleCoordinator uses preferred imported-key map when provided")
    func preservedImportedByKeyPrefersExplicitDictionary() {
        let imported = Schedule(
            name: "Imported",
            days: [],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            type: .focus,
            importedCalendarEventKey: "event-a"
        )
        let preferred: [String: Schedule] = ["preferred": imported]

        let mapping = AppStateScheduleCoordinator.preservedImportedByKey(
            from: [imported],
            preferred: preferred
        )

        #expect(mapping.count == 1)
        #expect(mapping["preferred"]?.id == imported.id)
    }

    @Test("PauseEngine tick handles non-paused and zero-remaining states")
    func pauseEngineEdgeTicks() {
        let idle = PauseEngine.State(isPaused: false, remaining: 42)
        let idleTick = PauseEngine.tick(from: idle)
        #expect(idleTick == idle)

        let boundary = PauseEngine.State(isPaused: true, remaining: 0)
        let boundaryTick = PauseEngine.tick(from: boundary)
        #expect(boundaryTick.isPaused == false)
        #expect(boundaryTick.remaining == 0)
    }

    @Test("LaunchAtLoginService covers prompt guards and disable failure path")
    func launchAtLoginServicePromptAndDisableFailure() {
        let suite = "LogicServicesCoverageBoostTests.launchAtLogin"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        let manager = LaunchAtLoginManagerMock()
        manager.isEnabled = false

        let noPromptService = LaunchAtLoginService(
            launchAtLoginManager: manager,
            settingsStore: store,
            canPromptForLaunchAtLogin: { false }
        )
        #expect(noPromptService.preparePromptIfNeeded() == false)

        let promptService = LaunchAtLoginService(
            launchAtLoginManager: manager,
            settingsStore: store,
            canPromptForLaunchAtLogin: { true }
        )
        #expect(promptService.preparePromptIfNeeded() == true)
        #expect(promptService.preparePromptIfNeeded() == false)

        manager.disableError = DummyError.failure
        #expect(promptService.setEnabled(false) == false)
    }

    @Test("RuleSetCoordinator create and delete cover non-active create and strict delete guard")
    func ruleSetCoordinatorEdgeBranches() {
        var ruleSets = [RuleSet.defaultSet()]
        var active: UUID? = ruleSets[0].id

        let created = RuleSetCoordinator.createRuleSet(
            name: "  ",
            makeActive: false,
            in: &ruleSets,
            activeRuleSetId: &active
        )
        #expect(created.name == "New List")
        #expect(active == ruleSets[0].id)

        let strictDelete = RuleSetCoordinator.deleteRuleSet(
            id: created.id,
            in: &ruleSets,
            activeRuleSetId: &active,
            isStrictActive: true
        )
        #expect(strictDelete == false)
        #expect(ruleSets.contains(where: { $0.id == created.id }))
    }

    @Test("CalendarImportService suppress guard and RuleSetService unknown-name path")
    func calendarImportAndRuleSetServiceEdges() {
        var suppressed = Set<String>()
        let local = Schedule(
            name: "Local",
            days: [2],
            startTime: Date(),
            endTime: Date().addingTimeInterval(120),
            type: .focus
        )
        #expect(
            CalendarImportService.suppressImportedCalendarEventIfNeeded(
                for: local,
                suppressedKeys: &suppressed
            ) == false
        )
        #expect(suppressed.isEmpty)

        let name = RuleSetService.currentPrimaryRuleSetName(
            ruleSets: [RuleSet.defaultSet()],
            schedules: [],
            currentPrimaryRuleSetId: UUID(),
            isPomodoroFocus: false,
            isBlocking: true,
            wasStartedBySchedule: false
        )
        #expect(name == "Unknown List")
    }

    @Test("ScheduleEngine covers imported guard and save existing with nil initial-day")
    func scheduleEngineEdgeBranches() {
        let imported = Schedule(
            name: "Imported",
            days: [],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            type: .focus,
            importedCalendarEventKey: "event-1"
        )
        var schedules = [imported]
        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: imported.id,
            originalDay: 2,
            targetDay: 3,
            targetDate: Date().addingTimeInterval(600),
            start: Date().addingTimeInterval(600),
            end: Date().addingTimeInterval(900)
        )
        #expect(schedules[0].id == imported.id)
        #expect(schedules[0].days == imported.days)

        let existing = Schedule(
            name: "Existing",
            days: [2, 3],
            startTime: Date(),
            endTime: Date().addingTimeInterval(600),
            type: .focus
        )
        schedules = [existing]
        ScheduleEngine.saveSchedule(
            in: &schedules,
            name: "Updated",
            days: [4],
            date: nil,
            start: Date().addingTimeInterval(100),
            end: Date().addingTimeInterval(200),
            color: 2,
            type: .unfocus,
            ruleSet: nil,
            existingId: existing.id,
            modifyAllDays: false,
            initialDay: nil
        )
        #expect(schedules.count == 1)
        #expect(schedules[0].name == "Existing")
        #expect(schedules[0].days == [2, 3])
    }
}
