import Foundation

struct ScheduleEngine {
    struct AutomaticBlockingResult {
        let shouldBlock: Bool
        let normalizedManuallyPausedScheduleIds: Set<UUID>
    }

    static func todaySchedules(
        from schedules: [Schedule],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Schedule] {
        let weekday = calendar.component(.weekday, from: now)
        return schedules
            .filter { schedule in
                if let specificDate = schedule.date {
                    return calendar.isDate(specificDate, inSameDayAs: now)
                }
                return schedule.days.contains(weekday)
            }
            .sorted { lhs, rhs in
                Schedule.minutesSinceMidnight(for: lhs.startTime, calendar: calendar)
                    < Schedule.minutesSinceMidnight(for: rhs.startTime, calendar: calendar)
            }
    }

    static func automaticBlockingState(
        schedules: [Schedule],
        manuallyPausedScheduleIds: Set<UUID>,
        pomodoroIsFocus: Bool,
        pomodoroIsBreak: Bool,
        calendarIntegrationEnabled: Bool,
        isUnblockable: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> AutomaticBlockingResult {
        let activeSchedules = schedules.filter { $0.isActive() }
        let focusSchedules = activeSchedules.filter { $0.type == .focus }
        let activeFocusIds = Set(focusSchedules.map(\.id))
        let normalizedPaused = manuallyPausedScheduleIds.intersection(activeFocusIds)

        let hasFocus = focusSchedules.contains { !normalizedPaused.contains($0.id) } || pomodoroIsFocus
        let hasBreak = activeSchedules.contains { $0.type == .unfocus } || pomodoroIsBreak
        let hasMeeting =
            calendarIntegrationEnabled
            && !isUnblockable
            && !calendarImportsBlockTime
            && calendarEvents.contains { $0.isActive() }

        return AutomaticBlockingResult(
            shouldBlock: hasFocus && !hasBreak && !hasMeeting,
            normalizedManuallyPausedScheduleIds: normalizedPaused
        )
    }

    static func saveSchedule(
        in schedules: inout [Schedule],
        name: String,
        days: Set<Int>,
        date: Date?,
        start: Date,
        end: Date,
        color: Int,
        type: ScheduleType,
        ruleSet: UUID?,
        existingId: UUID?,
        modifyAllDays: Bool,
        initialDay: Int?
    ) {
        let finalName =
            name.trimmingCharacters(in: .whitespaces).isEmpty
            ? (type == .focus ? "Focus Session" : "Break Session")
            : name

        if let id = existingId, let index = schedules.firstIndex(where: { $0.id == id }) {
            if modifyAllDays {
                schedules[index].name = finalName
                schedules[index].days = days
                schedules[index].date = date
                schedules[index].startTime = start
                schedules[index].endTime = end
                schedules[index].colorIndex = color
                schedules[index].type = type
                schedules[index].ruleSetId = ruleSet
            } else if let day = initialDay {
                schedules[index].days.remove(day)
                if schedules[index].days.isEmpty {
                    schedules.remove(at: index)
                }
                schedules.append(
                    Schedule(
                        name: finalName,
                        days: [day],
                        date: date,
                        startTime: start,
                        endTime: end,
                        colorIndex: color,
                        type: type,
                        ruleSetId: ruleSet
                    )
                )
            }
            return
        }

        schedules.append(
            Schedule(
                name: finalName,
                days: days,
                date: date,
                startTime: start,
                endTime: end,
                colorIndex: color,
                type: type,
                ruleSetId: ruleSet
            )
        )
    }

    static func updateScheduleOccurrence(
        in schedules: inout [Schedule],
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        let schedule = schedules[index]
        guard schedule.importedCalendarEventKey == nil else { return }

        if schedule.date != nil {
            schedules[index].date = targetDate
            schedules[index].days = [targetDay]
            schedules[index].startTime = start
            schedules[index].endTime = end
            return
        }

        if schedule.days.count == 1, schedule.days.contains(originalDay) {
            schedules[index].days = [targetDay]
            schedules[index].startTime = start
            schedules[index].endTime = end
            return
        }

        schedules[index].days.remove(originalDay)
        if schedules[index].days.isEmpty {
            schedules.remove(at: index)
        }

        schedules.append(
            Schedule(
                name: schedule.name,
                days: [targetDay],
                startTime: start,
                endTime: end,
                isEnabled: schedule.isEnabled,
                colorIndex: schedule.colorIndex,
                type: schedule.type,
                ruleSetId: schedule.ruleSetId
            )
        )
    }

    static func deleteSchedule(
        in schedules: inout [Schedule],
        id: UUID,
        modifyAllDays: Bool,
        initialDay: Int?
    ) -> Schedule? {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return nil }
        if !modifyAllDays, let day = initialDay {
            schedules[index].days.remove(day)
            if schedules[index].days.isEmpty {
                return schedules.remove(at: index)
            }
            return nil
        }
        return schedules.remove(at: index)
    }
}
