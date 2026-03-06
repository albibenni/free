import AppKit

final class SchedulesListDocumentNSView: NSView {
    private var schedules: [Schedule] = []
    private var accentColorIndex: Int = 0
    private var onSelectSchedule: ((Schedule) -> Void)?
    private var onDeleteSchedule: ((UUID) -> Void)?
    private var onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
    private var rowViews: [UUID: SchedulesListRowNSView] = [:]

    override var isFlipped: Bool { true }

    func configure(
        schedules: [Schedule],
        accentColorIndex: Int,
        onSelectSchedule: @escaping (Schedule) -> Void,
        onDeleteSchedule: @escaping (UUID) -> Void,
        onToggleScheduleEnabled: @escaping (UUID, Bool) -> Void
    ) {
        self.schedules = schedules
        self.accentColorIndex = accentColorIndex
        self.onSelectSchedule = onSelectSchedule
        self.onDeleteSchedule = onDeleteSchedule
        self.onToggleScheduleEnabled = onToggleScheduleEnabled

        rebuildRows()
    }

    func layoutRows(width: CGFloat) {
        let rowHeight: CGFloat = 68
        let contentWidth = max(width, 1)
        var y: CGFloat = 0

        for (index, schedule) in schedules.enumerated() {
            guard let rowView = rowViews[schedule.id] else { continue }
            rowView.frame = CGRect(x: 0, y: y, width: contentWidth, height: rowHeight)
            rowView.showsSeparator = index < schedules.count - 1
            y += rowHeight
        }

        frame = CGRect(x: 0, y: 0, width: contentWidth, height: max(y, 1))
    }

    private func rebuildRows() {
        rowViews.values.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()

        for schedule in schedules {
            let rowView = SchedulesListRowNSView()
            rowView.configure(
                schedule: schedule,
                accentColorIndex: accentColorIndex,
                onSelectSchedule: onSelectSchedule,
                onDeleteSchedule: onDeleteSchedule,
                onToggleScheduleEnabled: onToggleScheduleEnabled
            )
            addSubview(rowView)
            rowViews[schedule.id] = rowView
        }

        needsLayout = true
    }
}
