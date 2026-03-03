import AppKit
import SwiftUI

private func makeWidgetHeader(
    title: String,
    symbolName: String,
    color: NSColor
) -> NSView {
    let iconView = NSImageView()
    iconView.image = appKitSymbolImage(
        named: symbolName,
        pointSize: 16,
        weight: .semibold,
        color: color
    )
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
    iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = .labelColor

    let row = NSStackView(views: [iconView, titleLabel, NSView()])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    return row
}

private func makeSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11, weight: .bold)
    label.textColor = .secondaryLabelColor
    return label
}

private func makeBodyLabel(_ text: String, alignment: NSTextAlignment = .left) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13)
    label.textColor = .secondaryLabelColor
    label.alignment = alignment
    label.lineBreakMode = .byTruncatingTail
    return label
}

private func makeDividerView() -> NSView {
    let divider = NSView()
    divider.wantsLayer = true
    divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return divider
}

private func makePresetButton(
    title: String,
    isSelected: Bool,
    color: NSColor,
    action: @escaping () -> Void
) -> ActionButton {
    let button = makeAppKitSecondaryButton(title: title, color: isSelected ? color : .secondaryLabelColor)
    button.layer?.backgroundColor =
        isSelected
        ? color.withAlphaComponent(0.16).cgColor
        : NSColor.labelColor.withAlphaComponent(0.04).cgColor
    button.layer?.borderColor =
        isSelected
        ? color.withAlphaComponent(0.3).cgColor
        : NSColor.separatorColor.withAlphaComponent(0.25).cgColor
    button.onAction = action
    return button
}

private func selectedRuleSetIdForPomodoro(_ appState: AppState) -> UUID? {
    appState.activeRuleSetId ?? appState.ruleSets.first?.id
}

final class FocusSchedulesWidgetView: AppKitCardView {
    init(appState: AppState, shellState: FreeShellState) {
        super.init(frame: .zero)

        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        contentStack.addArrangedSubview(
            makeWidgetHeader(
                title: "Focus Schedules",
                symbolName: "calendar",
                color: .systemPurple
            )
        )

        if appState.todaySchedules.isEmpty {
            let emptyLabel = makeBodyLabel("No schedules planned for today.", alignment: .center)
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

        contentStack.addArrangedSubview(makeDividerView())

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
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        timeLabel.textColor = .labelColor

        let dayLabel = makeBodyLabel(schedule.daysString)
        dayLabel.font = .systemFont(ofSize: 11)

        let timeStack = NSStackView(views: [timeLabel, dayLabel])
        timeStack.orientation = .vertical
        timeStack.alignment = .leading
        timeStack.spacing = 2
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        timeStack.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = (
            schedule.type == .focus
                ? accentColor
                : NSColor(schedule.themeColor)
        ).cgColor
        indicator.layer?.cornerRadius = 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 4).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let nameLabel = NSTextField(labelWithString: schedule.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let typeLabel = makeBodyLabel(schedule.type.rawValue)
        typeLabel.font = .systemFont(ofSize: 11)

        let nameStack = NSStackView(views: [nameLabel, typeLabel])
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 2

        let trailingView: NSView
        if !schedule.isEnabled {
            let disabledLabel = NSTextField(labelWithString: "Disabled")
            disabledLabel.font = .systemFont(ofSize: 10, weight: .bold)
            disabledLabel.textColor = .secondaryLabelColor
            disabledLabel.wantsLayer = true
            disabledLabel.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12).cgColor
            disabledLabel.layer?.cornerRadius = 4
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

final class FocusAllowedWebsitesWidgetView: AppKitCardView {
    init(appState: AppState, shellState: FreeShellState) {
        super.init(frame: .zero)

        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        contentStack.addArrangedSubview(
            makeWidgetHeader(
                title: "Allowed Websites",
                symbolName: "globe",
                color: .systemBlue
            )
        )

        if appState.ruleSets.isEmpty {
            contentStack.addArrangedSubview(makeBodyLabel("No allow lists yet."))
        } else {
            contentStack.addArrangedSubview(makeSectionLabel("SELECT LIST"))

            let scrollView = VerticalStackScrollContainer(
                contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            )
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.heightAnchor.constraint(equalToConstant: 220).isActive = true

            for set in appState.ruleSets {
                let button = makeRuleSetButton(
                    set: set,
                    isSelected: appState.activeRuleSetId == set.id,
                    accentColor: accentColor
                ) {
                    guard !appState.isStrictActive else { return }
                    appState.activeRuleSetId = set.id
                }
                button.isEnabled = !appState.isStrictActive
                scrollView.stackView.addArrangedSubview(button)
                button.widthAnchor.constraint(equalTo: scrollView.stackView.widthAnchor).isActive = true
            }

            contentStack.addArrangedSubview(scrollView)
        }

        contentStack.addArrangedSubview(makeDividerView())

        let button = makeAppKitPrimaryButton(title: "Manage & Edit Lists", color: accentColor)
        button.onAction = { shellState.showRules = true }
        contentStack.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRuleSetButton(
        set: RuleSet,
        isSelected: Bool,
        accentColor: NSColor,
        action: @escaping () -> Void
    ) -> ActionButton {
        let button = ActionButton(title: set.name)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor =
            isSelected
            ? accentColor.withAlphaComponent(0.12).cgColor
            : NSColor.labelColor.withAlphaComponent(0.03).cgColor
        button.layer?.borderColor =
            isSelected
            ? accentColor.withAlphaComponent(0.25).cgColor
            : NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        button.layer?.borderWidth = 1
        button.image = appKitSymbolImage(
            named: isSelected ? "link.circle.fill" : "link",
            pointSize: 13,
            weight: isSelected ? .semibold : .regular,
            color: isSelected ? accentColor : .secondaryLabelColor
        )
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.attributedTitle = NSAttributedString(
            string: set.name,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular),
                .foregroundColor: isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ]
        )
        button.contentTintColor = isSelected ? accentColor : .secondaryLabelColor
        button.onAction = action
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }
}

final class FocusPomodoroWidgetView: AppKitCardView {
    private let appState: AppState
    private let accentColor: NSColor

    init(appState: AppState) {
        self.appState = appState
        self.accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        super.init(frame: .zero)

        contentStack.addArrangedSubview(
            makeWidgetHeader(
                title: "Pomodoro Mode",
                symbolName: "timer",
                color: .systemRed
            )
        )
        contentStack.addArrangedSubview(makePresetsSection())
        contentStack.addArrangedSubview(makeQuickBreakSection())
        contentStack.addArrangedSubview(makeMainStatusSection())

        if !appState.ruleSets.isEmpty {
            contentStack.addArrangedSubview(makeRuleSetSection())
        }

        let actionView = makeActionButtons()
        contentStack.addArrangedSubview(actionView)
        if let button = actionView as? NSButton {
            button.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makePresetsSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel("PRESETS"))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        for (focus, breakTime, label) in [(25.0, 5.0, "25/5"), (45.0, 15.0, "45/15"), (50.0, 10.0, "50/10"), (90.0, 20.0, "90/20")] {
            let button = makePresetButton(
                title: label,
                isSelected: appState.pomodoroFocusDuration == focus && appState.pomodoroBreakDuration == breakTime,
                color: accentColor
            ) { [weak appState] in
                appState?.pomodoroFocusDuration = focus
                appState?.pomodoroBreakDuration = breakTime
            }
            buttons.addArrangedSubview(button)
        }

        stack.addArrangedSubview(buttons)
        return stack
    }

    private func makeQuickBreakSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel("QUICK BREAK"))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        for minutes in [5, 15, 30] {
            let button = makePresetButton(
                title: "\(minutes)m",
                isSelected: false,
                color: .secondaryLabelColor
            ) { [weak appState] in
                appState?.startPause(minutes: Double(minutes))
            }
            button.isEnabled = appState.isBlocking && !appState.isStrictActive
            buttons.addArrangedSubview(button)
        }

        let customButton = makePresetButton(
            title: "Custom",
            isSelected: false,
            color: .secondaryLabelColor
        ) { [weak self] in
            self?.presentCustomBreakPrompt()
        }
        customButton.isEnabled = appState.isBlocking && !appState.isStrictActive
        buttons.addArrangedSubview(customButton)

        stack.addArrangedSubview(buttons)
        return stack
    }

    private func makeMainStatusSection() -> NSView {
        if appState.pomodoroStatus == .none {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 16
            row.distribution = .fillEqually
            row.addArrangedSubview(
                makeDurationControl(
                    title: "FOCUS",
                    value: Int(appState.pomodoroFocusDuration),
                    maxMinutes: 120
                ) { [weak appState] delta in
                    guard let appState else { return }
                    appState.pomodoroFocusDuration = min(
                        120,
                        max(5, appState.pomodoroFocusDuration + delta)
                    )
                }
            )
            row.addArrangedSubview(
                makeDurationControl(
                    title: "BREAK",
                    value: Int(appState.pomodoroBreakDuration),
                    maxMinutes: 60
                ) { [weak appState] delta in
                    guard let appState else { return }
                    appState.pomodoroBreakDuration = min(
                        60,
                        max(5, appState.pomodoroBreakDuration + delta)
                    )
                }
            )
            return row
        }

        let phaseCard = AppKitCardView()
        phaseCard.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.03).cgColor

        let phaseLabel = NSTextField(
            labelWithString: appState.pomodoroStatus == .focus ? "FOCUSING" : "BREAKING"
        )
        phaseLabel.font = .systemFont(ofSize: 12, weight: .black)
        phaseLabel.textColor = .secondaryLabelColor

        let timeLabel = NSTextField(labelWithString: appState.timeString(time: appState.pomodoroRemaining))
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        timeLabel.textColor = .labelColor

        phaseCard.contentStack.alignment = .centerX
        phaseCard.contentStack.addArrangedSubview(phaseLabel)
        phaseCard.contentStack.addArrangedSubview(timeLabel)

        if let activeId = appState.currentPrimaryRuleSetId,
           let setName = appState.ruleSets.first(where: { $0.id == activeId })?.name,
           appState.pomodoroStatus == .focus {
            let badge = makePresetButton(title: setName, isSelected: true, color: accentColor) {}
            badge.isEnabled = false
            phaseCard.contentStack.addArrangedSubview(badge)
        }

        return phaseCard
    }

    private func makeRuleSetSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        container.addArrangedSubview(makeSectionLabel("SELECT LIST"))

        let scrollView = VerticalStackScrollContainer(
            contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        )
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 150).isActive = true

        let selectedId = selectedRuleSetIdForPomodoro(appState)
        for set in appState.ruleSets {
            let isSelected = selectedId == set.id
            let button = makePresetButton(
                title: set.name,
                isSelected: isSelected,
                color: accentColor
            ) { [weak appState] in
                guard let appState, !appState.isStrictActive else { return }
                appState.activeRuleSetId = set.id
            }
            button.image = appKitSymbolImage(
                named: isSelected ? "link.circle.fill" : "link",
                pointSize: 12,
                weight: isSelected ? .semibold : .regular,
                color: isSelected ? accentColor : .secondaryLabelColor
            )
            button.imagePosition = .imageLeading
            button.contentTintColor = isSelected ? accentColor : .secondaryLabelColor
            button.alignment = .left
            button.isEnabled = !appState.isStrictActive
            scrollView.stackView.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: scrollView.stackView.widthAnchor).isActive = true
        }

        container.addArrangedSubview(scrollView)
        return container
    }

    private func makeActionButtons() -> NSView {
        if appState.pomodoroStatus == .none {
            let button = makeAppKitPrimaryButton(title: "Start Focus Session", color: accentColor)
            button.onAction = { [weak appState] in appState?.startPomodoro() }
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.distribution = .fillEqually

        let skipButton = makeAppKitSecondaryButton(title: "Skip", color: accentColor)
        skipButton.onAction = { [weak appState] in appState?.skipPomodoroPhase() }
        skipButton.isEnabled = !appState.isPomodoroLocked

        let stopButton = makeAppKitPrimaryButton(title: "Stop", color: .systemRed)
        stopButton.onAction = { [weak self] in
            guard let self else { return }
            if self.appState.isPomodoroLocked {
                self.presentStopChallengePrompt()
            } else {
                self.appState.stopPomodoro()
            }
        }

        row.addArrangedSubview(skipButton)
        row.addArrangedSubview(stopButton)
        return row
    }

    private func makeDurationControl(
        title: String,
        value: Int,
        maxMinutes: Int,
        onAdjust: @escaping (Double) -> Void
    ) -> NSView {
        let card = AppKitCardView()
        card.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.03).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .black)
        titleLabel.textColor = .secondaryLabelColor

        let valueLabel = NSTextField(labelWithString: "\(value) min")
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = .labelColor

        let minusButton = makePresetButton(title: "-", isSelected: false, color: .secondaryLabelColor) {
            onAdjust(-5)
        }
        minusButton.isEnabled = value > 5

        let plusButton = makePresetButton(title: "+", isSelected: false, color: .secondaryLabelColor) {
            onAdjust(5)
        }
        plusButton.isEnabled = value < maxMinutes

        let controls = NSStackView(views: [minusButton, plusButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        card.contentStack.alignment = .centerX
        card.contentStack.addArrangedSubview(titleLabel)
        card.contentStack.addArrangedSubview(valueLabel)
        card.contentStack.addArrangedSubview(controls)
        return card
    }

    private func presentCustomBreakPrompt() {
        let field = NSTextField(string: "")
        field.placeholderString = "Minutes"
        let alert = NSAlert()
        alert.messageText = "Custom Break"
        alert.informativeText = "Enter duration in minutes."
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let present: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            guard let self, let minutes = Double(field.stringValue) else { return }
            self.appState.startPause(minutes: minutes)
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: present)
        } else {
            present(alert.runModal())
        }
    }

    private func presentStopChallengePrompt() {
        let field = NSTextField(string: "")
        field.placeholderString = "Type the phrase exactly"
        let alert = NSAlert()
        alert.messageText = "Emergency Unlock"
        alert.informativeText =
            "To stop a Strict Pomodoro session, type the following exactly:\n\n\"\(AppState.challengePhrase)\""
        alert.accessoryView = field
        alert.addButton(withTitle: "Stop Pomodoro")
        alert.addButton(withTitle: "Cancel")

        let present: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            guard let self else { return }
            _ = self.appState.stopPomodoroWithChallenge(phrase: field.stringValue)
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: present)
        } else {
            present(alert.runModal())
        }
    }
}
