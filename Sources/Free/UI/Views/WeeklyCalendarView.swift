import SwiftUI

struct WeeklyCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var editorContext: ScheduleEditorContext?
    
    @State private var dragData: DragSelection?
    @State private var weekOffset: Int = 0
    
    struct DragSelection {
        let day: Int
        let startHour: CGFloat
        var endHour: CGFloat
    }
    
    let hourHeight: CGFloat = 80
    let dayHeaderHeight: CGFloat = 40
    let timeLabelWidth: CGFloat = 50
    let timeColumnGutter: CGFloat = 10
    
    var dayOrder: [Int] {
        WeeklyCalendarView.getDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
    }

    static func getDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        if weekStartsOnMonday {
            return [2, 3, 4, 5, 6, 7, 1] // Mon -> Sun
        } else {
            return [1, 2, 3, 4, 5, 6, 7] // Sun -> Sat
        }
    }
    
    var currentWeekDates: [Date] {
        WeeklyCalendarView.getWeekDates(at: Date(), weekStartsOnMonday: appState.weekStartsOnMonday, offset: weekOffset)
    }

    static func getWeekDates(at date: Date = Date(), weekStartsOnMonday: Bool, offset: Int = 0) -> [Date] {
        WeekDateCalculator.getWeekDates(at: date, weekStartsOnMonday: weekStartsOnMonday, offset: offset)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let calendar = Calendar.current
            let weekRange = currentWeekDates
            let weekStart = weekRange.first ?? Date.distantPast
            let weekEnd = calendar.date(byAdding: .day, value: 1, to: weekRange.last ?? Date.distantFuture) ?? Date.distantFuture

            VStack(spacing: 0) {
                // Toolbar (Navigation)
                HStack {
                    Text(monthYearString(for: weekStart))
                        .font(.title3.bold())
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: { weekOffset -= 1 }) {
                            Image(systemName: "chevron.left")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)
                        
                        Button("Today") {
                            weekOffset = 0
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { weekOffset += 1 }) {
                            Image(systemName: "chevron.right")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Header (Days)
                HStack(alignment: .center, spacing: 0) {
                    Text("")
                        .frame(width: timeLabelWidth + timeColumnGutter)
                    
                    ForEach(dayOrder, id: \.self) { day in
                        VStack(spacing: 4) {
                            Text(dayName(for: day))
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            if let date = dateFor(weekday: day, in: weekRange) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.title3.bold())
                                    .foregroundColor(isToday(date: date) ? .white : .primary)
                                    .frame(width: 28, height: 28)
                                    .background(isToday(date: date) ? FocusColor.color(for: appState.accentColorIndex) : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Scrollable Grid
                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            // Horizontal Grid Lines & Time Labels (Unified)
                            VStack(spacing: 0) {
                                ForEach(0..<24, id: \.self) { hour in
                                    ZStack(alignment: .top) {
                                        Divider()
                                        HStack(alignment: .top, spacing: 0) {
                                            Text(timeString(hour: hour))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: timeLabelWidth, alignment: .trailing)
                                                .padding(.trailing, 8)
                                                .offset(y: -6)
                                            Spacer()
                                        }
                                    }
                                    .frame(height: hourHeight, alignment: .top)
                                    .id(hour)
                                }
                            }
                            
                            // Vertical Day Lines
                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                ForEach(0..<7, id: \.self) { _ in
                                    Spacer()
                                    Divider()
                                }
                            }
                            
                            // Tappable & Draggable Areas (Background)
                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                ForEach(0..<7, id: \.self) { columnIndex in
                                    let day = dayOrder[columnIndex]
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity, maxHeight: 24 * hourHeight)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    if abs(value.translation.height) > 5 {
                                                        let startY = value.startLocation.y
                                                        let currentY = value.location.y
                                                        if dragData == nil {
                                                            dragData = DragSelection(day: day, startHour: startY / hourHeight, endHour: currentY / hourHeight)
                                                        } else {
                                                            dragData?.endHour = currentY / hourHeight
                                                        }
                                                    }
                                                }
                                                .onEnded { value in
                                                    if let data = dragData {
                                                        finalizeDrag(data)
                                                        dragData = nil
                                                    } else {
                                                        let hour = Int(value.startLocation.y / hourHeight)
                                                        quickAdd(day: day, hour: hour)
                                                    }
                                                }
                                        )
                                }
                            }
                            
                            // Ghost block while dragging
                            if let data = dragData {
                                let columnWidth = (geometry.size.width - (timeLabelWidth + timeColumnGutter)) / 7
                                
                                // Snap to 15 mins (0.25 of an hour)
                                let snap = { (h: CGFloat) -> CGFloat in
                                    return (h * 4).rounded() / 4.0
                                }
                                
                                let startH = snap(min(data.startHour, data.endHour))
                                let endH = snap(max(data.startHour, data.endHour))
                                let y = startH * hourHeight
                                let h = max(endH - startH, 0.25) * hourHeight // Min 15 mins
                                
                                if let colIndex = dayOrder.firstIndex(of: data.day) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(FocusColor.color(for: appState.accentColorIndex).opacity(0.3))
                                        .overlay(
                                            VStack {
                                                Text("\(formatTime(startH)) - \(formatTime(endH))")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                                                    .padding(4)
                                                    .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                                    .cornerRadius(4)
                                                    .offset(y: -25) // Show slightly above or inside at the top
                                            },
                                            alignment: .top
                                        )
                                        .frame(width: columnWidth - 4, height: h)
                                        .offset(x: timeLabelWidth + timeColumnGutter + CGFloat(colIndex) * columnWidth + 2, y: y)
                                }
                            }
                            
                            // Schedule Blocks
                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                GeometryReader { innerGeo in
                                    let columnWidth = innerGeo.size.width / 7
                                    
                                    ZStack(alignment: .topLeading) {
                                        // 1. External Events (System/Google Calendar)
                                        if appState.calendarIntegrationEnabled {
                                            ForEach(appState.calendarProvider.events.filter { 
                                                $0.startDate >= weekStart && $0.startDate < weekEnd
                                            }) { event in
                                                let weekday = calendar.component(.weekday, from: event.startDate)
                                                if let colIndex = dayOrder.firstIndex(of: weekday),
                                                   let frame = calculateRect(startDate: event.startDate, endDate: event.endDate, colIndex: colIndex, columnWidth: columnWidth) {
                                                    ExternalEventBlockView(event: event)
                                                        .frame(width: frame.width, height: frame.height)
                                                        .position(x: frame.midX, y: frame.midY)
                                                }
                                            }
                                        }
                                        
                                        // 2. Internal Schedules
                                        ForEach(appState.schedules.filter { schedule in
                                            if let specificDate = schedule.date {
                                                let d = calendar.startOfDay(for: specificDate)
                                                let s = calendar.startOfDay(for: weekStart)
                                                let e = calendar.startOfDay(for: weekEnd)
                                                return d >= s && d < e
                                            }
                                            return true // Recurring schedules show in every week
                                        }) { schedule in
                                            ForEach(schedule.days.sorted(), id: \.self) { day in
                                                if let colIndex = dayOrder.firstIndex(of: day),
                                                   let frame = calculateRect(startDate: schedule.startTime, endDate: schedule.endTime, colIndex: colIndex, columnWidth: columnWidth) {
                                                    ScheduleBlockView(schedule: schedule)
                                                        .frame(width: frame.width, height: frame.height)
                                                        .position(x: frame.midX, y: frame.midY)
                                                        .onTapGesture {
                                                            editorContext = ScheduleEditorContext(
                                                                day: day,
                                                                schedule: schedule,
                                                                weekOffset: weekOffset
                                                            )
                                                        }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Current Time Indicator
                            CurrentTimeIndicator(
                                hourHeight: hourHeight,
                                timeLabelWidth: timeLabelWidth + timeColumnGutter,
                                dayOrder: dayOrder,
                                weekStart: weekStart,
                                weekEnd: weekEnd
                            )
                        }
                    }
                    .onAppear {
                        scrollToCurrentTime(proxy: proxy)
                    }
                }
            }
        }
    }
    
    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetHour = max(0, currentHour - 2)
        proxy.scrollTo(targetHour, anchor: .top)
    }
    
    func formatTime(_ h: CGFloat) -> String {
        WeeklyCalendarView.formatTime(h)
    }

    static func formatTime(_ h: CGFloat) -> String {
        let hour = Int(h)
        let min = Int(((h - CGFloat(hour)) * 60).rounded())
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: min)) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        let result = WeeklyCalendarView.calculateDragSelection(
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

    static func calculateDragSelection(startHour: CGFloat, endHour: CGFloat) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let snap = { (h: CGFloat) -> CGFloat in
            return (h * 4).rounded() / 4.0
        }
        
        let sH = snap(min(startHour, endHour))
        var eH = snap(max(startHour, endHour))
        
        // Ensure at least 15 mins
        if eH - sH < 0.25 {
            eH = sH + 0.25
        }
        
        let sHour = Int(sH)
        let sMin = Int(((sH - CGFloat(sHour)) * 60).rounded())
        
        let eHour = Int(eH)
        let eMin = Int(((eH - CGFloat(eHour)) * 60).rounded())
        
        let start = calendar.date(from: DateComponents(hour: sHour, minute: sMin)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: eHour, minute: eMin)) ?? Date()
        
        return (start, end)
    }
    
    func dayName(for day: Int) -> String {
        WeeklyCalendarView.dayName(for: day)
    }

    static func dayName(for day: Int) -> String {
        return Calendar.current.shortWeekdaySymbols[day - 1]
    }
    
    func isToday(day: Int) -> Bool {
        return Calendar.current.component(.weekday, from: Date()) == day
    }
    
    func timeString(hour: Int) -> String {
        WeeklyCalendarView.timeString(hour: hour)
    }

    static func timeString(hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }

    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func dateFor(weekday: Int, in range: [Date]) -> Date? {
        range.first { Calendar.current.component(.weekday, from: $0) == weekday }
    }

    private func isToday(date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private func calculateRect(startDate: Date, endDate: Date, colIndex: Int, columnWidth: CGFloat) -> CGRect? {
        WeeklyCalendarView.calculateRect(
            startDate: startDate,
            endDate: endDate,
            colIndex: colIndex,
            columnWidth: columnWidth,
            hourHeight: hourHeight
        )
    }

    static func calculateRect(startDate: Date, endDate: Date, colIndex: Int, columnWidth: CGFloat, hourHeight: CGFloat) -> CGRect? {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComp = calendar.dateComponents([.hour, .minute], from: endDate)
        
        guard let startHour = startComp.hour, let startMin = startComp.minute,
              let endHour = endComp.hour, let endMin = endComp.minute else { return nil }
        
        let startY = (CGFloat(startHour) + CGFloat(startMin) / 60.0) * hourHeight
        var endY = (CGFloat(endHour) + CGFloat(endMin) / 60.0) * hourHeight
        
        // Handle overnight or same-time
        if startY >= endY { endY = 24 * hourHeight }
        
        let height = max(endY - startY, 15) // Min height
        let x = CGFloat(colIndex) * columnWidth + 2
        
        return CGRect(x: x, y: startY, width: columnWidth - 4, height: height)
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
            .fill(schedule.isEnabled ? schedule.themeColor.opacity(0.8) : Color.gray.opacity(0.5))
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: schedule.type == .focus ? "target" : "cup.and.saucer.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(schedule.name)
                            .font(.caption)
                            .bold()
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
    
    func timeRange(_ s: Schedule) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: s.startTime))"
    }
}

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let timeLabelWidth: CGFloat
    let dayOrder: [Int]
    let weekStart: Date
    let weekEnd: Date
    
    @State private var currentTimeOffset: CGFloat = 0
    @State private var currentDayIndex: Int?
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            let now = Date()
            if now >= weekStart && now < weekEnd {
                GeometryReader { geo in
                    if let colIndex = currentDayIndex {
                        let columnWidth = (geo.size.width - timeLabelWidth) / 7
                        let xOffset = timeLabelWidth + CGFloat(colIndex) * columnWidth
                        
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
        .onReceive(timer) { _ in updateTime() }
    }
    
    func updateTime() {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        if let h = comps.hour, let m = comps.minute, let w = comps.weekday {
            currentTimeOffset = (CGFloat(h) + CGFloat(m) / 60.0) * hourHeight
            currentDayIndex = dayOrder.firstIndex(of: w)
        }
    }
}
