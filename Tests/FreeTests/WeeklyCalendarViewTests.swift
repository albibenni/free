import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct WeeklyCalendarViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "WeeklyCalendarViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 980, height: 860))
        -> NSHostingView<V>
    {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func sampleSchedule(
        name: String = "Focus",
        day: Int,
        date: Date? = nil,
        enabled: Bool = true
    ) -> Schedule {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        return Schedule(
            name: name,
            days: [day],
            date: date,
            startTime: start,
            endTime: end,
            isEnabled: enabled,
            colorIndex: 0,
            type: .focus
        )
    }

    @Test("WeeklyCalendarView action helpers cover drag, quick add, and schedule editor actions")
    @MainActor
    func weeklyCalendarActionHelpers() {
        let appState = isolatedAppState(name: "actions")
        var context: ScheduleEditorContext?
        let binding = Binding<ScheduleEditorContext?>(
            get: { context },
            set: { context = $0 }
        )

        let today = Calendar.current.component(.weekday, from: Date())
        let view = WeeklyCalendarView(
            editorContext: binding,
            actionAppState: appState,
            initialWeekOffset: 2
        )

        _ = view.weekOffsetForTesting
        view.goToPreviousWeek()
        view.goToCurrentWeek()
        view.goToNextWeek()
        _ = view.weekOffsetForTesting

        view.handleDragChanged(day: today, startY: 80, currentY: 82)
        _ = view.dragDataForTesting
        view.handleDragChanged(day: today, startY: 80, currentY: 140)
        _ = view.dragDataForTesting
        let seeded = WeeklyCalendarView(
            editorContext: binding,
            actionAppState: appState,
            initialDragData: .init(day: today, startHour: 9.0, endHour: 9.25)
        )
        seeded.handleDragChanged(day: today, startY: 80, currentY: 200)
        seeded.handleDragEnded(day: today, startY: 80)
        #expect(context?.day == today)
        #expect(context?.schedule == nil)

        seeded.finalizeDrag(.init(day: today, startHour: 11.0, endHour: 11.5))
        #expect(context?.day == today)

        context = nil
        view.handleDragEnded(day: today, startY: 400)
        #expect(context?.day == today)
        #expect(context?.schedule == nil)

        let schedule = sampleSchedule(day: today)
        let openEditor = view.openScheduleEditorAction(day: today, schedule: schedule)
        openEditor()
        #expect(context?.schedule?.id == schedule.id)
    }

    @Test("WeeklyCalendarView preview and formatting helpers cover static and instance paths")
    @MainActor
    func weeklyCalendarPreviewAndFormattingHelpers() {
        let appState = isolatedAppState(name: "preview")
        appState.weekStartsOnMonday = false

        var context: ScheduleEditorContext?
        let binding = Binding<ScheduleEditorContext?>(
            get: { context },
            set: { context = $0 }
        )
        let view = WeeklyCalendarView(editorContext: binding, actionAppState: appState)

        let validMetrics = WeeklyCalendarView.dragPreviewMetrics(
            data: .init(day: 2, startHour: 9.1, endHour: 10.4),
            dayOrder: [1, 2, 3, 4, 5, 6, 7],
            geometryWidth: 980,
            timeLabelWidth: 50,
            timeColumnGutter: 10,
            hourHeight: 80
        )
        #expect(validMetrics != nil)
        #expect(validMetrics?.height ?? 0 > 0)

        let missingMetrics = WeeklyCalendarView.dragPreviewMetrics(
            data: .init(day: 9, startHour: 9.0, endHour: 9.0),
            dayOrder: [1, 2, 3, 4, 5, 6, 7],
            geometryWidth: 980,
            timeLabelWidth: 50,
            timeColumnGutter: 10,
            hourHeight: 80
        )
        #expect(missingMetrics == nil)

        let instanceMetrics = view.dragPreviewMetrics(
            data: .init(day: 2, startHour: 13.0, endHour: 13.0),
            geometryWidth: 980
        )
        #expect(instanceMetrics != nil)
        #expect(instanceMetrics?.height == 20)

        _ = view.formatTime(9.5)
        _ = view.timeString(hour: 12)
        let today = Calendar.current.component(.weekday, from: Date())
        #expect(view.isToday(day: today))
    }

    @Test("WeeklyCalendarView calendar-event and schedule visibility helpers")
    @MainActor
    func weeklyCalendarVisibilityHelpers() {
        let appState = isolatedAppState(name: "visibility")

        var context: ScheduleEditorContext?
        let binding = Binding<ScheduleEditorContext?>(
            get: { context },
            set: { context = $0 }
        )
        let view = WeeklyCalendarView(editorContext: binding, actionAppState: appState)

        let calendar = Calendar.current
        let week = WeeklyCalendarView.getWeekDates(
            at: Date(),
            weekStartsOnMonday: appState.weekStartsOnMonday,
            offset: 0
        )
        let weekStart = week.first ?? Date()
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: week.last ?? Date()) ?? Date()
        let insideStart = calendar.date(byAdding: .hour, value: 2, to: weekStart) ?? weekStart
        let insideEnd = calendar.date(byAdding: .hour, value: 3, to: weekStart) ?? weekStart
        let outsideStart = calendar.date(byAdding: .hour, value: 2, to: weekEnd) ?? weekEnd
        let outsideEnd = calendar.date(byAdding: .hour, value: 3, to: weekEnd) ?? weekEnd

        let insideEvent = ExternalEvent(
            id: "in-week",
            title: "In Week",
            startDate: insideStart,
            endDate: insideEnd
        )
        let outsideEvent = ExternalEvent(
            id: "out-week",
            title: "Out Week",
            startDate: outsideStart,
            endDate: outsideEnd
        )
        appState.calendarProvider.events = [insideEvent, outsideEvent]

        let visibleEvents = view.visibleCalendarEvents(weekStart: weekStart, weekEnd: weekEnd)
        #expect(visibleEvents.count == 1)
        #expect(visibleEvents.first?.id == "in-week")

        let weekday = calendar.component(.weekday, from: weekStart)
        let recurring = sampleSchedule(name: "Recurring", day: weekday, date: nil)
        let oneOffInside = sampleSchedule(name: "OneOffIn", day: weekday, date: weekStart)
        let oneOffOutside = sampleSchedule(name: "OneOffOut", day: weekday, date: outsideStart)

        #expect(view.shouldDisplaySchedule(recurring, weekStart: weekStart, weekEnd: weekEnd))
        #expect(view.shouldDisplaySchedule(oneOffInside, weekStart: weekStart, weekEnd: weekEnd))
        #expect(view.shouldDisplaySchedule(oneOffOutside, weekStart: weekStart, weekEnd: weekEnd) == false)
    }

    @Test("WeeklyCalendarView and related block views render event, drag-preview, and time-indicator paths")
    @MainActor
    func weeklyCalendarRenderPaths() {
        let appState = isolatedAppState(name: "render")
        appState.calendarIntegrationEnabled = true

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.component(.weekday, from: now)

        appState.schedules = [sampleSchedule(day: today)]
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "render-event",
                title: "Meeting",
                startDate: now.addingTimeInterval(-1800),
                endDate: now.addingTimeInterval(1800)
            )
        ]

        var context: ScheduleEditorContext?
        let binding = Binding<ScheduleEditorContext?>(
            get: { context },
            set: { context = $0 }
        )

        let weeklyView = WeeklyCalendarView(
            editorContext: binding,
            actionAppState: appState,
            initialDragData: .init(day: today, startHour: 9.0, endHour: 10.0)
        ).environmentObject(appState)
        let weeklyHost = host(weeklyView, size: CGSize(width: 980, height: 860))
        #expect(weeklyHost.fittingSize.height >= 0)

        let externalHost = host(
            ExternalEventBlockView(event: appState.calendarProvider.events[0]),
            size: CGSize(width: 220, height: 80)
        )
        #expect(externalHost.fittingSize.width >= 0)

        let indicatorInWeek = CurrentTimeIndicator(
            hourHeight: 80,
            timeLabelWidth: 60,
            dayOrder: WeeklyCalendarView.getDayOrder(weekStartsOnMonday: false),
            weekStart: now.addingTimeInterval(-24 * 60 * 60),
            weekEnd: now.addingTimeInterval(24 * 60 * 60)
        )
        _ = indicatorInWeek.timer
        indicatorInWeek.updateTime()
        let indicatorInWeekHost = host(indicatorInWeek, size: CGSize(width: 900, height: 120))
        #expect(indicatorInWeekHost.fittingSize.height >= 0)

        let indicatorOutOfWeek = CurrentTimeIndicator(
            hourHeight: 80,
            timeLabelWidth: 60,
            dayOrder: WeeklyCalendarView.getDayOrder(weekStartsOnMonday: false),
            weekStart: now.addingTimeInterval(24 * 60 * 60),
            weekEnd: now.addingTimeInterval(2 * 24 * 60 * 60)
        )
        _ = indicatorOutOfWeek.timer
        indicatorOutOfWeek.updateTime()
        let indicatorOutOfWeekHost = host(
            indicatorOutOfWeek,
            size: CGSize(width: 900, height: 120)
        )
        #expect(indicatorOutOfWeekHost.fittingSize.width >= 0)
    }
}
