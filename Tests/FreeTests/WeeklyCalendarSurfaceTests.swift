import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct WeeklyCalendarSurfaceTests {
    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    private func makeSchedule(
        name: String,
        day: Int,
        importedKey: String? = nil
    ) -> Schedule {
        Schedule(
            name: name,
            days: [day],
            startTime: makeDate(hour: 9),
            endTime: makeDate(hour: 10),
            colorIndex: 1,
            type: .focus,
            importedCalendarEventKey: importedKey
        )
    }

    private func makeConfiguration(
        dayOrder: [Int],
        weekRange: [Date],
        weekStart: Date,
        weekEnd: Date,
        positionedSchedules: [WeeklyCalendarSupport.PositionedSchedule],
        externalEvents: [ExternalEvent] = [],
        showsExternalEvents: Bool = false,
        onQuickAdd: @escaping (Int, Int) -> Void = { _, _ in },
        onCreateSelection: @escaping (Int, CGFloat, CGFloat) -> Void = { _, _, _ in },
        onOpenSchedule: @escaping (Int, Schedule) -> Void = { _, _ in },
        onUpdateSchedule: @escaping (UUID, Int, Int, Date?, Date, Date) -> Void = {
            _, _, _, _, _, _ in
        }
    ) -> WeeklyCalendarSurfaceConfiguration {
        WeeklyCalendarSurfaceConfiguration(
            dayOrder: dayOrder,
            weekRange: weekRange,
            weekStart: weekStart,
            weekEnd: weekEnd,
            positionedSchedules: positionedSchedules,
            externalEvents: externalEvents,
            showsExternalEvents: showsExternalEvents,
            hourHeight: 80,
            dayHeaderHeight: 56,
            timeLabelWidth: 60,
            timeColumnGutter: 12,
            accentColor: .systemOrange,
            onQuickAdd: onQuickAdd,
            onCreateSelection: onCreateSelection,
            onOpenSchedule: onOpenSchedule,
            onUpdateSchedule: onUpdateSchedule
        )
    }

    private func mirrorValue<T>(_ name: String, in root: Any) -> T? {
        var mirror: Mirror? = Mirror(reflecting: root)
        while let current = mirror {
            for child in current.children where child.label == name {
                return child.value as? T
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    @Test("Weekly calendar support hook fallbacks cover nil builder and overnight normalization")
    func weeklyCalendarSupportHookFallbackCoverage() throws {
        defer { WeeklyCalendarSupport.resetCalendarHooksForTesting() }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        let defaultHourSet = WeeklyCalendarSupport.calendarHourSetter(calendar, 8, 45, anchor)
        #expect(defaultHourSet != nil)
        let defaultTimeOnly = WeeklyCalendarSupport.calendarDateBuilder(
            calendar,
            DateComponents(hour: 8, minute: 45)
        )
        #expect(defaultTimeOnly != nil)

        WeeklyCalendarSupport.calendarHourSetter = { _, _, _, _ in nil }
        WeeklyCalendarSupport.calendarDateBuilder = { _, _ in nil }

        let start = try #require(calendar.date(from: DateComponents(hour: 23, minute: 30)))
        let end = try #require(calendar.date(from: DateComponents(hour: 1, minute: 15)))

        let normalized = WeeklyCalendarSupport.normalizedInterval(
            startDate: start,
            endDate: end,
            calendar: calendar
        )
        #expect(normalized.end > normalized.start)

        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "fallback",
            day: 2,
            startDate: start,
            endDate: end
        )
        let wrapped = WeeklyCalendarSupport.normalizedInterval(for: placement, calendar: calendar)
        #expect(wrapped.end > wrapped.start)

        let fallbackTimeOnly = WeeklyCalendarSupport.timeOnlyDate(from: start, calendar: calendar)
        #expect(fallbackTimeOnly == start)
    }

    @Test("Weekly calendar support schedule helpers cover visibility, labels, and style metadata")
    func weeklyCalendarSupportScheduleHelpersCoverage() throws {
        let calendar = Calendar.current
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let bounds = WeeklyCalendarSupport.weekBounds(for: weekRange, calendar: calendar)
        let inWeekDate = try #require(weekRange.first)
        let outOfWeekDate = try #require(calendar.date(byAdding: .day, value: 10, to: inWeekDate))

        let recurring = makeSchedule(name: "Recurring", day: 2)
        var imported = recurring
        imported.importedCalendarEventKey = "evt"
        var oneOffInWeek = recurring
        oneOffInWeek.date = inWeekDate
        var oneOffOutOfWeek = recurring
        oneOffOutOfWeek.date = outOfWeekDate

        #expect(WeeklyCalendarSupport.canDirectlyManipulate(recurring))
        #expect(WeeklyCalendarSupport.canDirectlyManipulate(imported) == false)
        #expect(WeeklyCalendarSupport.dayName(for: 1).isEmpty == false)
        #expect(WeeklyCalendarSupport.timeString(hour: 9).isEmpty == false)
        #expect(WeeklyCalendarSupport.formattedTime(recurring.startTime, calendar: calendar).isEmpty == false)
        #expect(WeeklyCalendarSupport.monthYearString(for: inWeekDate, calendar: calendar).isEmpty == false)

        let events = [
            ExternalEvent(
                id: "in",
                title: "In",
                startDate: inWeekDate.addingTimeInterval(3600),
                endDate: inWeekDate.addingTimeInterval(7200)
            ),
            ExternalEvent(
                id: "out",
                title: "Out",
                startDate: outOfWeekDate,
                endDate: outOfWeekDate.addingTimeInterval(3600)
            ),
        ]
        let visible = WeeklyCalendarSupport.visibleCalendarEvents(events, weekStart: bounds.0, weekEnd: bounds.1)
        #expect(visible.map(\.id) == ["in"])

        #expect(WeeklyCalendarSupport.shouldDisplaySchedule(oneOffInWeek, weekStart: bounds.0, weekEnd: bounds.1))
        #expect(WeeklyCalendarSupport.shouldDisplaySchedule(oneOffOutOfWeek, weekStart: bounds.0, weekEnd: bounds.1) == false)
        #expect(WeeklyCalendarSupport.shouldDisplaySchedule(recurring, weekStart: bounds.0, weekEnd: bounds.1))

        let placementsInWeek = WeeklyCalendarSupport.schedulePlacements(
            for: oneOffInWeek,
            weekRange: weekRange,
            calendar: calendar
        )
        let placementsOutOfWeek = WeeklyCalendarSupport.schedulePlacements(
            for: oneOffOutOfWeek,
            weekRange: weekRange,
            calendar: calendar
        )
        #expect(placementsInWeek.count == 1)
        #expect(placementsOutOfWeek.isEmpty)

        let positioned = WeeklyCalendarSupport.positionedSchedules(
            schedules: [recurring, oneOffInWeek, oneOffOutOfWeek],
            weekRange: weekRange,
            calendar: calendar
        )
        #expect(positioned.isEmpty == false)

        #expect(WeeklyCalendarSupport.blockFillOpacity(isImported: false) == 0.8)
        #expect(WeeklyCalendarSupport.blockFillOpacity(isImported: true) == 0.5)
        #expect(WeeklyCalendarSupport.blockBorderOpacity(isImported: false) == 0.95)
        #expect(WeeklyCalendarSupport.blockBorderOpacity(isImported: true) == 0.72)
        #expect(WeeklyCalendarSupport.primarySymbolName(for: recurring) == AppKitUISymbols.Name.target)
        #expect(WeeklyCalendarSupport.importedSymbolName(for: recurring) == nil)
        #expect(WeeklyCalendarSupport.importedSymbolName(for: imported) == AppKitUISymbols.Name.importedCalendar)

        let baseDay = calendar.startOfDay(for: inWeekDate)
        let target = WeeklyCalendarSupport.SchedulePlacement(
            id: "target",
            day: 2,
            startDate: calendar.date(byAdding: .hour, value: 8, to: baseDay) ?? baseDay,
            endDate: calendar.date(byAdding: .hour, value: 9, to: baseDay) ?? baseDay
        )
        let disjoint = WeeklyCalendarSupport.SchedulePlacement(
            id: "disjoint",
            day: 2,
            startDate: calendar.date(byAdding: .hour, value: 11, to: baseDay) ?? baseDay,
            endDate: calendar.date(byAdding: .hour, value: 12, to: baseDay) ?? baseDay
        )
        #expect(
            WeeklyCalendarSupport.concurrentLaneCount(
                for: target,
                among: [target, disjoint],
                calendar: calendar
            ) == 1
        )
    }

    @MainActor
    @Test("Weekly calendar document timer callback marks view for redraw")
    func weeklyCalendarDocumentTimerCallbackCoverage() {
        let document = WeeklyCalendarSurfaceDocumentNSView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 320)
        )

        let timer: Timer? = mirrorValue("timer", in: document)
        #expect(timer != nil)
        timer?.fire()
        #expect(timer?.isValid == true)
    }

    @MainActor
    @Test("Weekly calendar schedule block supports click, drag, update, and imported draw")
    func weeklyCalendarScheduleBlockInteractionsAndDraw() throws {
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let dayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        let targetDay = Calendar.current.component(.weekday, from: weekRange[0])
        let schedule = makeSchedule(name: "Focusable", day: targetDay)
        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "entry",
            day: targetDay,
            startDate: makeDate(hour: 9),
            endDate: makeDate(hour: 10)
        )
        let entry = WeeklyCalendarSupport.PositionedSchedule(
            id: "entry",
            schedule: schedule,
            placement: placement,
            laneIndex: 0,
            laneCount: 1
        )

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 1200))
        let block = WeeklyCalendarSurfaceScheduleBlockNSView()
        var opened: (Int, UUID)?
        var updated = false
        var began = false
        var endedValues: [Bool] = []
        block.configure(
            entry: entry,
            frame: NSRect(x: 120, y: 720, width: 96, height: 80),
            columnWidth: 100,
            originalColumnIndex: 0,
            calendarAreaX: 72,
            dayCount: dayOrder.count,
            weekRange: weekRange,
            hourHeight: 80,
            edgeHeight: 18,
            onOpenSchedule: { day, schedule in opened = (day, schedule.id) },
            onUpdateSchedule: { _, _, _, _, _, _ in updated = true },
            onInteractionDidBegin: { _ in began = true },
            onInteractionDidEnd: { endedValues.append($0) }
        )
        container.addSubview(block)

        let image = NSImage(size: block.bounds.size)
        image.lockFocus()
        block.draw(block.bounds)
        image.unlockFocus()

        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 140, y: 740),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        block.mouseDown(with: down)
        let drag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 260, y: 700),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        block.mouseDragged(with: drag)

        image.lockFocus()
        block.draw(block.bounds)
        image.unlockFocus()

        let upAfterDrag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 260, y: 700),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )
        block.mouseUp(with: upAfterDrag)

        #expect(began)
        #expect(updated)
        #expect(endedValues.contains(false))

        let imported = WeeklyCalendarSurfaceScheduleBlockNSView()
        var importedOpened = false
        imported.configure(
            entry: WeeklyCalendarSupport.PositionedSchedule(
                id: "imported",
                schedule: makeSchedule(name: "Imported", day: targetDay, importedKey: "event"),
                placement: WeeklyCalendarSupport.SchedulePlacement(
                    id: "imported",
                    day: targetDay,
                    startDate: makeDate(hour: 11),
                    endDate: makeDate(hour: 12)
                ),
                laneIndex: 0,
                laneCount: 1
            ),
            frame: NSRect(x: 120, y: 640, width: 96, height: 80),
            columnWidth: 100,
            originalColumnIndex: 0,
            calendarAreaX: 72,
            dayCount: dayOrder.count,
            weekRange: weekRange,
            hourHeight: 80,
            edgeHeight: 18,
            onOpenSchedule: { _, _ in importedOpened = true },
            onUpdateSchedule: { _, _, _, _, _, _ in },
            onInteractionDidBegin: { _ in },
            onInteractionDidEnd: { _ in }
        )
        container.addSubview(imported)

        image.lockFocus()
        imported.draw(imported.bounds)
        image.unlockFocus()

        imported.mouseDown(with: down)
        let importedUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 140, y: 660),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 3,
                clickCount: 1,
                pressure: 1
            )
        )
        imported.mouseUp(with: importedUp)

        #expect(importedOpened)
        #expect(opened == nil)
    }

    @MainActor
    @Test("Weekly calendar schedule block guard branches handle unconfigured state")
    func weeklyCalendarScheduleBlockUnconfiguredGuards() throws {
        let block = WeeklyCalendarSurfaceScheduleBlockNSView()
        block.frame = NSRect(x: 0, y: 0, width: 120, height: 80)

        let image = NSImage(size: block.bounds.size)
        image.lockFocus()
        block.draw(block.bounds)
        image.unlockFocus()
        block.resetCursorRects()

        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 10, y: 10),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        let drag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 16, y: 12),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let up = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 16, y: 12),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )

        block.mouseDown(with: down)
        block.mouseDragged(with: drag)
        block.mouseUp(with: up)
        #expect(block.frame.width == 120)
    }

    @MainActor
    @Test("Weekly calendar header draws both populated and empty week states")
    func weeklyCalendarHeaderDrawCoverage() {
        let header = WeeklyCalendarSurfaceHeaderNSView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 64)
        )
        let dayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)

        header.configure(
            dayOrder: dayOrder,
            weekRange: weekRange,
            accentColor: .systemBlue,
            timeLabelWidth: 60,
            timeColumnGutter: 12
        )
        var image = NSImage(size: header.bounds.size)
        image.lockFocus()
        header.draw(header.bounds)
        image.unlockFocus()

        header.configure(
            dayOrder: dayOrder,
            weekRange: [],
            accentColor: .systemPink,
            timeLabelWidth: 50,
            timeColumnGutter: 10
        )
        image = NSImage(size: header.bounds.size)
        image.lockFocus()
        header.draw(header.bounds)
        image.unlockFocus()
    }

    @MainActor
    @Test("Weekly calendar document supports selection, quick add, deferred rebuild, and redraw")
    func weeklyCalendarDocumentInteractionsAndRefresh() throws {
        let calendar = Calendar.current
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let dayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        let weekBounds = WeeklyCalendarSupport.weekBounds(for: weekRange)
        let targetDay = calendar.component(.weekday, from: weekRange[0])
        let schedule = makeSchedule(name: "Document", day: targetDay)
        let positioned = WeeklyCalendarSupport.positionedSchedules(
            schedules: [schedule],
            weekRange: weekRange
        )
        let externalEvent = ExternalEvent(
            id: "event-1",
            title: "Meeting",
            startDate: weekRange[0].addingTimeInterval(3600),
            endDate: weekRange[0].addingTimeInterval(5400)
        )

        var quickAdds: [(Int, Int)] = []
        var selections: [(Int, CGFloat, CGFloat)] = []
        var updates = 0
        let document = WeeklyCalendarSurfaceDocumentNSView(
            frame: NSRect(x: 0, y: 0, width: 920, height: 24 * 80)
        )
        document.configure(
            with: makeConfiguration(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekBounds.0,
                weekEnd: weekBounds.1,
                positionedSchedules: positioned,
                externalEvents: [externalEvent],
                showsExternalEvents: true,
                onQuickAdd: { day, hour in quickAdds.append((day, hour)) },
                onCreateSelection: { day, start, end in selections.append((day, start, end)) },
                onOpenSchedule: { _, _ in },
                onUpdateSchedule: { _, _, _, _, _, _ in updates += 1 }
            )
        )
        document.layoutSubtreeIfNeeded()
        #expect(document.scheduleBlockCountForTesting == 1)

        let image = NSImage(size: document.bounds.size)
        image.lockFocus()
        document.draw(document.bounds)
        image.unlockFocus()

        let quickDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 120, y: 160),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        let quickUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 120, y: 160),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseDown(with: quickDown)
        document.mouseUp(with: quickUp)
        #expect(quickAdds.count == 1)

        let selectDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 120, y: 240),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )
        let selectDrag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 120, y: 360),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 3,
                clickCount: 1,
                pressure: 1
            )
        )
        let selectUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 120, y: 360),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 4,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseDown(with: selectDown)
        document.mouseDragged(with: selectDrag)
        document.mouseUp(with: selectUp)
        #expect(selections.count == 1)

        guard let block = document.subviews.compactMap({ $0 as? WeeklyCalendarSurfaceScheduleBlockNSView }).first
        else {
            Issue.record("Expected a schedule block subview")
            return
        }

        let blockDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 120, y: 730),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 5,
                clickCount: 1,
                pressure: 1
            )
        )
        let blockDrag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 230, y: 700),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 6,
                clickCount: 1,
                pressure: 1
            )
        )
        let blockUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 230, y: 700),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 7,
                clickCount: 1,
                pressure: 1
            )
        )

        block.mouseDown(with: blockDown)
        document.configure(
            with: makeConfiguration(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekBounds.0,
                weekEnd: weekBounds.1,
                positionedSchedules: [],
                showsExternalEvents: false
            )
        )
        #expect(document.scheduleBlockCountForTesting == 1)

        block.mouseDragged(with: blockDrag)
        block.mouseUp(with: blockUp)
        #expect(updates > 0)
        #expect(document.scheduleBlockCountForTesting == 1)

        document.applyCurrentLayout()
        #expect(document.scheduleBlockCountForTesting == 0)
    }

    @MainActor
    @Test("Weekly calendar schedule block covers cursor rects, disabled draw, and no-superview drag")
    func weeklyCalendarScheduleBlockAdditionalBranches() throws {
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let dayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        let targetDay = Calendar.current.component(.weekday, from: weekRange[0])
        var disabledSchedule = makeSchedule(name: "Disabled", day: targetDay)
        disabledSchedule.isEnabled = false
        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "disabled",
            day: targetDay,
            startDate: makeDate(hour: 8),
            endDate: makeDate(hour: 9)
        )

        let block = WeeklyCalendarSurfaceScheduleBlockNSView()
        block.configure(
            entry: WeeklyCalendarSupport.PositionedSchedule(
                id: "disabled",
                schedule: disabledSchedule,
                placement: placement,
                laneIndex: 0,
                laneCount: 1
            ),
            frame: NSRect(x: 40, y: 40, width: 100, height: 80),
            columnWidth: 100,
            originalColumnIndex: 0,
            calendarAreaX: 72,
            dayCount: dayOrder.count,
            weekRange: weekRange,
            hourHeight: 80,
            edgeHeight: 18,
            onOpenSchedule: { _, _ in },
            onUpdateSchedule: { _, _, _, _, _, _ in },
            onInteractionDidBegin: { _ in },
            onInteractionDidEnd: { _ in }
        )

        block.resetCursorRects()

        let image = NSImage(size: block.bounds.size)
        image.lockFocus()
        block.draw(block.bounds)
        image.unlockFocus()

        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 60, y: 80),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        let tinyDrag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 61, y: 80),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let up = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 61, y: 80),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )

        block.mouseDown(with: down)
        block.mouseDragged(with: tinyDrag)
        block.mouseUp(with: up)

        let importedBlock = WeeklyCalendarSurfaceScheduleBlockNSView()
        importedBlock.configure(
            entry: WeeklyCalendarSupport.PositionedSchedule(
                id: "imported-cursor",
                schedule: makeSchedule(name: "Imported", day: targetDay, importedKey: "event-key"),
                placement: WeeklyCalendarSupport.SchedulePlacement(
                    id: "imported-cursor",
                    day: targetDay,
                    startDate: makeDate(hour: 13),
                    endDate: makeDate(hour: 14)
                ),
                laneIndex: 0,
                laneCount: 1
            ),
            frame: NSRect(x: 160, y: 40, width: 100, height: 80),
            columnWidth: 100,
            originalColumnIndex: 0,
            calendarAreaX: 72,
            dayCount: dayOrder.count,
            weekRange: weekRange,
            hourHeight: 80,
            edgeHeight: 18,
            onOpenSchedule: { _, _ in },
            onUpdateSchedule: { _, _, _, _, _, _ in },
            onInteractionDidBegin: { _ in },
            onInteractionDidEnd: { _ in }
        )
        importedBlock.resetCursorRects()
    }

    @MainActor
    @Test("Weekly calendar document handles selection preview draw and immediate rebuild branch")
    func weeklyCalendarDocumentAdditionalBranches() throws {
        let calendar = Calendar.current
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let dayOrder = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        let weekBounds = WeeklyCalendarSupport.weekBounds(for: weekRange)
        let targetDay = calendar.component(.weekday, from: weekRange[0])
        let schedule = makeSchedule(name: "Extra", day: targetDay)
        let positioned = WeeklyCalendarSupport.positionedSchedules(
            schedules: [schedule],
            weekRange: weekRange
        )
        let document = WeeklyCalendarSurfaceDocumentNSView(
            frame: NSRect(x: 0, y: 0, width: 920, height: 24 * 80)
        )

        document.configure(
            with: makeConfiguration(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekBounds.0,
                weekEnd: weekBounds.1,
                positionedSchedules: positioned,
                showsExternalEvents: false
            )
        )

        let outsideDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 8, y: 40),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseDown(with: outsideDown)
        let outsideUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 8, y: 40),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseUp(with: outsideUp)

        let farRightDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 5000, y: 80),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseDown(with: farRightDown)

        let selectDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 120, y: 240),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 3,
                clickCount: 1,
                pressure: 1
            )
        )
        let selectDrag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 120, y: 360),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 4,
                clickCount: 1,
                pressure: 1
            )
        )
        document.mouseDown(with: selectDown)
        document.mouseDragged(with: selectDrag)

        let previewImage = NSImage(size: document.bounds.size)
        previewImage.lockFocus()
        document.draw(document.bounds)
        previewImage.unlockFocus()

        guard let block = document.subviews.compactMap({ $0 as? WeeklyCalendarSurfaceScheduleBlockNSView }).first
        else {
            Issue.record("Expected block for immediate rebuild branch")
            return
        }
        let blockDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 120, y: 730),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 5,
                clickCount: 1,
                pressure: 1
            )
        )
        let blockUp = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 120, y: 730),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 6,
                clickCount: 1,
                pressure: 1
            )
        )
        block.mouseDown(with: blockDown)
        document.applyCurrentLayout()

        document.configure(
            with: makeConfiguration(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekBounds.0,
                weekEnd: weekBounds.1,
                positionedSchedules: [],
                externalEvents: [
                    ExternalEvent(
                        id: "skip-event",
                        title: "Skip",
                        startDate: weekRange[0],
                        endDate: weekRange[0].addingTimeInterval(1800)
                    )
                ],
                showsExternalEvents: true
            )
        )
        #expect(document.scheduleBlockCountForTesting == 1)
        block.mouseUp(with: blockUp)
        #expect(document.scheduleBlockCountForTesting == 0)
    }

    @MainActor
    @Test("Weekly calendar document skips entries with unmapped days in schedule and external-event rendering")
    func weeklyCalendarDocumentUnmappedDayBranches() {
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let weekBounds = WeeklyCalendarSupport.weekBounds(for: weekRange)
        let schedule = makeSchedule(name: "Unmapped", day: 2)
        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "unmapped-placement",
            day: 2,
            startDate: makeDate(hour: 8),
            endDate: makeDate(hour: 9)
        )
        let positioned = [
            WeeklyCalendarSupport.PositionedSchedule(
                id: "unmapped-placement",
                schedule: schedule,
                placement: placement,
                laneIndex: 0,
                laneCount: 1
            )
        ]

        let eventDate =
            Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 9, minute: 0, weekday: 2),
                matchingPolicy: .nextTimePreservingSmallerComponents
            ) ?? Date()
        let event = ExternalEvent(
            id: "unmapped-event",
            title: "Out",
            startDate: eventDate,
            endDate: eventDate.addingTimeInterval(1800)
        )

        let document = WeeklyCalendarSurfaceDocumentNSView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 24 * 80)
        )
        document.configure(
            with: makeConfiguration(
                dayOrder: [1],  // excludes schedule day/event weekday
                weekRange: weekRange,
                weekStart: weekBounds.0,
                weekEnd: weekBounds.1,
                positionedSchedules: positioned,
                externalEvents: [event],
                showsExternalEvents: true
            )
        )
        document.layoutSubtreeIfNeeded()

        let image = NSImage(size: document.bounds.size)
        image.lockFocus()
        document.draw(document.bounds)
        image.unlockFocus()

        #expect(document.scheduleBlockCountForTesting == 0)
    }
}
