import SwiftUI

struct ScheduleRow: View {
    @Binding var schedule: Schedule
    var accentColorIndex: Int
    var onDelete: () -> Void

    init(
        schedule: Binding<Schedule>,
        accentColorIndex: Int = 0,
        onDelete: @escaping () -> Void
    ) {
        self._schedule = schedule
        self.accentColorIndex = accentColorIndex
        self.onDelete = onDelete
    }

    var indicatorColor: Color {
        Self.indicatorColor(for: schedule, accentColorIndex: accentColorIndex)
    }

    static func indicatorColor(for schedule: Schedule, accentColorIndex: Int) -> Color {
        schedule.type == .focus ? FocusColor.color(for: accentColorIndex) : schedule.themeColor
    }

    static func isImported(_ schedule: Schedule) -> Bool {
        schedule.importedCalendarEventKey != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(indicatorColor)
                .frame(width: 4, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: schedule.type == .focus ? "target" : "cup.and.saucer.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(schedule.name)
                        .font(.headline)
                    if Self.isImported(schedule) {
                        Label("Imported", systemImage: "calendar.badge.clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text(schedule.timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(schedule.daysString)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            Spacer()

            HStack(spacing: 12) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.body)
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $schedule.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .fixedSize()
        }
        .padding(.vertical, 4)
    }
}
