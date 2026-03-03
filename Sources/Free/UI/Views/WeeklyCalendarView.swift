import AppKit
import Combine
import SwiftUI

struct WeeklyCalendarView: View {
    typealias DragSelection = WeeklyCalendarSupport.DragSelection
    typealias DragPreviewMetrics = WeeklyCalendarSupport.DragPreviewMetrics
    typealias SchedulePlacement = WeeklyCalendarSupport.SchedulePlacement
    typealias PositionedSchedule = WeeklyCalendarSupport.PositionedSchedule
    typealias ScheduleInteractionMode = WeeklyCalendarSupport.ScheduleInteractionMode
    typealias ScheduleUpdate = WeeklyCalendarSupport.ScheduleUpdate

    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    private let headerAccessory: AnyView?
    var appState: AppState { actionAppState ?? environmentAppState }
    @Binding var editorContext: ScheduleEditorContext?

    @State private var dragData: DragSelection?
    @State private var scheduleInteraction: ScheduleInteraction?
    @State private var weekOffset: Int = 0

    struct ScheduleInteraction {
        let placementId: String
        let schedule: Schedule
        let originalDay: Int
        let mode: ScheduleInteractionMode
        var translation: CGSize = .zero
    }

    init(
        editorContext: Binding<ScheduleEditorContext?>,
        actionAppState: AppState? = nil,
        initialWeekOffset: Int = 0,
        initialDragData: DragSelection? = nil,
        headerAccessory: AnyView? = nil
    ) {
        _editorContext = editorContext
        self.actionAppState = actionAppState
        self.headerAccessory = headerAccessory
        _weekOffset = State(initialValue: initialWeekOffset)
        _dragData = State(initialValue: initialDragData)
    }

    let hourHeight: CGFloat = 80
    let dayHeaderHeight: CGFloat = 40
    let timeLabelWidth: CGFloat = 60
    let timeColumnGutter: CGFloat = 12
    let resizeHandleHitHeight: CGFloat = 18
    let toolbarHeight: CGFloat = 36

    var dayOrder: [Int] {
        Self.getDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
    }

    var currentWeekDates: [Date] {
        Self.getWeekDates(
            at: Date(),
            weekStartsOnMonday: appState.weekStartsOnMonday,
            offset: weekOffset
        )
    }

    var shouldShowExternalCalendarOverlay: Bool {
        appState.calendarIntegrationEnabled && !appState.calendarImportsBlockTime
    }

    var body: some View {
        let weekRange = currentWeekDates
        let (weekStart, weekEnd) = Self.weekBounds(for: weekRange)

        ZStack(alignment: .top) {
            WeeklyCalendarAppKitView(
                configuration: WeeklyCalendarSurfaceConfiguration(
                    dayOrder: dayOrder,
                    weekRange: weekRange,
                    weekStart: weekStart,
                    weekEnd: weekEnd,
                    positionedSchedules: positionedSchedules(weekRange: weekRange),
                    externalEvents: visibleCalendarEvents(weekStart: weekStart, weekEnd: weekEnd),
                    showsExternalEvents: shouldShowExternalCalendarOverlay,
                    hourHeight: hourHeight,
                    dayHeaderHeight: dayHeaderHeight,
                    timeLabelWidth: timeLabelWidth,
                    timeColumnGutter: timeColumnGutter,
                    accentColor: FocusColor.nsColor(for: appState.accentColorIndex),
                    onQuickAdd: { day, hour in
                        quickAdd(day: day, hour: hour)
                    },
                    onCreateSelection: { day, startHour, endHour in
                        finalizeDrag(
                            DragSelection(day: day, startHour: startHour, endHour: endHour)
                        )
                    },
                    onOpenSchedule: { day, schedule in
                        openScheduleEditor(day: day, schedule: schedule)
                    },
                    onUpdateSchedule: { scheduleId, originalDay, targetDay, targetDate, start, end in
                        appState.updateScheduleOccurrence(
                            id: scheduleId,
                            originalDay: originalDay,
                            targetDay: targetDay,
                            targetDate: targetDate,
                            start: start,
                            end: end
                        )
                    }
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, toolbarHeight)

            ZStack {
                HStack {
                    Text(monthYearString(for: weekStart))
                        .font(.title3.bold())

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: goToPreviousWeek) {
                            Image(systemName: "chevron.left")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button("Today", action: goToCurrentWeek)
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Button(action: goToNextWeek) {
                            Image(systemName: "chevron.right")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let headerAccessory {
                    headerAccessory
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func goToPreviousWeek() {
        weekOffset -= 1
    }

    func goToCurrentWeek() {
        weekOffset = 0
    }

    func goToNextWeek() {
        weekOffset += 1
    }

    func handleDragChanged(day: Int, startY: CGFloat, currentY: CGFloat) {
        if abs(currentY - startY) > 5 {
            if dragData == nil {
                dragData = DragSelection(
                    day: day,
                    startHour: startY / hourHeight,
                    endHour: currentY / hourHeight
                )
            } else {
                dragData?.endHour = currentY / hourHeight
            }
        }
    }

    func handleDragEnded(day: Int, startY: CGFloat) {
        if let data = dragData {
            finalizeDrag(data)
            dragData = nil
        } else {
            let hour = Int(startY / hourHeight)
            quickAdd(day: day, hour: hour)
        }
    }

    func dragChangedAction(day: Int) -> (DragGesture.Value) -> Void {
        { value in
            handleDragChanged(
                day: day,
                startY: value.startLocation.y,
                currentY: value.location.y
            )
        }
    }

    func dragEndedAction(day: Int) -> (DragGesture.Value) -> Void {
        { value in
            handleDragEnded(day: day, startY: value.startLocation.y)
        }
    }

    func dragPreviewMetrics(data: DragSelection, geometryWidth: CGFloat) -> DragPreviewMetrics? {
        Self.dragPreviewMetrics(
            data: data,
            dayOrder: dayOrder,
            geometryWidth: geometryWidth,
            timeLabelWidth: timeLabelWidth,
            timeColumnGutter: timeColumnGutter,
            hourHeight: hourHeight
        )
    }

    func formatTime(_ hour: CGFloat) -> String {
        Self.formatTime(hour)
    }

    func quickAdd(day: Int, hour: Int) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: hour, minute: 0))
        let end = calendar.date(from: DateComponents(hour: hour + 1, minute: 0))

        editorContext = ScheduleEditorContext(
            day: day,
            startTime: start,
            endTime: end,
            schedule: nil,
            weekOffset: weekOffset
        )
    }

    func finalizeDrag(_ data: DragSelection) {
        let result = Self.calculateDragSelection(
            startHour: data.startHour,
            endHour: data.endHour
        )

        editorContext = ScheduleEditorContext(
            day: data.day,
            startTime: result.start,
            endTime: result.end,
            schedule: nil,
            weekOffset: weekOffset
        )
    }

    func visibleCalendarEvents(weekStart: Date, weekEnd: Date) -> [ExternalEvent] {
        appState.calendarProvider.events.filter {
            $0.startDate >= weekStart && $0.startDate < weekEnd
        }
    }

    func shouldDisplaySchedule(_ schedule: Schedule, weekStart: Date, weekEnd: Date) -> Bool {
        let calendar = Calendar.current
        if let specificDate = schedule.date {
            let scheduleDay = calendar.startOfDay(for: specificDate)
            let weekStartDay = calendar.startOfDay(for: weekStart)
            let weekEndDay = calendar.startOfDay(for: weekEnd)
            return scheduleDay >= weekStartDay && scheduleDay < weekEndDay
        }
        return true
    }

    func openScheduleEditor(day: Int, schedule: Schedule) {
        editorContext = ScheduleEditorContext(
            day: day,
            schedule: schedule,
            weekOffset: weekOffset
        )
    }

    func openScheduleEditorAction(day: Int, schedule: Schedule) -> () -> Void {
        { openScheduleEditor(day: day, schedule: schedule) }
    }

    private func previewFrame(for entry: PositionedSchedule, baseFrame: CGRect) -> CGRect {
        guard let scheduleInteraction, scheduleInteraction.placementId == entry.id else {
            return baseFrame
        }
        return Self.previewFrame(
            baseFrame: baseFrame,
            translation: scheduleInteraction.translation,
            mode: scheduleInteraction.mode
        )
    }

    func scheduleInteractionChangedAction(
        entry: PositionedSchedule,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat
    ) -> (DragGesture.Value) -> Void {
        { value in
            scheduleInteraction = ScheduleInteraction(
                placementId: entry.id,
                schedule: entry.schedule,
                originalDay: entry.placement.day,
                mode: mode,
                translation: Self.snappedInteractionTranslation(
                    translation: value.translation,
                    mode: mode,
                    columnWidth: columnWidth,
                    hourHeight: hourHeight
                )
            )
        }
    }

    func scheduleInteractionEndedAction(
        entry: PositionedSchedule,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        weekRange: [Date]
    ) -> (DragGesture.Value) -> Void {
        { value in
            let update = Self.scheduleUpdate(
                placement: entry.placement,
                translation: value.translation,
                mode: mode,
                columnWidth: columnWidth,
                hourHeight: hourHeight,
                weekRange: weekRange
            )
            scheduleInteraction = nil
            guard let update else { return }
            appState.updateScheduleOccurrence(
                id: entry.schedule.id,
                originalDay: entry.placement.day,
                targetDay: update.targetDay,
                targetDate: update.targetDate,
                start: update.start,
                end: update.end
            )
        }
    }

    func schedulePlacements(for schedule: Schedule, weekRange: [Date]) -> [SchedulePlacement] {
        let calendar = Calendar.current

        if let specificDate = schedule.date {
            guard let inWeekDate = weekRange.first(where: {
                calendar.isDate($0, inSameDayAs: specificDate)
            }) else {
                return []
            }

            return [
                SchedulePlacement(
                    id: "\(schedule.id.uuidString)-\(calendar.startOfDay(for: inWeekDate).timeIntervalSince1970)",
                    day: calendar.component(.weekday, from: inWeekDate),
                    startDate: schedule.startTime,
                    endDate: schedule.endTime
                )
            ]
        }

        return schedule.days.sorted().map { day in
            SchedulePlacement(
                id: "\(schedule.id.uuidString)-\(day)",
                day: day,
                startDate: schedule.startTime,
                endDate: schedule.endTime
            )
        }
    }

    func positionedSchedules(weekRange: [Date]) -> [PositionedSchedule] {
        let visible = appState.schedules.filter {
            let bounds = Self.weekBounds(for: weekRange)
            return shouldDisplaySchedule($0, weekStart: bounds.0, weekEnd: bounds.1)
        }
        let placements = visible.flatMap { schedule in
            schedulePlacements(for: schedule, weekRange: weekRange).map {
                (schedule: schedule, placement: $0)
            }
        }
        return Self.positionedSchedules(from: placements)
    }

    func dayName(for day: Int) -> String {
        Self.dayName(for: day)
    }

    func isToday(day: Int) -> Bool {
        Calendar.current.component(.weekday, from: Date()) == day
    }

    func timeString(hour: Int) -> String {
        Self.timeString(hour: hour)
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var weekOffsetForTesting: Int { weekOffset }
    var dragDataForTesting: DragSelection? { dragData }

    static func getDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: weekStartsOnMonday)
    }

    static func getWeekDates(
        at date: Date = Date(),
        weekStartsOnMonday: Bool,
        offset: Int = 0
    ) -> [Date] {
        WeeklyCalendarSupport.getWeekDates(
            at: date,
            weekStartsOnMonday: weekStartsOnMonday,
            offset: offset
        )
    }

    static func dragPreviewMetrics(
        data: DragSelection,
        dayOrder: [Int],
        geometryWidth: CGFloat,
        timeLabelWidth: CGFloat,
        timeColumnGutter: CGFloat,
        hourHeight: CGFloat
    ) -> DragPreviewMetrics? {
        WeeklyCalendarSupport.dragPreviewMetrics(
            data: data,
            dayOrder: dayOrder,
            geometryWidth: geometryWidth,
            timeLabelWidth: timeLabelWidth,
            timeColumnGutter: timeColumnGutter,
            hourHeight: hourHeight
        )
    }

    static func formatTime(_ hour: CGFloat) -> String {
        WeeklyCalendarSupport.formatTime(hour)
    }

    static func positionedSchedules(
        from placements: [(schedule: Schedule, placement: SchedulePlacement)],
        calendar: Calendar = .current
    ) -> [PositionedSchedule] {
        WeeklyCalendarSupport.positionedSchedules(from: placements, calendar: calendar)
    }

    static func calculateDragSelection(startHour: CGFloat, endHour: CGFloat) -> (start: Date, end: Date) {
        WeeklyCalendarSupport.calculateDragSelection(startHour: startHour, endHour: endHour)
    }

    static func selectionPreviewLabels(startHour: CGFloat, endHour: CGFloat) -> (start: String, end: String) {
        WeeklyCalendarSupport.selectionPreviewLabels(startHour: startHour, endHour: endHour)
    }

    static func snappedSelectionHours(startHour: CGFloat, endHour: CGFloat) -> (start: CGFloat, end: CGFloat) {
        WeeklyCalendarSupport.snappedSelectionHours(startHour: startHour, endHour: endHour)
    }

    static func previewFrame(
        baseFrame: CGRect,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        minimumHeight: CGFloat = 15
    ) -> CGRect {
        WeeklyCalendarSupport.previewFrame(
            baseFrame: baseFrame,
            translation: translation,
            mode: mode,
            minimumHeight: minimumHeight
        )
    }

    static func snappedInteractionTranslation(
        translation: CGSize,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        hourHeight: CGFloat
    ) -> CGSize {
        WeeklyCalendarSupport.snappedInteractionTranslation(
            translation: translation,
            mode: mode,
            columnWidth: columnWidth,
            hourHeight: hourHeight
        )
    }

    static func scheduleUpdate(
        placement: SchedulePlacement,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        hourHeight: CGFloat,
        weekRange: [Date],
        resolvedDayDelta: Int? = nil,
        calendar: Calendar = .current
    ) -> ScheduleUpdate? {
        WeeklyCalendarSupport.scheduleUpdate(
            placement: placement,
            translation: translation,
            mode: mode,
            columnWidth: columnWidth,
            hourHeight: hourHeight,
            weekRange: weekRange,
            resolvedDayDelta: resolvedDayDelta,
            calendar: calendar
        )
    }

    static func schedulePreviewLabels(
        placement: SchedulePlacement,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        hourHeight: CGFloat,
        calendar: Calendar = .current
    ) -> (start: String, end: String) {
        WeeklyCalendarSupport.schedulePreviewLabels(
            placement: placement,
            translation: translation,
            mode: mode,
            hourHeight: hourHeight,
            calendar: calendar
        )
    }

    static func snappedMinuteDelta(translationHeight: CGFloat, hourHeight: CGFloat) -> Int {
        WeeklyCalendarSupport.snappedMinuteDelta(
            translationHeight: translationHeight,
            hourHeight: hourHeight
        )
    }

    static func snappedDayDelta(translationWidth: CGFloat, columnWidth: CGFloat) -> Int {
        WeeklyCalendarSupport.snappedDayDelta(
            translationWidth: translationWidth,
            columnWidth: columnWidth
        )
    }

    static func dayDelta(
        cursorX: CGFloat,
        calendarAreaX: CGFloat,
        columnWidth: CGFloat,
        dayCount: Int,
        originalColumnIndex: Int
    ) -> Int {
        WeeklyCalendarSupport.dayDelta(
            cursorX: cursorX,
            calendarAreaX: calendarAreaX,
            columnWidth: columnWidth,
            dayCount: dayCount,
            originalColumnIndex: originalColumnIndex
        )
    }

    static func shiftedWeekday(_ weekday: Int, by delta: Int) -> Int {
        WeeklyCalendarSupport.shiftedWeekday(weekday, by: delta)
    }

    static func interactionMode(
        at point: CGPoint,
        in bounds: CGRect,
        edgeHeight: CGFloat
    ) -> ScheduleInteractionMode {
        WeeklyCalendarSupport.interactionMode(at: point, in: bounds, edgeHeight: edgeHeight)
    }

    static func effectiveResizeHandleHeight(
        boundsHeight: CGFloat,
        preferredHeight: CGFloat,
        minimumHeight: CGFloat = 4,
        maximumHeight: CGFloat = 6
    ) -> CGFloat {
        WeeklyCalendarSupport.effectiveResizeHandleHeight(
            boundsHeight: boundsHeight,
            preferredHeight: preferredHeight,
            minimumHeight: minimumHeight,
            maximumHeight: maximumHeight
        )
    }

    static func adjustedTimes(
        start: Date,
        end: Date,
        minuteDelta: Int,
        mode: ScheduleInteractionMode,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        WeeklyCalendarSupport.adjustedTimes(
            start: start,
            end: end,
            minuteDelta: minuteDelta,
            mode: mode,
            calendar: calendar
        )
    }

    static func canDirectlyManipulate(_ schedule: Schedule) -> Bool {
        WeeklyCalendarSupport.canDirectlyManipulate(schedule)
    }

    static func dayName(for day: Int) -> String {
        WeeklyCalendarSupport.dayName(for: day)
    }

    static func timeString(hour: Int) -> String {
        WeeklyCalendarSupport.timeString(hour: hour)
    }

    static func formattedTime(_ date: Date, calendar: Calendar = .current) -> String {
        WeeklyCalendarSupport.formattedTime(date, calendar: calendar)
    }

    static func weekBounds(for weekRange: [Date], calendar: Calendar = .current) -> (Date, Date) {
        WeeklyCalendarSupport.weekBounds(for: weekRange, calendar: calendar)
    }

    static func calculateRect(
        startDate: Date,
        endDate: Date,
        colIndex: Int,
        columnWidth: CGFloat,
        laneIndex: Int = 0,
        laneCount: Int = 1,
        hourHeight: CGFloat
    ) -> CGRect? {
        WeeklyCalendarSupport.calculateRect(
            startDate: startDate,
            endDate: endDate,
            colIndex: colIndex,
            columnWidth: columnWidth,
            laneIndex: laneIndex,
            laneCount: laneCount,
            hourHeight: hourHeight
        )
    }
}

private struct WeeklyCalendarAppKitView: NSViewRepresentable {
    let configuration: WeeklyCalendarSurfaceConfiguration

    func makeNSView(context: Context) -> WeeklyCalendarSurfaceNSView {
        let view = WeeklyCalendarSurfaceNSView()
        view.configure(with: configuration)
        return view
    }

    func updateNSView(_ nsView: WeeklyCalendarSurfaceNSView, context: Context) {
        nsView.configure(with: configuration)
    }
}

struct ExternalEventBlockView: View {
    let event: ExternalEvent

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.secondary.opacity(0.4))
            )
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(event.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    Spacer()
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            )
    }
}

struct ScheduleBlockView: View {
    let schedule: Schedule

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(blockFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(blockBorderColor, lineWidth: 1)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: Self.primarySymbolName(for: schedule))
                            .font(.system(size: 10, weight: .bold))
                        Text(schedule.name)
                            .font(.caption)
                            .bold()
                        if let importedSymbolName = Self.importedSymbolName(for: schedule) {
                            Image(systemName: importedSymbolName)
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .lineLimit(1)

                    Text(timeRange(schedule))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            )
    }

    var blockFillColor: Color {
        if !schedule.isEnabled {
            return Color.gray.opacity(0.5)
        }
        return schedule.themeColor.opacity(Self.fillOpacity(isImported: isImported))
    }

    var blockBorderColor: Color {
        if !schedule.isEnabled {
            return Color.gray.opacity(0.8)
        }
        return schedule.themeColor.opacity(Self.borderOpacity(isImported: isImported))
    }

    static func fillOpacity(isImported: Bool) -> Double {
        WeeklyCalendarSupport.blockFillOpacity(isImported: isImported)
    }

    static func borderOpacity(isImported: Bool) -> Double {
        WeeklyCalendarSupport.blockBorderOpacity(isImported: isImported)
    }

    static func primarySymbolName(for schedule: Schedule) -> String {
        WeeklyCalendarSupport.primarySymbolName(for: schedule)
    }

    static func importedSymbolName(for schedule: Schedule) -> String? {
        WeeklyCalendarSupport.importedSymbolName(for: schedule)
    }

    func timeRange(_ schedule: Schedule) -> String {
        schedule.timeRangeString
    }

    var isImported: Bool {
        schedule.importedCalendarEventKey != nil
    }
}

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let timeLabelWidth: CGFloat
    let dayOrder: [Int]
    let weekStart: Date
    let weekEnd: Date

    @State private var currentTimeOffset: CGFloat
    @State private var currentDayIndex: Int?
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(
        hourHeight: CGFloat,
        timeLabelWidth: CGFloat,
        dayOrder: [Int],
        weekStart: Date,
        weekEnd: Date,
        initialCurrentTimeOffset: CGFloat = 0,
        initialCurrentDayIndex: Int? = nil,
        timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(
            every: 60,
            on: .main,
            in: .common
        ).autoconnect()
    ) {
        self.hourHeight = hourHeight
        self.timeLabelWidth = timeLabelWidth
        self.dayOrder = dayOrder
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.timer = timer
        _currentTimeOffset = State(initialValue: initialCurrentTimeOffset)
        _currentDayIndex = State(initialValue: initialCurrentDayIndex)
    }

    var body: some View {
        Group {
            let now = Date()
            if now >= weekStart && now < weekEnd {
                GeometryReader { geometry in
                    if let columnIndex = currentDayIndex {
                        let columnWidth = (geometry.size.width - timeLabelWidth) / 7
                        let xOffset = timeLabelWidth + CGFloat(columnIndex) * columnWidth

                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: xOffset - 4)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: columnWidth, height: 1)
                                .offset(x: xOffset - 4)
                        }
                        .offset(y: currentTimeOffset)
                    }
                }
            }
        }
        .onAppear { updateTime() }
        .onReceive(timer, perform: onTimerTick)
    }

    func onTimerTick(_: Date) {
        updateTime()
    }

    func updateTime() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        if let hour = components.hour, let minute = components.minute, let weekday = components.weekday {
            currentTimeOffset = (CGFloat(hour) + CGFloat(minute) / 60.0) * hourHeight
            currentDayIndex = dayOrder.firstIndex(of: weekday)
        }
    }
}
