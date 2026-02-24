import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct ScheduleRowTests {
    private final class ScheduleBox {
        var value: Schedule
        init(_ value: Schedule) { self.value = value }
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 420, height: 90)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func makeSchedule(type: ScheduleType, enabled: Bool = true) -> Schedule {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 10, minute: 30))!
        return Schedule(
            name: type == .focus ? "Focus Session" : "Break Session",
            days: [2, 3, 4],
            startTime: start,
            endTime: end,
            isEnabled: enabled,
            colorIndex: 0,
            type: type
        )
    }

    @Test("ScheduleRow renders focus schedule variant")
    @MainActor
    func focusRowRender() {
        let schedule = ScheduleBox(makeSchedule(type: .focus))
        let binding = Binding<Schedule>(
            get: { schedule.value },
            set: { schedule.value = $0 }
        )

        let row = ScheduleRow(
            schedule: binding,
            onDelete: {}
        )
        let hosted = host(row)

        #expect(hosted.fittingSize.width >= 0)
        #expect(schedule.value.type == .focus)
        #expect(schedule.value.isEnabled == true)
    }

    @Test("ScheduleRow renders break schedule variant")
    @MainActor
    func breakRowRender() {
        let schedule = ScheduleBox(makeSchedule(type: .unfocus, enabled: false))
        let binding = Binding<Schedule>(
            get: { schedule.value },
            set: { schedule.value = $0 }
        )

        let row = ScheduleRow(
            schedule: binding,
            onDelete: {}
        )
        let hosted = host(row)

        #expect(hosted.fittingSize.width >= 0)
        #expect(schedule.value.type == .unfocus)
        #expect(schedule.value.isEnabled == false)
    }

    @Test("ScheduleRow indicator color follows accent for focus and keeps theme for break")
    func scheduleRowIndicatorColorMapping() {
        let focusSchedule = makeSchedule(type: .focus)
        #expect(ScheduleRow.indicatorColor(for: focusSchedule, accentColorIndex: 3) == FocusColor.color(for: 3))

        var breakSchedule = makeSchedule(type: .unfocus)
        breakSchedule.colorIndex = 6
        #expect(ScheduleRow.indicatorColor(for: breakSchedule, accentColorIndex: 3) == breakSchedule.themeColor)
    }

    @Test("ScheduleRow import marker helper reflects imported key state")
    func scheduleRowImportedHelper() {
        var local = makeSchedule(type: .focus)
        local.importedCalendarEventKey = nil
        #expect(ScheduleRow.isImported(local) == false)

        var imported = makeSchedule(type: .focus)
        imported.importedCalendarEventKey = "calendar-event-1"
        #expect(ScheduleRow.isImported(imported) == true)
    }
}
