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

        reconcileRows()
    }

    func layoutRows(width: CGFloat) {
        let rowHeight: CGFloat = 68
        let contentWidth = max(width, 1)
        var y: CGFloat = 0

        for (index, schedule) in schedules.enumerated() {
            let rowView = rowViews[schedule.id]!
            rowView.frame = CGRect(x: 0, y: y, width: contentWidth, height: rowHeight)
            rowView.showsSeparator = index < schedules.count - 1
            y += rowHeight
        }

        frame = CGRect(x: 0, y: 0, width: contentWidth, height: max(y, 1))
    }

    private func reconcileRows() {
        withAppKitSignpost("SchedulesListReconcileRows") {
            let desiredIds = Set(schedules.map(\.id))

            let idsToRemove = rowViews.keys.filter { !desiredIds.contains($0) }
            for id in idsToRemove {
                let rowView = rowViews[id]!
                rowView.removeFromSuperview()
                rowViews.removeValue(forKey: id)
            }

            for schedule in schedules {
                let rowView = rowViews[schedule.id] ?? SchedulesListRowNSView()
                rowView.configure(
                    schedule: schedule,
                    accentColorIndex: accentColorIndex,
                    onSelectSchedule: onSelectSchedule,
                    onDeleteSchedule: onDeleteSchedule,
                    onToggleScheduleEnabled: onToggleScheduleEnabled
                )

                if rowView.superview !== self {
                    addSubview(rowView)
                }

                rowViews[schedule.id] = rowView
            }

            let orderedRows = schedules.compactMap { rowViews[$0.id] }
            let hasDifferentOrder =
                subviews.count != orderedRows.count
                || zip(subviews, orderedRows).contains { current, expected in
                    current !== expected
                }
            if hasDifferentOrder {
                subviews = orderedRows
            }

            needsLayout = true
        }
    }
}

extension SchedulesListDocumentNSView {
    func rowObjectIdentifierForTesting(scheduleId: UUID) -> ObjectIdentifier? {
        rowViews[scheduleId].map(ObjectIdentifier.init)
    }
}
