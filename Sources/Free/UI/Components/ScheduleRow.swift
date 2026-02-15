import SwiftUI

struct ScheduleRow: View {
    @Binding var schedule: Schedule
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(schedule.themeColor)
                .frame(width: 4, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: schedule.type == .focus ? "target" : "cup.and.saucer.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(schedule.name)
                        .font(.headline)
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
