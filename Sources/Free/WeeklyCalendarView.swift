import SwiftUI

struct WeeklyCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var editorContext: ScheduleEditorContext?
    
    @State private var dragData: DragSelection?
    
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
        if appState.weekStartsOnMonday {
            return [2, 3, 4, 5, 6, 7, 1] // Mon -> Sun
        } else {
            return [1, 2, 3, 4, 5, 6, 7] // Sun -> Sat
        }
    }
    
    var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeekDay = appState.weekStartsOnMonday ? 2 : 1
        
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = startOfWeekDay
        
        guard let startOfWeek = calendar.date(from: components) else { return [] }
        
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let calendar = Calendar.current
            let weekRange = currentWeekDates
            let weekStart = weekRange.first ?? Date.distantPast
            let weekEnd = calendar.date(byAdding: .day, value: 1, to: weekRange.last ?? Date.distantFuture) ?? Date.distantFuture

            VStack(spacing: 0) {
                // Header (Days)
                HStack(alignment: .center, spacing: 0) {
                    Text("")
                        .frame(width: timeLabelWidth + timeColumnGutter)
                    
                    ForEach(dayOrder, id: \.self) { day in
                        Text(dayName(for: day))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isToday(day: day) ? FocusColor.color(for: appState.accentColorIndex).opacity(0.1) : Color.clear)
                    }
                }
                .frame(height: dayHeaderHeight)
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
                                            ForEach(appState.calendarManager.events.filter { 
                                                $0.startDate >= weekStart && $0.startDate < weekEnd
                                            }) { event in
                                                if let frame = calculateExternalFrame(event: event, columnWidth: columnWidth) {
                                                    ExternalEventBlockView(event: event)
                                                        .frame(width: frame.width, height: frame.height)
                                                        .position(x: frame.midX, y: frame.midY)
                                                }
                                            }
                                        }
                                        
                                        // 2. Internal Schedules
                                        ForEach(appState.schedules) { schedule in
                                            ForEach(schedule.days.sorted(), id: \.self) { day in
                                                if let colIndex = dayOrder.firstIndex(of: day),
                                                   let frame = calculateFrame(schedule: schedule, colIndex: colIndex, columnWidth: columnWidth) {
                                                    ScheduleBlockView(schedule: schedule)
                                                        .frame(width: frame.width, height: frame.height)
                                                        .position(x: frame.midX, y: frame.midY)
                                                        .onTapGesture {
                                                            editorContext = ScheduleEditorContext(
                                                                day: day,
                                                                schedule: schedule
                                                            )
                                                        }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Current Time Indicator
                            CurrentTimeIndicator(hourHeight: hourHeight, timeLabelWidth: timeLabelWidth + timeColumnGutter, dayOrder: dayOrder)
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
        let hour = Int(h)
        let min = Int((h - CGFloat(hour)) * 60)
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
            schedule: nil
        )
    }
    
    func finalizeDrag(_ data: DragSelection) {
        let calendar = Calendar.current
        
        let snap = { (h: CGFloat) -> CGFloat in
            return (h * 4).rounded() / 4.0
        }
        
        let startH = snap(min(data.startHour, data.endHour))
        var endH = snap(max(data.startHour, data.endHour))
        
        // Ensure at least 15 mins
        if endH - startH < 0.25 {
            endH = startH + 0.25
        }
        
        let startHour = Int(startH)
        let startMin = Int(((startH - CGFloat(startHour)) * 60).rounded())
        
        let endHour = Int(endH)
        let endMin = Int(((endH - CGFloat(endHour)) * 60).rounded())
        
        let start = calendar.date(from: DateComponents(hour: startHour, minute: startMin))
        let end = calendar.date(from: DateComponents(hour: endHour, minute: endMin))
        
        editorContext = ScheduleEditorContext(
            day: data.day,
            startTime: start,
            endTime: end,
            schedule: nil
        )
    }
    
    func dayName(for day: Int) -> String {
        return Calendar.current.shortWeekdaySymbols[day - 1]
    }
    
    func isToday(day: Int) -> Bool {
        return Calendar.current.component(.weekday, from: Date()) == day
    }
    
    func timeString(hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }
    
    func calculateFrame(schedule: Schedule, colIndex: Int, columnWidth: CGFloat) -> CGRect? {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: schedule.startTime)
        let endComp = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
        
        guard let startHour = startComp.hour, let startMin = startComp.minute,
              let endHour = endComp.hour, let endMin = endComp.minute else { return nil }
        
        let startY = (CGFloat(startHour) + CGFloat(startMin) / 60.0) * hourHeight
        var endY = (CGFloat(endHour) + CGFloat(endMin) / 60.0) * hourHeight
        
        if startY > endY { endY = 24 * hourHeight }
        
        let height = max(endY - startY, 15)
        let x = CGFloat(colIndex) * columnWidth + 2
        
        return CGRect(x: x, y: startY, width: columnWidth - 4, height: height)
    }

    func calculateExternalFrame(event: ExternalEvent, columnWidth: CGFloat) -> CGRect? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: event.startDate)
        
        guard let colIndex = dayOrder.firstIndex(of: weekday) else { return nil }
        
        let startComp = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let endComp = calendar.dateComponents([.hour, .minute], from: event.endDate)
        
        guard let startHour = startComp.hour, let startMin = startComp.minute,
              let endHour = endComp.hour, let endMin = endComp.minute else { return nil }
        
        let startY = (CGFloat(startHour) + CGFloat(startMin) / 60.0) * hourHeight
        let endY = (CGFloat(endHour) + CGFloat(endMin) / 60.0) * hourHeight
        
        let height = max(endY - startY, 15)
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
    @State private var currentTimeOffset: CGFloat = 0
    @State private var currentDayIndex: Int?
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
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