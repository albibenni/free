import SwiftUI

struct WeeklyCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingAddSchedule: Bool
    @Binding var selectedDay: Int?
    @Binding var selectedTime: Date?
    
    let hourHeight: CGFloat = 60
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
                        
                        // Tappable Areas (Background)
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeLabelWidth)
                            ForEach(1...7, id: \.self) { day in
                                VStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .frame(height: hourHeight)
                                            .onTapGesture {
                                                handleTap(day: day, hour: hour)
                                            }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Schedule Blocks
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeLabelWidth)
                            // We need a GeometryReader here to get the exact width of a day column
                            GeometryReader { innerGeo in
                                let columnWidth = innerGeo.size.width / 7
                                
                                ZStack(alignment: .topLeading) {
                                    ForEach(appState.schedules) { schedule in
                                        ForEach(schedule.days.sorted(), id: \.self) { day in
                                            // Calculate position
                                            if let frame = calculateFrame(schedule: schedule, day: day, columnWidth: columnWidth) {
                                                ScheduleBlockView(schedule: schedule)
                                                    .frame(width: frame.width, height: frame.height)
                                                    .position(x: frame.midX, y: frame.midY)
                                            }
                                            
                                            // Handle overnight wrapping (segment on the next day)
                                            // Note: simplistic handling, only drawing the second part if it wraps
                                            if isOvernight(schedule: schedule) {
                                                // TODO: complex rendering for overnight
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
    
    func handleTap(day: Int, hour: Int) {
        selectedDay = day
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        selectedTime = Calendar.current.date(from: components)
        showingAddSchedule = true
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
