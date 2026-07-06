import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct WeeklyCalendarViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "WeeklyCalendarViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(_ view: NSView, size: CGSize = CGSize(width: 980, height: 860)) -> NSView {
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        return view
    }

    private func sampleSchedule(
        name: String = "Focus",
        day: Int,
        date: Date? = nil,
        enabled: Bool = true,
        colorIndex: Int = 0,
        type: ScheduleType = .focus
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
            colorIndex: colorIndex,
            type: type
        )
    }

    @Test("WeeklyCalendar support preview and formatting helpers cover shared math")
    func weeklyCalendarPreviewAndFormattingHelpers() async throws {
        let mondayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: true)
        #expect(mondayOrder == [2, 3, 4, 5, 6, 7, 1])

        let now = Date()
        let normalBounds = WeeklyCalendarSupport.weekBounds(for: [now])
        #expect(normalBounds.0 == now)
        #expect(normalBounds.1 > normalBounds.0)

        let emptyBounds = WeeklyCalendarSupport.weekBounds(for: [])
        #expect(emptyBounds.0 == .distantPast)
        #expect(emptyBounds.1 == .distantFuture)

        let validMetrics = WeeklyCalendarSupport.dragPreviewMetrics(
            data: .init(day: 2, startHour: 9.1, endHour: 10.4),
            dayOrder: [1, 2, 3, 4, 5, 6, 7],
            geometryWidth: 980,
            timeLabelWidth: 50,
            timeColumnGutter: 10,
            hourHeight: 80
        )
        #expect(validMetrics != nil)
        #expect(validMetrics?.height ?? 0 > 0)

        let missingMetrics = WeeklyCalendarSupport.dragPreviewMetrics(
            data: .init(day: 9, startHour: 9.0, endHour: 9.0),
            dayOrder: [1, 2, 3, 4, 5, 6, 7],
            geometryWidth: 980,
            timeLabelWidth: 50,
            timeColumnGutter: 10,
            hourHeight: 80
        )
        #expect(missingMetrics == nil)

        let snappedMoveTranslation = WeeklyCalendarSupport.snappedInteractionTranslation(
            translation: CGSize(width: 15, height: 30),
            mode: .move,
            columnWidth: 100,
            hourHeight: 80
        )
        #expect(snappedMoveTranslation.width == 0)
        #expect(snappedMoveTranslation.height == 40)

        let movedPreview = WeeklyCalendarSupport.previewFrame(
            baseFrame: CGRect(x: 10, y: 20, width: 50, height: 80),
            translation: snappedMoveTranslation,
            mode: .move
        )
        #expect(movedPreview.origin.x == 10)
        #expect(movedPreview.origin.y == 60)

        let snappedResizeTranslation = WeeklyCalendarSupport.snappedInteractionTranslation(
            translation: CGSize(width: 18, height: 30),
            mode: .resizeStart,
            columnWidth: 100,
            hourHeight: 80
        )
        #expect(snappedResizeTranslation.width == 0)
        #expect(snappedResizeTranslation.height == 40)

        let resizedTopPreview = WeeklyCalendarSupport.previewFrame(
            baseFrame: CGRect(x: 10, y: 20, width: 50, height: 80),
            translation: snappedResizeTranslation,
            mode: .resizeStart
        )
        #expect(resizedTopPreview.origin.y == 60)
        #expect(resizedTopPreview.height == 40)

        let resizedBottomPreview = WeeklyCalendarSupport.previewFrame(
            baseFrame: CGRect(x: 10, y: 20, width: 50, height: 20),
            translation: CGSize(width: 0, height: -30),
            mode: .resizeEnd
        )
        #expect(resizedBottomPreview.height == 15)

        #expect(WeeklyCalendarSupport.snappedMinuteDelta(translationHeight: 40, hourHeight: 80) == 30)
        #expect(WeeklyCalendarSupport.snappedDayDelta(translationWidth: 120, columnWidth: 100) == 1)
        #expect(
            WeeklyCalendarSupport.dayDelta(
                cursorX: 171,
                calendarAreaX: 60,
                columnWidth: 100,
                dayCount: 7,
                originalColumnIndex: 0
            ) == 1
        )
        #expect(
            WeeklyCalendarSupport.dayDelta(
                cursorX: 159,
                calendarAreaX: 60,
                columnWidth: 100,
                dayCount: 7,
                originalColumnIndex: 0
            ) == 0
        )
        #expect(
            WeeklyCalendarSupport.dayDelta(
                cursorX: 159,
                calendarAreaX: 60,
                columnWidth: 0,
                dayCount: 7,
                originalColumnIndex: 0
            ) == 0
        )
        #expect(WeeklyCalendarSupport.shiftedWeekday(1, by: -1) == 7)

        let previewLabels = WeeklyCalendarSupport.selectionPreviewLabels(startHour: 9.1, endHour: 10.2)
        #expect(previewLabels.start == WeeklyCalendarSupport.formatTime(9.0))
        #expect(previewLabels.end == WeeklyCalendarSupport.formatTime(10.25))

        let correctedDrag = WeeklyCalendarSupport.calculateDragSelection(startHour: 2.5, endHour: 2.5)
        #expect(correctedDrag.end > correctedDrag.start)

        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 23, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 1, minute: 0))!
        let overnightRect = WeeklyCalendarSupport.calculateRect(
            startDate: start,
            endDate: end,
            colIndex: 0,
            columnWidth: 100,
            hourHeight: 80
        )
        #expect(overnightRect != nil)
        #expect((overnightRect?.height ?? 0) > 0)

        #expect(WeeklyCalendarSupport.dayName(for: 1) == Calendar.current.shortWeekdaySymbols[0])
        #expect(!WeeklyCalendarSupport.timeString(hour: 12).isEmpty)
        #expect(!WeeklyCalendarSupport.formattedTime(start, calendar: calendar).isEmpty)
        #expect(!WeeklyCalendarSupport.monthYearString(for: now, calendar: calendar).isEmpty)
    }

    @Test("WeeklyCalendar support normalized interval handles overnight end-time rollover")
    func weeklyCalendarNormalizedIntervalOvernightRollover() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: base) ?? base
        let end = calendar.date(bySettingHour: 0, minute: 15, second: 0, of: base) ?? base

        let interval = WeeklyCalendarSupport.normalizedInterval(
            startDate: start,
            endDate: end,
            calendar: calendar
        )
        #expect(interval.end > interval.start)
        #expect(abs(interval.end.timeIntervalSince(interval.start) - (45 * 60)) < 1)
    }

    @Test("WeeklyCalendar support schedule drag and resize update helpers produce snapped results")
    func weeklyCalendarScheduleUpdateHelpers() async throws {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: Date())
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "placement",
            day: 2,
            startDate: start,
            endDate: end
        )
        let weekRange = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: anchorDay) }

        let moved = WeeklyCalendarSupport.scheduleUpdate(
            placement: placement,
            translation: CGSize(width: 120, height: 40),
            mode: .move,
            columnWidth: 100,
            hourHeight: 80,
            weekRange: weekRange
        )
        #expect(moved?.targetDay == 3)
        #expect(calendar.component(.hour, from: moved?.start ?? start) == 9)
        #expect(calendar.component(.minute, from: moved?.start ?? start) == 30)

        let movedByCursorColumn = WeeklyCalendarSupport.scheduleUpdate(
            placement: placement,
            translation: CGSize(width: 20, height: 40),
            mode: .move,
            columnWidth: 100,
            hourHeight: 80,
            weekRange: weekRange,
            resolvedDayDelta: 1
        )
        #expect(movedByCursorColumn?.targetDay == 3)

        let movePreview = WeeklyCalendarSupport.schedulePreviewLabels(
            placement: placement,
            translation: CGSize(width: 120, height: 40),
            mode: .move,
            hourHeight: 80,
            calendar: calendar
        )
        #expect(movePreview.start == WeeklyCalendarSupport.formattedTime(
            calendar.date(from: DateComponents(hour: 9, minute: 30))!,
            calendar: calendar
        ))
        #expect(movePreview.end == WeeklyCalendarSupport.formattedTime(
            calendar.date(from: DateComponents(hour: 10, minute: 30))!,
            calendar: calendar
        ))

        let resizeStartPreview = WeeklyCalendarSupport.schedulePreviewLabels(
            placement: placement,
            translation: CGSize(width: 0, height: 40),
            mode: .resizeStart,
            hourHeight: 80,
            calendar: calendar
        )
        #expect(resizeStartPreview.start == WeeklyCalendarSupport.formattedTime(
            calendar.date(from: DateComponents(hour: 9, minute: 30))!,
            calendar: calendar
        ))
        #expect(resizeStartPreview.end == WeeklyCalendarSupport.formattedTime(end, calendar: calendar))

        let resizeEndPreview = WeeklyCalendarSupport.schedulePreviewLabels(
            placement: placement,
            translation: CGSize(width: 0, height: -200),
            mode: .resizeEnd,
            hourHeight: 80,
            calendar: calendar
        )
        #expect(resizeEndPreview.start == WeeklyCalendarSupport.formattedTime(start, calendar: calendar))
        #expect(resizeEndPreview.end == WeeklyCalendarSupport.formattedTime(
            calendar.date(from: DateComponents(hour: 9, minute: 15))!,
            calendar: calendar
        ))

        let resizedStart = WeeklyCalendarSupport.scheduleUpdate(
            placement: placement,
            translation: CGSize(width: 0, height: 40),
            mode: .resizeStart,
            columnWidth: 100,
            hourHeight: 80,
            weekRange: weekRange
        )
        #expect(calendar.component(.hour, from: resizedStart?.start ?? start) == 9)
        #expect(calendar.component(.minute, from: resizedStart?.start ?? start) == 30)

        let resizedEnd = WeeklyCalendarSupport.scheduleUpdate(
            placement: placement,
            translation: CGSize(width: 0, height: -200),
            mode: .resizeEnd,
            columnWidth: 100,
            hourHeight: 80,
            weekRange: weekRange
        )
        #expect(calendar.component(.hour, from: resizedEnd?.end ?? end) == 9)
        #expect(calendar.component(.minute, from: resizedEnd?.end ?? end) == 15)

        var imported = sampleSchedule(day: 2)
        imported.importedCalendarEventKey = "imported"
        #expect(!WeeklyCalendarSupport.canDirectlyManipulate(imported))
        #expect(WeeklyCalendarSupport.canDirectlyManipulate(sampleSchedule(day: 2)))

        let bounds = CGRect(x: 0, y: 0, width: 100, height: 120)
        #expect(
            WeeklyCalendarSupport.interactionMode(
                at: CGPoint(x: 50, y: 5),
                in: bounds,
                edgeHeight: 18
            ) == .resizeStart
        )
        #expect(
            WeeklyCalendarSupport.interactionMode(
                at: CGPoint(x: 50, y: 60),
                in: bounds,
                edgeHeight: 18
            ) == .move
        )
        #expect(
            WeeklyCalendarSupport.interactionMode(
                at: CGPoint(x: 50, y: 115),
                in: bounds,
                edgeHeight: 18
            ) == .resizeEnd
        )
        #expect(WeeklyCalendarSupport.effectiveResizeHandleHeight(boundsHeight: 120, preferredHeight: 18) == 6)
        #expect(WeeklyCalendarSupport.effectiveResizeHandleHeight(boundsHeight: 0, preferredHeight: 18) == 0)
    }

    @Test("WeeklyCalendar support calendar-event and schedule visibility helpers")
    func weeklyCalendarVisibilityHelpers() async throws {
        let calendar = Calendar.current
        let week = WeeklyCalendarSupport.getWeekDates(
            at: Date(),
            weekStartsOnMonday: false,
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

        let visibleEvents = WeeklyCalendarSupport.visibleCalendarEvents(
            [insideEvent, outsideEvent],
            weekStart: weekStart,
            weekEnd: weekEnd
        )
        #expect(visibleEvents.count == 1)
        #expect(visibleEvents.first?.id == "in-week")

        let weekday = calendar.component(.weekday, from: weekStart)
        let recurring = sampleSchedule(name: "Recurring", day: weekday, date: nil)
        let oneOffInside = sampleSchedule(name: "OneOffIn", day: weekday, date: weekStart)
        let oneOffOutside = sampleSchedule(name: "OneOffOut", day: weekday, date: outsideStart)

        #expect(
            WeeklyCalendarSupport.shouldDisplaySchedule(
                recurring,
                weekStart: weekStart,
                weekEnd: weekEnd
            )
        )
        #expect(
            WeeklyCalendarSupport.shouldDisplaySchedule(
                oneOffInside,
                weekStart: weekStart,
                weekEnd: weekEnd
            )
        )
        #expect(
            WeeklyCalendarSupport.shouldDisplaySchedule(
                oneOffOutside,
                weekStart: weekStart,
                weekEnd: weekEnd
            ) == false
        )

        let importedOneOff = Schedule(
            name: "Imported One-off",
            days: [],
            date: weekStart,
            startTime: oneOffInside.startTime,
            endTime: oneOffInside.endTime,
            isEnabled: true,
            colorIndex: 0,
            type: .focus,
            ruleSetId: nil,
            importedCalendarEventKey: "imported-key"
        )
        let placements = WeeklyCalendarSupport.schedulePlacements(
            for: importedOneOff,
            weekRange: week
        )
        #expect(placements.count == 1)
        #expect(placements.first?.day == calendar.component(.weekday, from: weekStart))

        #expect(WeeklyCalendarSupport.blockFillOpacity(isImported: false) == 0.8)
        #expect(WeeklyCalendarSupport.blockFillOpacity(isImported: true) == 0.5)
        #expect(WeeklyCalendarSupport.blockBorderOpacity(isImported: false) == 0.95)
        #expect(WeeklyCalendarSupport.blockBorderOpacity(isImported: true) == 0.72)
        #expect(WeeklyCalendarSupport.primarySymbolName(for: recurring) == "target")
        #expect(WeeklyCalendarSupport.importedSymbolName(for: recurring) == nil)
        #expect(WeeklyCalendarSupport.importedSymbolName(for: importedOneOff) == "calendar.badge.clock")

        var breakSchedule = recurring
        breakSchedule.type = .unfocus
        #expect(WeeklyCalendarSupport.primarySymbolName(for: breakSchedule) == "cup.and.saucer.fill")

        let overlappingA = Schedule(
            name: "Overlap A",
            days: [weekday],
            startTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: weekStart) ?? weekStart,
            endTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: weekStart) ?? weekStart
        )
        let overlappingB = Schedule(
            name: "Overlap B",
            days: [weekday],
            startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: weekStart) ?? weekStart,
            endTime: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: weekStart) ?? weekStart
        )
        let positioned = WeeklyCalendarSupport.positionedSchedules(
            schedules: [overlappingA, overlappingB],
            weekRange: week
        )
        #expect(positioned.count == 2)
        #expect(Set(positioned.map(\.laneIndex)) == [0, 1])
        #expect(positioned.allSatisfy { $0.laneCount == 2 })

        let splitRect = WeeklyCalendarSupport.calculateRect(
            startDate: overlappingA.startTime,
            endDate: overlappingA.endTime,
            colIndex: 0,
            columnWidth: 100,
            laneIndex: 1,
            laneCount: 2,
            hourHeight: 80
        )
        #expect(splitRect?.width == 48)
        #expect(splitRect?.minX == 50)
    }

    @Test("WeeklyCalendar support positioned-schedule sorting covers tie-break and lane-reuse branches")
    func weeklyCalendarPositionedScheduleSortAndLaneBranches() async throws {
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: Date())
        let start9 = calendar.date(byAdding: .hour, value: 9, to: baseDay)!
        let end10 = calendar.date(byAdding: .hour, value: 10, to: baseDay)!
        let end11 = calendar.date(byAdding: .hour, value: 11, to: baseDay)!
        let start12 = calendar.date(byAdding: .hour, value: 12, to: baseDay)!
        let end13 = calendar.date(byAdding: .hour, value: 13, to: baseDay)!
        let weekday = calendar.component(.weekday, from: baseDay)

        let template = Schedule(
            name: "TieBreak",
            days: [weekday],
            startTime: start9,
            endTime: end10
        )

        let placements: [(schedule: Schedule, placement: WeeklyCalendarSupport.SchedulePlacement)] = [
            (
                schedule: template,
                placement: .init(id: "b", day: weekday, startDate: start9, endDate: end11)
            ),
            (
                schedule: template,
                placement: .init(id: "a", day: weekday, startDate: start9, endDate: end11)
            ),
            (
                schedule: template,
                placement: .init(id: "c", day: weekday, startDate: start9, endDate: end10)
            ),
            (
                schedule: template,
                placement: .init(id: "d", day: weekday, startDate: start12, endDate: end13)
            ),
            (
                schedule: template,
                placement: .init(id: "z", day: weekday, startDate: start9, endDate: end11)
            ),
            (
                schedule: template,
                placement: .init(id: "z", day: weekday, startDate: start9, endDate: end11)
            ),
        ]

        let positioned = WeeklyCalendarSupport.positionedSchedules(from: placements, calendar: calendar)
        #expect(positioned.count == 6)
        #expect(positioned.map(\.id).contains("a"))
        #expect(positioned.map(\.id).contains("b"))
        #expect(positioned.map(\.id).contains("c"))
        #expect(positioned.map(\.id).contains("d"))

        // Later non-overlapping schedule should reuse lane 0.
        #expect(positioned.first(where: { $0.id == "d" })?.laneIndex == 0)
    }

    @Test("WeeklyCalendar AppKit surface lays out header, scroller, and schedule blocks")
    @MainActor
    func weeklyCalendarSurfaceLayout() async throws {
        let calendar = Calendar.current
        let weekRange = WeeklyCalendarSupport.getWeekDates(
            at: Date(),
            weekStartsOnMonday: false,
            offset: 0
        )
        let bounds = WeeklyCalendarSupport.weekBounds(for: weekRange)
        let weekday = calendar.component(.weekday, from: weekRange[0])
        let schedules = [
            sampleSchedule(name: "Morning", day: weekday),
            Schedule(
                name: "Overlap",
                days: [weekday],
                startTime: calendar.date(from: DateComponents(hour: 9, minute: 30))!,
                endTime: calendar.date(from: DateComponents(hour: 10, minute: 30))!,
                colorIndex: 1,
                type: .focus
            ),
        ]
        let visibleEvent = ExternalEvent(
            id: "event",
            title: "Meeting",
            startDate: calendar.date(byAdding: .hour, value: 1, to: weekRange[0]) ?? weekRange[0],
            endDate: calendar.date(byAdding: .hour, value: 2, to: weekRange[0]) ?? weekRange[0]
        )

        let surface = WeeklyCalendarSurfaceNSView()
        surface.configure(
            with: WeeklyCalendarSurfaceConfiguration(
                dayOrder: WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false),
                weekRange: weekRange,
                weekStart: bounds.0,
                weekEnd: bounds.1,
                positionedSchedules: WeeklyCalendarSupport.positionedSchedules(
                    schedules: schedules,
                    weekRange: weekRange
                ),
                externalEvents: [visibleEvent],
                showsExternalEvents: true,
                hourHeight: 80,
                dayHeaderHeight: 40,
                timeLabelWidth: 60,
                timeColumnGutter: 12,
                accentColor: .systemBlue,
                onQuickAdd: { _, _ in },
                onCreateSelection: { _, _, _ in },
                onOpenSchedule: { _, _ in },
                onUpdateSchedule: { _, _, _, _, _, _ in }
            )
        )

        let hosted = host(surface, size: CGSize(width: 980, height: 860))
        #expect(hosted.fittingSize.width >= 0)
        #expect(surface.headerHeightForTesting >= 56)
        #expect(Int(surface.documentHeightForTesting) == Int(24.0 * 80.0))
        #expect(surface.hasVerticalScrollerForTesting)
        #expect(surface.didInitialScrollForTesting)
        #expect(surface.scheduleBlockCountForTesting == 2)

        surface.configure(
            with: WeeklyCalendarSurfaceConfiguration(
                dayOrder: WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false),
                weekRange: weekRange,
                weekStart: bounds.0,
                weekEnd: bounds.1,
                positionedSchedules: [],
                externalEvents: [],
                showsExternalEvents: false,
                hourHeight: 80,
                dayHeaderHeight: 40,
                timeLabelWidth: 60,
                timeColumnGutter: 12,
                accentColor: .systemBlue,
                onQuickAdd: { _, _ in },
                onCreateSelection: { _, _, _ in },
                onOpenSchedule: { _, _ in },
                onUpdateSchedule: { _, _, _, _, _, _ in }
            )
        )
        surface.layoutSubtreeIfNeeded()
        #expect(surface.scheduleBlockCountForTesting == 0)
    }

    @Test("Schedules sheet controller week navigation updates AppKit calendar configuration")
    @MainActor
    func schedulesSheetWeekNavigation() async throws {
        let appState = isolatedAppState(name: "calendar-navigation")
        let weekday = Calendar.current.component(.weekday, from: Date())
        appState.schedules = [sampleSchedule(day: weekday)]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        let hosted = host(controller.view, size: CGSize(width: 900, height: 760))
        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.weekOffsetForTesting == 0)

        let initialWeekStart = controller.calendarConfigurationForTesting.weekRange.first!

        controller.goToNextWeekForTesting()
        let nextWeekStart = controller.calendarConfigurationForTesting.weekRange.first!
        let forwardDelta = Calendar.current.dateComponents([.day], from: initialWeekStart, to: nextWeekStart).day
        #expect(controller.weekOffsetForTesting == 1)
        #expect(forwardDelta == 7)

        controller.goToPreviousWeekForTesting()
        #expect(controller.weekOffsetForTesting == 0)

        controller.goToPreviousWeekForTesting()
        let previousWeekStart = controller.calendarConfigurationForTesting.weekRange.first!
        let backwardDelta = Calendar.current.dateComponents([.day], from: previousWeekStart, to: initialWeekStart).day
        #expect(controller.weekOffsetForTesting == -1)
        #expect(backwardDelta == 7)

        controller.goToPreviousWeekForTesting()
        #expect(controller.weekOffsetForTesting == -1)
        #expect(controller.calendarConfigurationForTesting.weekRange.first == previousWeekStart)

        controller.goToCurrentWeekForTesting()
        #expect(controller.weekOffsetForTesting == 0)
        #expect(controller.calendarConfigurationForTesting.weekRange.first == initialWeekStart)

        appState.calendarIntegrationEnabled = true
        #expect(controller.calendarConfigurationForTesting.showsExternalEvents)
        #expect(!controller.monthTitleForTesting.isEmpty)
    }
}
