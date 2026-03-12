import AppKit

final class FocusSchedulesWidgetView: AppKitCardView {
    init(appState: AppState, shellState: FreeShellState) {
        super.init(frame: .zero)

        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        contentStack.addArrangedSubview(
            makeAppKitHeaderRow(
                title: "Focus Schedules",
                symbolName: AppKitUISymbols.Name.schedules,
                color: .systemPurple
            )
        )

        if appState.todaySchedules.isEmpty {
            let emptyLabel = makeAppKitBodyLabel("No schedules planned for today.", alignment: .center)
            emptyLabel.alignment = .center
            contentStack.addArrangedSubview(emptyLabel)
        } else {
            let rows = NSStackView()
            rows.orientation = .vertical
            rows.alignment = .leading
            rows.spacing = 10

            for schedule in appState.todaySchedules {
                let row = makeScheduleRow(
                    schedule: schedule,
                    accentColor: accentColor
                )
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            }

            contentStack.addArrangedSubview(rows)
        }

        contentStack.addArrangedSubview(makeAppKitDividerView())

        let button = makeAppKitPrimaryButton(title: "Open Full Calendar", color: accentColor)
        button.onAction = { shellState.showSchedules = true }
        contentStack.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeScheduleRow(schedule: Schedule, accentColor: NSColor) -> NSView {
        let row = AppKitFlippedView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let timeLabel = NSTextField(labelWithString: schedule.timeRangeString)
        timeLabel.font = .monospacedDigitSystemFont(
            ofSize: AppKitUIConstants.Typography.regular.pointSize,
            weight: .semibold
        )
        timeLabel.textColor = .labelColor

        let dayLabel = makeAppKitBodyLabel(schedule.daysString)
        dayLabel.font = AppKitUIConstants.Typography.helperLabel

        let timeStack = NSStackView(views: [timeLabel, dayLabel])
        timeStack.orientation = .vertical
        timeStack.alignment = .leading
        timeStack.spacing = AppKitUIConstants.Spacing.compact / 2
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        timeStack.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = (
            schedule.type == .focus
                ? accentColor
                : appKitEmphasizedUnfocusColor(FocusColor.nsColor(for: schedule.colorIndex))
        ).cgColor
        indicator.layer?.cornerRadius = AppKitUIConstants.CornerRadius.badge / 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 4).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let nameLabel = NSTextField(labelWithString: schedule.name)
        nameLabel.font = AppKitUIConstants.Typography.buttonLabel
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let typeLabel = makeAppKitBodyLabel(schedule.type.rawValue)
        typeLabel.font = AppKitUIConstants.Typography.helperLabel

        let nameStack = NSStackView(views: [nameLabel, typeLabel])
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = AppKitUIConstants.Spacing.compact / 2

        let trailingView: NSView
        if !schedule.isEnabled {
            let disabledLabel = NSTextField(labelWithString: "Disabled")
            disabledLabel.font = AppKitUIConstants.Typography.regular
            disabledLabel.textColor = .secondaryLabelColor
            disabledLabel.wantsLayer = true
            disabledLabel.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12).cgColor
            disabledLabel.layer?.cornerRadius = AppKitUIConstants.CornerRadius.badge
            disabledLabel.alignment = .center
            disabledLabel.translatesAutoresizingMaskIntoConstraints = false
            disabledLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
            trailingView = disabledLabel
        } else if schedule.isActive() {
            let activeDot = NSView()
            activeDot.wantsLayer = true
            activeDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            activeDot.layer?.cornerRadius = 4
            activeDot.translatesAutoresizingMaskIntoConstraints = false
            activeDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            activeDot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            trailingView = activeDot
        } else {
            trailingView = NSView()
        }

        let stack = NSStackView(views: [timeStack, indicator, nameStack, NSView(), trailingView])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            stack.topAnchor.constraint(equalTo: row.topAnchor),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }
}
