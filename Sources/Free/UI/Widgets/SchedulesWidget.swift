import SwiftUI

struct SchedulesWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSchedules: Bool
    @State private var isExpanded = false

    init(showSchedules: Binding<Bool>, initialIsExpanded: Bool = false) {
        self._showSchedules = showSchedules
        self._isExpanded = State(initialValue: initialIsExpanded)
    }

    func openSchedules() {
        showSchedules = true
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        WidgetCard {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Text("Focus Schedules")
                        .font(.headline)

                    Spacer()

                    if !isExpanded {
                        let activeCount = appState.todaySchedules.filter { $0.isEnabled }.count
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
                    if appState.todaySchedules.isEmpty {
                        Text("No schedules planned for today.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(appState.todaySchedules) { schedule in
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

                    Button(action: openSchedules) {
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
