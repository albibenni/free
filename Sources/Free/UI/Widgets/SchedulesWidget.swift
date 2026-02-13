import SwiftUI

struct SchedulesWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSchedules: Bool
    
    var body: some View {
        WidgetCard {
            Button(action: { showSchedules = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("Focus Schedules")
                            .font(.headline)
                        Spacer()
                        Text("\(appState.schedules.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if appState.schedules.isEmpty {
                        Text("No schedules set. Click to automate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.schedules.prefix(2)) { schedule in
                                HStack {
                                    Circle()
                                        .fill(schedule.isEnabled ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)
                                    Text(schedule.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if appState.schedules.count > 2 {
                                Text("and \(appState.schedules.count - 2) more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                            }
                        }
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
        }
    }
}
