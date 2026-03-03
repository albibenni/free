import AppKit
import Foundation

enum ScheduleEditorSupport {
    struct Configuration {
        let name: String
        let days: Set<Int>
        let isRecurring: Bool
        let startTime: Date
        let endTime: Date
        let colorIndex: Int
        let type: ScheduleType
        let ruleSetId: UUID?
    }

    struct SavePayload {
        let days: Set<Int>
        let date: Date?
    }

    static func configuration(
        initialDay: Int?,
        initialStartTime: Date?,
        initialEndTime: Date?,
        existingSchedule: Schedule?
    ) -> Configuration {
        if let schedule = existingSchedule {
            return Configuration(
                name: schedule.name,
                days: schedule.days,
                isRecurring: schedule.date == nil,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                colorIndex: schedule.colorIndex,
                type: schedule.type,
                ruleSetId: schedule.ruleSetId
            )
        }

        let start =
            initialStartTime ?? Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
        let end = initialEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        return Configuration(
            name: "",
            days: initialDay.map { [$0] } ?? [2, 3, 4, 5, 6],
            isRecurring: false,
            startTime: start,
            endTime: end,
            colorIndex: 0,
            type: .focus,
            ruleSetId: nil
        )
    }

    static func savePayload(
        days: Set<Int>,
        isRecurring: Bool,
        initialDay: Int?,
        weekOffset: Int,
        weekStartsOnMonday: Bool
    ) -> SavePayload {
        guard !isRecurring else { return SavePayload(days: days, date: nil) }
        guard
            let targetDate = Schedule.calculateOneOffDate(
                initialDay: initialDay,
                weekOffset: weekOffset,
                weekStartsOnMonday: weekStartsOnMonday
            )
        else {
            return SavePayload(days: days, date: nil)
        }
        let weekday = Calendar.current.component(.weekday, from: targetDate)
        return SavePayload(days: [weekday], date: targetDate)
    }

    static func dayName(for day: Int) -> String {
        Calendar.current.weekdaySymbols[day - 1]
    }

    static func shouldShowAllowedList(for sessionType: ScheduleType) -> Bool {
        sessionType == .focus
    }

    static func isImportedSchedule(_ existingSchedule: Schedule?) -> Bool {
        existingSchedule?.importedCalendarEventKey != nil
    }

    static func canDeleteSchedule(existingSchedule: Schedule?) -> Bool {
        guard let existingSchedule else { return false }
        return existingSchedule.importedCalendarEventKey == nil
    }

    static func canEditImportedScheduleDetails(existingSchedule: Schedule?) -> Bool {
        !isImportedSchedule(existingSchedule)
    }

    static func shouldShowEditScope(existingSchedule: Schedule?, initialDay: Int?) -> Bool {
        guard let existingSchedule else { return false }
        guard initialDay != nil else { return false }
        return existingSchedule.days.count > 1
    }

    static func scheduleNamePlaceholder(for sessionType: ScheduleType) -> String {
        sessionType == .focus ? "Focus Session" : "Break Session"
    }

    static func shouldShowSingleDayBadge(
        existingSchedule: Schedule?,
        modifyAllDays: Bool,
        initialDay: Int?
    ) -> Bool {
        existingSchedule != nil && !modifyAllDays && initialDay != nil
    }

    static func weekDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        weekStartsOnMonday ? [2, 3, 4, 5, 6, 7, 1] : [1, 2, 3, 4, 5, 6, 7]
    }

    static func toggledDays(_ days: Set<Int>, day: Int) -> Set<Int> {
        var updated = days
        if updated.contains(day) {
            updated.remove(day)
        } else {
            updated.insert(day)
        }
        return updated
    }

    static func saveButtonTitle(
        existingSchedule: Schedule?,
        sessionType: ScheduleType
    ) -> String {
        if existingSchedule != nil { return "Save Changes" }
        return sessionType == .focus ? "Add Focus Session" : "Add Break Session"
    }

    static func primaryButtonColor(
        sessionType: ScheduleType,
        accentColorIndex: Int
    ) -> NSColor {
        sessionType == .focus ? FocusColor.nsColor(for: accentColorIndex) : .systemOrange
    }

    static func daySymbol(at index: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][index - 1]
    }

    static func isSaveDisabled(
        days: Set<Int>,
        modifyAllDays: Bool,
        isRecurring: Bool
    ) -> Bool {
        if !isRecurring { return false }
        return days.isEmpty && modifyAllDays
    }

    static func shouldApplyNewScheduleDefaults(existingSchedule: Schedule?) -> Bool {
        existingSchedule == nil
    }
}
