import SwiftUI

struct WeeklyCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingAddSchedule: Bool
    @Binding var selectedDay: Int?
    @Binding var selectedTime: Date?
    @Binding var selectedSchedule: Schedule?
    
    @State private var dragData: DragSelection?
    
    struct DragSelection {
        let day: Int
        let startHour: CGFloat
        var endHour: CGFloat
    }
    
    let hourHeight: CGFloat = 80
    let dayHeaderHeight: CGFloat = 40
    let timeLabelWidth: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header (Days)
                HStack(alignment: .center, spacing: 0) {
                    Text("")
                        .frame(width: timeLabelWidth)
                    
                    ForEach(1...7, id: \.self) { day in
                        Text(dayName(for: day))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isToday(day: day) ? Color.blue.opacity(0.1) : Color.clear)
                    }
                }
                .frame(height: dayHeaderHeight)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Scrollable Grid
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Grid Lines & Time Labels
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(alignment: .top, spacing: 0) {
                                    // Time Label
                                    Text(timeString(hour: hour))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: timeLabelWidth, alignment: .trailing)
                                        .padding(.trailing, 8)
                                        .offset(y: -6) // Align with line
                                    
                                    // Horizontal Line
                                    Divider()
                                }
                                .frame(height: hourHeight, alignment: .top)
                            }
                        }
                        
                        // Vertical Day Lines
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeLabelWidth)
                            ForEach(1...7, id: \.self) { day in
                                Divider()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        
                        // Tappable & Draggable Areas (Background)
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeLabelWidth)
                            ForEach(1...7, id: \.self) { day in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(maxWidth: .infinity, maxHeight: 24 * hourHeight)
                                    .gesture(
                                        DragGesture(minimumDistance: 10)
                                            .onChanged { value in
                                                let startY = value.startLocation.y
                                                let currentY = value.location.y
                                                if dragData == nil {
                                                    dragData = DragSelection(day: day, startHour: startY / hourHeight, endHour: currentY / hourHeight)
                                                } else {
                                                    dragData?.endHour = currentY / hourHeight
                                                }
                                            }
                                            .onEnded { _ in
                                                if let data = dragData {
                                                    finalizeDrag(data)
                                                    dragData = nil
                                                }
                                            }
                                    )
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            // We need to know the Y position of the tap
                                            // Since TapGesture doesn't give location, we'll use a hack or just use a coordinate space
                                        }
                                    )
                                    // Using individual hour cells for tap-to-add since TapGesture location is hard in SwiftUI
                                    .overlay(
                                        VStack(spacing: 0) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Color.clear
                                                    .contentShape(Rectangle())
                                                    .frame(height: hourHeight)
                                                    .onTapGesture {
                                                        quickAdd(day: day, hour: hour)
                                                    }
                                                    .onLongPressGesture {
                                                        openPreciseEditor(day: day, hour: hour)
                                                    }
                                            }
                                        }
                                    )
                            }
                        }
                        
                        // Ghost block while dragging
                        if let data = dragData {
                            let columnWidth = (geometry.size.width - timeLabelWidth) / 7
                            let startH = min(data.startHour, data.endHour)
                            let endH = max(data.startHour, data.endHour)
                            let y = startH * hourHeight
                            let h = max(endH - startH, 0.1) * hourHeight
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: columnWidth - 4, height: h)
                                .offset(x: timeLabelWidth + CGFloat(data.day - 1) * columnWidth + 2, y: y)
                        }
                        
                        // Schedule Blocks
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeLabelWidth)
                            GeometryReader { innerGeo in
                                let columnWidth = innerGeo.size.width / 7
                                
                                ZStack(alignment: .topLeading) {
                                    ForEach(appState.schedules) { schedule in
                                        ForEach(schedule.days.sorted(), id: \.self) { day in
                                            if let frame = calculateFrame(schedule: schedule, day: day, columnWidth: columnWidth) {
                                                ScheduleBlockView(schedule: schedule)
                                                    .frame(width: frame.width, height: frame.height)
                                                    .position(x: frame.midX, y: frame.midY)
                                                    .onTapGesture {
                                                        selectedSchedule = schedule
                                                        selectedDay = day
                                                        showingAddSchedule = true
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Current Time Indicator
                        CurrentTimeIndicator(hourHeight: hourHeight, timeLabelWidth: timeLabelWidth)
                    }
                }
            }
        }
    }
    
    func quickAdd(day: Int, hour: Int) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: hour, minute: 0)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: hour + 1, minute: 0)) ?? Date()
        
        let new = Schedule(name: "Focus Session", days: [day], startTime: start, endTime: end)
        appState.schedules.append(new)
    }
    
    func openPreciseEditor(day: Int, hour: Int) {
        let calendar = Calendar.current
        selectedDay = day
        selectedTime = calendar.date(from: DateComponents(hour: hour, minute: 0))
        selectedSchedule = nil
        showingAddSchedule = true
    }
    
    func finalizeDrag(_ data: DragSelection) {
        let calendar = Calendar.current
        let startH = min(data.startHour, data.endHour)
        let endH = max(data.startHour, data.endHour)
        
        let startHour = Int(startH)
        let startMin = Int((startH - CGFloat(startHour)) * 60)
        
        let endHour = Int(endH)
        let endMin = Int((endH - CGFloat(endHour)) * 60)
        
        // Ensure at least 15 mins
        let startTotal = startHour * 60 + startMin
        var endTotal = endHour * 60 + endMin
        if endTotal - startTotal < 15 {
            endTotal = startTotal + 60 // Default to 1 hour if too small
        }
        
        let start = calendar.date(from: DateComponents(hour: startTotal / 60, minute: startTotal % 60)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: endTotal / 60, minute: endTotal % 60)) ?? Date()
        
        let new = Schedule(name: "Focus Session", days: [data.day], startTime: start, endTime: end)
        appState.schedules.append(new)
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
    
    func isOvernight(schedule: Schedule) -> Bool {
        return schedule.startTime > schedule.endTime // Rough check based on time components only logic
    }
    
    func calculateFrame(schedule: Schedule, day: Int, columnWidth: CGFloat) -> CGRect? {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: schedule.startTime)
        let endComp = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
        
        guard let startHour = startComp.hour, let startMin = startComp.minute,
              let endHour = endComp.hour, let endMin = endComp.minute else { return nil }
        
        let startY = (CGFloat(startHour) + CGFloat(startMin) / 60.0) * hourHeight
        var endY = (CGFloat(endHour) + CGFloat(endMin) / 60.0) * hourHeight
        
        // Handle overnight (draw until bottom)
        if startY > endY {
            endY = 24 * hourHeight // Cap at midnight for the first day segment
        }
        
        let height = max(endY - startY, 15) // Min height
        let x = CGFloat(day - 1) * columnWidth
        
        return CGRect(x: x, y: startY, width: columnWidth - 2, height: height)
    }
}

struct ScheduleBlockView: View {
    let schedule: Schedule
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(schedule.isEnabled ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5))
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    Text(schedule.name)
                        .font(.caption)
                        .bold()
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
            .padding(.horizontal, 1)
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
    @State private var currentTimeOffset: CGFloat = 0
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: timeLabelWidth - 4)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(y: currentTimeOffset)
        .onAppear { updateTime() }
        .onReceive(timer) { _ in updateTime() }
    }
    
    func updateTime() {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        if let h = comps.hour, let m = comps.minute {
            currentTimeOffset = (CGFloat(h) + CGFloat(m) / 60.0) * hourHeight
        }
    }
}
