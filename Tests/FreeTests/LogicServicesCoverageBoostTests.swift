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

    @Test("LaunchAtLoginService covers default prompt closure, status, enable and disable-success")
    func launchAtLoginServiceRemainingCoverage() {
        let suite = "LogicServicesCoverageBoostTests.launchAtLogin.remaining"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        let manager = LaunchAtLoginManagerMock()

        let defaultPromptService = LaunchAtLoginService(
            launchAtLoginManager: manager,
            settingsStore: store
        )
        _ = defaultPromptService.preparePromptIfNeeded()

        #expect(defaultPromptService.isEnabled() == false)
        #expect(defaultPromptService.enable() == true)
        #expect(defaultPromptService.isEnabled() == true)
        #expect(defaultPromptService.setEnabled(false) == true)
        #expect(defaultPromptService.isEnabled() == false)
        #expect(defaultPromptService.setEnabled(true) == true)

        manager.enableError = DummyError.failure
        #expect(defaultPromptService.enable() == false)
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

    @Test("CalendarImportService covers merge, signature and duplicate-removal branches")
    func calendarImportServiceRemainingCoverage() {
        let baseStart = Date(timeIntervalSince1970: 1_000)
        let baseEnd = Date(timeIntervalSince1970: 1_600)
        let eventA = ExternalEvent(
            id: "event-a",
            title: "A",
            startDate: baseStart,
            endDate: baseEnd
        )
        let eventB = ExternalEvent(
            id: "event-b",
            title: "B",
            startDate: baseStart.addingTimeInterval(1_000),
            endDate: baseEnd.addingTimeInterval(1_000)
        )
        let eventC = ExternalEvent(
            id: "event-c",
            title: "C",
            startDate: baseStart.addingTimeInterval(2_000),
            endDate: baseEnd.addingTimeInterval(2_000)
        )

        let manual = Schedule(
            name: "Manual",
            days: [2],
            startTime: baseStart,
            endTime: baseEnd,
            type: .focus
        )
        let existingImportedA = Schedule(
            id: UUID(),
            name: "Imported Existing",
            days: [],
            date: eventA.startDate,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            isEnabled: false,
            colorIndex: 3,
            type: .unfocus,
            ruleSetId: nil,
            importedCalendarEventKey: eventA.id
        )
        let preservedImportedB = Schedule(
            id: UUID(),
            name: "Preserved B",
            days: [],
            date: eventB.startDate,
            startTime: eventB.startDate,
            endTime: eventB.endDate,
            isEnabled: false,
            colorIndex: 5,
            type: .focus,
            ruleSetId: UUID(),
            importedCalendarEventKey: eventB.id
        )

        let noImport = CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: [manual, existingImportedA],
            events: [eventA, eventB],
            shouldImportCalendarEvents: false,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            preservedImportedByKey: [:]
        )
        #expect(noImport.count == 1)
        #expect(noImport.first?.importedCalendarEventKey == nil)

        let merged = CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: [manual, existingImportedA],
            events: [eventB, eventA],
            shouldImportCalendarEvents: true,
            suppressedImportedCalendarEventKeys: [eventB.id],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            preservedImportedByKey: [eventB.id: preservedImportedB]
        )

        #expect(merged.count == 2)
        let importedA = merged.first(where: { $0.importedCalendarEventKey == eventA.id })
        #expect(importedA?.id == existingImportedA.id)
        #expect(importedA?.isEnabled == false)
        #expect(importedA?.colorIndex == 3)
        #expect(importedA?.type == .unfocus)

        let mergedWithPreserved = CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: [manual],
            events: [eventB],
            shouldImportCalendarEvents: true,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            preservedImportedByKey: [eventB.id: preservedImportedB]
        )
        let importedB = mergedWithPreserved.first(where: { $0.importedCalendarEventKey == eventB.id })
        #expect(importedB?.id == preservedImportedB.id)
        #expect(importedB?.colorIndex == preservedImportedB.colorIndex)

        let defaultSet = RuleSet.defaultSet()
        let mergedWithDefaults = CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: [manual],
            events: [eventC],
            shouldImportCalendarEvents: true,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: defaultSet.id,
            ruleSets: [defaultSet],
            preservedImportedByKey: [:]
        )
        let importedC = mergedWithDefaults.first(where: { $0.importedCalendarEventKey == eventC.id })
        #expect(importedC?.isEnabled == true)
        #expect(importedC?.colorIndex == 0)
        #expect(importedC?.type == .focus)
        #expect(importedC?.ruleSetId == defaultSet.id)

        let signatures = CalendarImportService.legacyImportedEventSignatures(from: [eventA, eventB])
        #expect(signatures.count == 2)

        let legacyDuplicate = Schedule(
            name: eventA.title,
            days: [2],
            date: eventA.startDate,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            type: .focus
        )
        let nonFocus = Schedule(
            name: eventA.title,
            days: [2],
            date: eventA.startDate,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            type: .unfocus
        )
        let noDate = Schedule(
            name: eventA.title,
            days: [2],
            date: nil,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            type: .focus
        )
        let keyedImported = Schedule(
            name: "Keyed",
            days: [],
            date: eventA.startDate,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            type: .focus,
            importedCalendarEventKey: "already-imported"
        )

        let filtered = CalendarImportService.removeLegacyImportedDuplicates(
            from: [legacyDuplicate, nonFocus, noDate, keyedImported],
            signatures: signatures
        )
        #expect(filtered.contains(where: { $0.id == legacyDuplicate.id }) == false)
        #expect(filtered.contains(where: { $0.id == nonFocus.id }))
        #expect(filtered.contains(where: { $0.id == noDate.id }))
        #expect(filtered.contains(where: { $0.id == keyedImported.id }) == false)

        var suppressed = Set<String>()
        let importedForSuppress = Schedule(
            name: "Imported",
            days: [],
            date: eventA.startDate,
            startTime: eventA.startDate,
            endTime: eventA.endDate,
            type: .focus,
            importedCalendarEventKey: "suppress-me"
        )
        #expect(
            CalendarImportService.suppressImportedCalendarEventIfNeeded(
                for: importedForSuppress,
                suppressedKeys: &suppressed
            ) == true
        )
        #expect(
            CalendarImportService.suppressImportedCalendarEventIfNeeded(
                for: importedForSuppress,
                suppressedKeys: &suppressed
            ) == false
        )

        let calendar = Calendar(identifier: .gregorian)
        let referenceNow = Date(timeIntervalSince1970: 1_700_000_000)
        let oldOneOff = Schedule(
            name: "Old one-off",
            days: [2],
            date: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60),
            startTime: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60),
            endTime: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60 + 600),
            type: .focus
        )
        let retainedOneOff = Schedule(
            name: "Retained one-off",
            days: [2],
            date: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60),
            startTime: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60),
            endTime: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60 + 600),
            type: .focus
        )
        let retainedRecurring = Schedule(
            name: "Recurring",
            days: [2],
            date: nil,
            startTime: referenceNow,
            endTime: referenceNow.addingTimeInterval(600),
            type: .focus
        )
        let prunedSchedules = CalendarImportService.pruneSchedulesOlderThanPreviousWeek(
            schedules: [oldOneOff, retainedOneOff, retainedRecurring],
            weekStartsOnMonday: false,
            now: referenceNow,
            calendar: calendar
        )
        #expect(prunedSchedules.contains(where: { $0.id == oldOneOff.id }) == false)
        #expect(prunedSchedules.contains(where: { $0.id == retainedOneOff.id }))
        #expect(prunedSchedules.contains(where: { $0.id == retainedRecurring.id }))

        let staleEvent = ExternalEvent(
            id: "stale-event",
            title: "Stale Event",
            startDate: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60),
            endDate: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60 + 300)
        )
        let retainedEvent = ExternalEvent(
            id: "retained-event",
            title: "Retained Event",
            startDate: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60),
            endDate: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60 + 300)
        )
        let crossingCutoffEvent = ExternalEvent(
            id: "crossing-cutoff-event",
            title: "Crossing Cutoff Event",
            startDate: referenceNow.addingTimeInterval(-22 * 24 * 60 * 60),
            endDate: referenceNow.addingTimeInterval(-2 * 24 * 60 * 60)
        )
        let prunedEvents = CalendarImportService.pruneCalendarEventsOlderThanPreviousWeek(
            events: [staleEvent, retainedEvent, crossingCutoffEvent],
            weekStartsOnMonday: false,
            now: referenceNow,
            calendar: calendar
        )
        #expect(prunedEvents.contains(where: { $0.id == staleEvent.id }) == false)
        #expect(prunedEvents.contains(where: { $0.id == retainedEvent.id }))
        #expect(prunedEvents.contains(where: { $0.id == crossingCutoffEvent.id }) == false)

        let fallbackBoundarySchedule = Schedule(
            name: "Fallback boundary",
            days: [2],
            date: referenceNow,
            startTime: referenceNow,
            endTime: referenceNow.addingTimeInterval(600),
            type: .focus
        )
        CalendarImportService.weekDateProvider = { _, _, _, _ in [] }
        defer { CalendarImportService.resetWeekDateProviderForTesting() }
        let fallbackPruned = CalendarImportService.pruneSchedulesOlderThanPreviousWeek(
            schedules: [fallbackBoundarySchedule],
            weekStartsOnMonday: false,
            now: referenceNow,
            calendar: calendar
        )
        #expect(fallbackPruned.contains(where: { $0.id == fallbackBoundarySchedule.id }))
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

    @Test("RuleSetService removeRule removes matching existing rule entry")
    func ruleSetServiceRemoveRuleExistingEntry() {
        var ruleSets = [RuleSet(name: "Main", urls: ["keep.com", "drop.com"])]
        let setId = ruleSets[0].id

        RuleSetService.removeRule("drop.com", from: setId, in: &ruleSets)

        #expect(ruleSets[0].urls.contains("drop.com") == false)
        #expect(ruleSets[0].urls.contains("keep.com"))
    }

    @Test("ScheduleEngine update occurrence removes malformed empty-days source schedule")
    func scheduleEngineUpdateOccurrenceRemovesEmptySourceDays() {
        let start = Date()
        let end = start.addingTimeInterval(600)
        let malformed = Schedule(
            name: "Malformed",
            days: [],
            date: nil,
            startTime: start,
            endTime: end,
            type: .focus
        )
        var schedules = [malformed]

        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: malformed.id,
            originalDay: 2,
            targetDay: 4,
            targetDate: nil,
            start: start.addingTimeInterval(60),
            end: end.addingTimeInterval(60)
        )

        #expect(schedules.count == 1)
        #expect(schedules[0].id != malformed.id)
        #expect(schedules[0].days == [4])
    }

    @Test("RuleSetService activeScheduleRuleSetIds ignores active break schedules")
    func ruleSetServiceActiveIdsIgnoresBreakSchedules() {
        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        let focusId = UUID()

        let activeBreak = Schedule(
            name: "Break",
            days: [weekday],
            startTime: now.addingTimeInterval(-60),
            endTime: now.addingTimeInterval(60),
            isEnabled: true,
            type: .unfocus,
            ruleSetId: UUID()
        )
        let activeFocus = Schedule(
            name: "Focus",
            days: [weekday],
            startTime: now.addingTimeInterval(-60),
            endTime: now.addingTimeInterval(60),
            isEnabled: true,
            type: .focus,
            ruleSetId: focusId
        )

        let ids = RuleSetService.activeScheduleRuleSetIds(from: [activeBreak, activeFocus])
        #expect(ids == [focusId])
    }

    @Test("ScheduleEngine updateScheduleOccurrence searches through non-matching IDs")
    func scheduleEngineUpdateOccurrenceFirstIndexClosureCoverage() {
        let start = Date()
        let end = start.addingTimeInterval(600)

        let first = Schedule(
            name: "First",
            days: [2],
            startTime: start,
            endTime: end,
            type: .focus
        )
        let second = Schedule(
            name: "Second",
            days: [2],
            startTime: start,
            endTime: end,
            type: .focus
        )
        var schedules = [first, second]

        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: second.id,
            originalDay: 2,
            targetDay: 3,
            targetDate: nil,
            start: start.addingTimeInterval(60),
            end: end.addingTimeInterval(60)
        )

        #expect(schedules.first(where: { $0.id == second.id })?.days == [3])
    }

    @Test("ScheduleEngine deleteSchedule searches through non-matching IDs")
    func scheduleEngineDeleteScheduleFirstIndexClosureCoverage() {
        let start = Date()
        let end = start.addingTimeInterval(600)

        let first = Schedule(
            name: "First",
            days: [2],
            startTime: start,
            endTime: end,
            type: .focus
        )
        let second = Schedule(
            name: "Second",
            days: [3],
            startTime: start,
            endTime: end,
            type: .focus
        )
        var schedules = [first, second]

        let removed = ScheduleEngine.deleteSchedule(
            in: &schedules,
            id: second.id,
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(removed?.id == second.id)
        #expect(schedules.count == 1)
        #expect(schedules[0].id == first.id)
    }

    @Test("ScheduleEngine updateScheduleOccurrence returns early when ID is missing")
    func scheduleEngineUpdateOccurrenceMissingIdCoverage() {
        let start = Date()
        let end = start.addingTimeInterval(600)
        let schedule = Schedule(
            name: "Only",
            days: [2],
            startTime: start,
            endTime: end,
            type: .focus
        )
        var schedules = [schedule]

        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: UUID(),
            originalDay: 2,
            targetDay: 3,
            targetDate: nil,
            start: start.addingTimeInterval(60),
            end: end.addingTimeInterval(60)
        )

        #expect(schedules.count == 1)
        #expect(schedules[0].id == schedule.id)
    }

    @Test("ScheduleEngine deleteSchedule returns nil when ID is missing")
    func scheduleEngineDeleteScheduleMissingIdCoverage() {
        let start = Date()
        let end = start.addingTimeInterval(600)
        let schedule = Schedule(
            name: "Only",
            days: [2],
            startTime: start,
            endTime: end,
            type: .focus
        )
        var schedules = [schedule]

        let removed = ScheduleEngine.deleteSchedule(
            in: &schedules,
            id: UUID(),
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(removed == nil)
        #expect(schedules.count == 1)
        #expect(schedules[0].id == schedule.id)
    }
}
