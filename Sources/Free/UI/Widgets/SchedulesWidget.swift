import SwiftUI

struct SchedulesWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSchedules: Bool
    @State private var isExpanded = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var todaySchedules: [Schedule] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return appState.schedules.filter { $0.days.contains(weekday) }
            .sorted { s1, s2 in
                let c1 = Calendar.current.dateComponents([.hour, .minute], from: s1.startTime)
                let c2 = Calendar.current.dateComponents([.hour, .minute], from: s2.startTime)
                let m1 = (c1.hour ?? 0) * 60 + (c1.minute ?? 0)
                let m2 = (c2.hour ?? 0) * 60 + (c2.minute ?? 0)
                return m1 < m2
            }
    }
    
    var body: some View {
        WidgetCard {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                    Text("Focus Schedules")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !isExpanded {
                        let activeCount = todaySchedules.filter { $0.isEnabled }.count
                        if activeCount > 0 {
                            Text("\(activeCount) today")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(FocusColor.color(for: appState.accentColorIndex).opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if todaySchedules.isEmpty {
                        Text("No schedules planned for today.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(todaySchedules) { schedule in
                                HStack(spacing: 12) {
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text(timeFormatter.string(from: schedule.startTime))
                                            .font(.system(.caption, design: .monospaced))
                                            .fontWeight(.bold)
                                        Text(timeFormatter.string(from: schedule.endTime))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 65)
                                    
                                    Capsule()
                                        .fill(schedule.themeColor)
                                        .frame(width: 4)
                                        .frame(height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(schedule.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(schedule.type.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !schedule.isEnabled {
                                        Text("Disabled")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(4)
                                    } else if schedule.isActive() {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                            .shadow(color: .green.opacity(0.5), radius: 2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Divider().opacity(0.5)
                    
                    Button(action: { showSchedules = true }) {
                        Text("Open Full Calendar")
                    }
                    .buttonStyle(AppPrimaryButtonStyle(
                        color: FocusColor.color(for: appState.accentColorIndex),
                        maxWidth: .infinity
                    ))
                }
                .padding([.horizontal, .bottom])
            }
        }
    }
}
