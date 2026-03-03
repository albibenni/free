import AppKit

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
    titleLabel.font = AppKitUIConstants.Typography.cardTitle
    titleLabel.textColor = .labelColor

    let row = NSStackView(views: [iconView, titleLabel, NSView()])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = AppKitUIConstants.Spacing.sectionStack
    return row
}

private func makeSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.helperLabel
    label.textColor = .secondaryLabelColor
    return label
}

private func makeBodyLabel(_ text: String, alignment: NSTextAlignment = .left) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.body
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
    button.setGradientBackground(
        colors: isSelected
            ? [color.withAlphaComponent(0.18), color.withAlphaComponent(0.11)]
            : [
                NSColor.labelColor.withAlphaComponent(0.07),
                NSColor.labelColor.withAlphaComponent(0.03),
            ],
        borderColor: isSelected
            ? color.withAlphaComponent(0.30)
            : NSColor.separatorColor.withAlphaComponent(0.25)
    )
    button.onAction = action
    return button
}

private func selectedRuleSetIdForPomodoro(_ appState: AppState) -> UUID? {
    appState.activeRuleSetId ?? appState.ruleSets.first?.id
}

private func makeSelectableRuleSetRowButton(
    title: String,
    isSelected: Bool,
    accentColor: NSColor,
    action: @escaping () -> Void
) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.layer?.cornerRadius = 8
    button.setGradientBackground(
        colors: isSelected
            ? [accentColor.withAlphaComponent(0.14), accentColor.withAlphaComponent(0.08)]
            : [
                NSColor.labelColor.withAlphaComponent(0.05),
                NSColor.labelColor.withAlphaComponent(0.02),
            ],
        borderColor: isSelected
            ? accentColor.withAlphaComponent(0.22)
            : NSColor.separatorColor.withAlphaComponent(0.18)
    )
    button.image = appKitSymbolImage(
        named: isSelected ? "link.circle.fill" : "link",
        pointSize: 13,
        weight: isSelected ? .semibold : .regular,
        color: isSelected ? accentColor : .secondaryLabelColor
    )
    button.imagePosition = .imageLeading
    button.alignment = .left
    button.contentTintColor = isSelected ? accentColor : .secondaryLabelColor
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular),
            .foregroundColor: isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ]
    )
    button.onAction = action
    button.heightAnchor.constraint(equalToConstant: 34).isActive = true

    let checkView = NSImageView()
    checkView.image = appKitSymbolImage(
        named: "checkmark",
        pointSize: 11,
        weight: .bold,
        color: accentColor
    )
    checkView.isHidden = !isSelected
    checkView.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(checkView)

    NSLayoutConstraint.activate([
        checkView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
        checkView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
    ])

    return button
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
        timeLabel.font = .monospacedDigitSystemFont(
            ofSize: AppKitUIConstants.Typography.regular.pointSize,
            weight: .semibold
        )
        timeLabel.textColor = .labelColor

        let dayLabel = makeBodyLabel(schedule.daysString)
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
                : FocusColor.nsColor(for: schedule.colorIndex)
        ).cgColor
        indicator.layer?.cornerRadius = AppKitUIConstants.CornerRadius.badge / 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 4).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let nameLabel = NSTextField(labelWithString: schedule.name)
        nameLabel.font = AppKitUIConstants.Typography.buttonLabel
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let typeLabel = makeBodyLabel(schedule.type.rawValue)
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
        makeSelectableRuleSetRowButton(
            title: set.name,
            isSelected: isSelected,
            accentColor: accentColor,
            action: action
        )
    }
}

final class FocusPomodoroWidgetView: AppKitCardView {
    private let appState: AppState
    private let accentColor: NSColor
    private let onDialInteractionDidBegin: (() -> Void)?
    private let onDialInteractionDidEnd: (() -> Void)?

    init(
        appState: AppState,
        onDialInteractionDidBegin: (() -> Void)? = nil,
        onDialInteractionDidEnd: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        self.onDialInteractionDidBegin = onDialInteractionDidBegin
        self.onDialInteractionDidEnd = onDialInteractionDidEnd
        super.init(frame: .zero)

        contentStack.spacing = 12
        contentStack.addArrangedSubview(makePomodoroHeader())
        let topContentSection = makeTopContentSection()
        contentStack.addArrangedSubview(topContentSection)
        topContentSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        if !appState.ruleSets.isEmpty {
            let ruleSetSection = makeRuleSetSection()
            contentStack.addArrangedSubview(ruleSetSection)
            ruleSetSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            contentStack.setCustomSpacing(20, after: topContentSection)
        }

        let actionView = makeActionButtons()
        contentStack.addArrangedSubview(actionView)
        if let button = actionView as? NSButton {
            button.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        } else {
            actionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makePomodoroHeader() -> NSView {
        let iconView = NSImageView()
        iconView.image = appKitSymbolImage(
            named: "timer",
            pointSize: 16,
            weight: .semibold,
            color: .systemRed
        )
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let titleLabel = NSTextField(labelWithString: "Pomodoro Mode")
        titleLabel.font = AppKitUIConstants.Typography.cardTitle
        titleLabel.textColor = .labelColor

        let chevronView = NSImageView()
        chevronView.image = appKitSymbolImage(
            named: "chevron.up",
            pointSize: 11,
            weight: .semibold,
            color: .secondaryLabelColor
        )
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chevronView.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let row = NSStackView(views: [iconView, titleLabel, NSView(), chevronView])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = AppKitUIConstants.Spacing.sectionStack
        return row
    }

    private func makeTopContentSection() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 20

        let sidebar = makeSidebarSection()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let mainContent = makeMainStatusSection()
        let mainContainer = AppKitFlippedView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(mainContent)
        mainContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainContent.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            mainContent.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            mainContent.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            mainContent.leadingAnchor.constraint(greaterThanOrEqualTo: mainContainer.leadingAnchor),
            mainContent.trailingAnchor.constraint(lessThanOrEqualTo: mainContainer.trailingAnchor),
        ])

        row.addArrangedSubview(sidebar)
        row.addArrangedSubview(mainContainer)
        return row
    }

    private func makeSidebarSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24

        stack.addArrangedSubview(makeSidebarPresetSection())
        stack.addArrangedSubview(makeSidebarQuickBreakSection())
        return stack
    }

    private func makeMainStatusSection() -> NSView {
        if appState.pomodoroStatus == .none {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 60

            let focusColumn = makeDurationDialColumn(
                title: "FOCUS",
                iconName: "leaf.fill",
                duration: appState.pomodoroFocusDuration,
                maxMinutes: 120
            ) { [weak appState] minutes in
                guard let appState else { return }
                appState.pomodoroFocusDuration = minutes
            }
            let breakColumn = makeDurationDialColumn(
                title: "BREAK",
                iconName: "cup.and.saucer.fill",
                duration: appState.pomodoroBreakDuration,
                maxMinutes: 60
            ) { [weak appState] minutes in
                guard let appState else { return }
                appState.pomodoroBreakDuration = minutes
            }

            row.addArrangedSubview(focusColumn)
            row.addArrangedSubview(breakColumn)
            return row
        }

        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 20

        let phaseLabel = NSTextField(
            labelWithString: appState.pomodoroStatus == .focus ? "FOCUSING" : "BREAKING"
        )
        phaseLabel.font = .systemFont(ofSize: 14, weight: .black)
        phaseLabel.textColor = .secondaryLabelColor

        let totalDurationSeconds =
            appState.pomodoroStatus == .focus
            ? appState.pomodoroFocusDuration * 60
            : appState.pomodoroBreakDuration * 60
        let progress =
            totalDurationSeconds > 0
            ? 1 - (appState.pomodoroRemaining / totalDurationSeconds)
            : 0
        let progressView = PomodoroProgressDialView(
            progress: progress,
            iconName: appState.pomodoroStatus == .focus ? "leaf.fill" : "cup.and.saucer.fill",
            color: appState.pomodoroStatus == .focus ? accentColor : .systemOrange,
            centerText: appState.timeString(time: appState.pomodoroRemaining)
        )
        progressView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        progressView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        column.addArrangedSubview(phaseLabel)
        column.addArrangedSubview(progressView)

        if let activeId = appState.currentPrimaryRuleSetId,
           let setName = appState.ruleSets.first(where: { $0.id == activeId })?.name,
           appState.pomodoroStatus == .focus {
            column.addArrangedSubview(makeActiveRuleSetBadge(name: setName))
        }

        return column
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
        scrollView.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let selectedId = selectedRuleSetIdForPomodoro(appState)
        for set in appState.ruleSets {
            let isSelected = selectedId == set.id
            let button = makeRuleSetRowButton(
                set: set,
                isSelected: isSelected
            ) { [weak appState] in
                guard let appState, !appState.isStrictActive else { return }
                appState.activeRuleSetId = set.id
            }
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

        let skipButton = makeAppKitPrimaryButton(title: "Skip", color: accentColor)
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

    private func makeSidebarPresetSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel("PRESETS"))

        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 6

        for (focus, breakTime, label) in [(25.0, 5.0, "25/5"), (45.0, 15.0, "45/15"), (50.0, 10.0, "50/10"), (90.0, 20.0, "90/20")] {
            let button = makePomodoroChipButton(
                title: label,
                isSelected: appState.pomodoroFocusDuration == focus && appState.pomodoroBreakDuration == breakTime,
                color: accentColor,
                width: 50
            ) { [weak appState] in
                appState?.pomodoroFocusDuration = focus
                appState?.pomodoroBreakDuration = breakTime
            }
            buttons.addArrangedSubview(button)
        }

        stack.addArrangedSubview(buttons)
        return stack
    }

    private func makeSidebarQuickBreakSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel("QUICK BREAK"))

        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 6

        for minutes in [5, 15, 30] {
            let button = makePomodoroChipButton(
                title: "\(minutes)m",
                isSelected: false,
                color: .secondaryLabelColor,
                width: 50
            ) { [weak appState] in
                appState?.startPause(minutes: Double(minutes))
            }
            button.isEnabled = appState.isBlocking && !appState.isStrictActive
            buttons.addArrangedSubview(button)
        }

        let customButton = makePomodoroChipButton(
            title: "Cust",
            isSelected: false,
            color: .secondaryLabelColor,
            width: 50
        ) { [weak self] in
            self?.presentCustomBreakPrompt()
        }
        customButton.isEnabled = appState.isBlocking && !appState.isStrictActive
        buttons.addArrangedSubview(customButton)

        stack.addArrangedSubview(buttons)
        return stack
    }

    private func makeDurationDialColumn(
        title: String,
        iconName: String,
        duration: Double,
        maxMinutes: Int,
        onCommit: @escaping (Double) -> Void
    ) -> NSView {
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 16

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .black)
        titleLabel.textColor = .secondaryLabelColor

        let dial = PomodoroDurationDialView(
            title: title,
            durationMinutes: duration,
            maxMinutes: Double(maxMinutes),
            iconName: iconName,
            color: title == "FOCUS" ? accentColor : .systemOrange,
            onInteractionDidBegin: onDialInteractionDidBegin,
            onInteractionDidEnd: onDialInteractionDidEnd,
            onCommit: onCommit
        )
        dial.widthAnchor.constraint(equalToConstant: 240).isActive = true
        dial.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 20

        let minimumValue = 5.0
        controls.addArrangedSubview(
            makeDialAdjustmentButton(
                symbolName: "minus.circle.fill",
                isEnabled: duration > minimumValue,
                action: { onCommit(max(minimumValue, duration - 5)) }
            )
        )
        controls.addArrangedSubview(
            makeDialAdjustmentButton(
                symbolName: "plus.circle.fill",
                isEnabled: duration < Double(maxMinutes),
                action: { onCommit(min(Double(maxMinutes), duration + 5)) }
            )
        )

        column.addArrangedSubview(titleLabel)
        column.addArrangedSubview(dial)
        column.addArrangedSubview(controls)
        return column
    }

    private func makePomodoroChipButton(
        title: String,
        isSelected: Bool,
        color: NSColor,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> ActionButton {
        let button = ActionButton(title: title)
        button.isBordered = false
        button.layer?.cornerRadius = 6
        button.setGradientBackground(
            colors: isSelected
                ? [color.withAlphaComponent(0.20), color.withAlphaComponent(0.12)]
                : [
                    NSColor.labelColor.withAlphaComponent(0.08),
                    NSColor.labelColor.withAlphaComponent(0.04),
                ],
            borderColor: isSelected
                ? color.withAlphaComponent(0.24)
                : NSColor.separatorColor.withAlphaComponent(0.18)
        )
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: isSelected ? color : NSColor.secondaryLabelColor,
            ]
        )
        button.onAction = action
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    private func makeDialAdjustmentButton(
        symbolName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> ActionButton {
        let button = ActionButton()
        button.isBordered = false
        button.layer?.cornerRadius = 11
        button.layer?.masksToBounds = true
        button.setGradientBackground(
            colors: isEnabled
                ? [
                    NSColor.labelColor.withAlphaComponent(0.12),
                    NSColor.labelColor.withAlphaComponent(0.07),
                ]
                : [
                    NSColor.labelColor.withAlphaComponent(0.06),
                    NSColor.labelColor.withAlphaComponent(0.03),
                ],
            borderColor: isEnabled
                ? NSColor.separatorColor.withAlphaComponent(0.22)
                : NSColor.separatorColor.withAlphaComponent(0.12)
        )
        button.image = appKitSymbolImage(
            named: symbolName.hasPrefix("minus") ? "minus" : "plus",
            pointSize: 11,
            weight: .bold,
            color: isEnabled
                ? .secondaryLabelColor
                : .secondaryLabelColor.withAlphaComponent(0.45)
        )
        button.imagePosition = .imageOnly
        button.contentTintColor = isEnabled
            ? .secondaryLabelColor
            : .secondaryLabelColor.withAlphaComponent(0.45)
        button.onAction = action
        button.isEnabled = isEnabled
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    private func makeActiveRuleSetBadge(name: String) -> NSView {
        let container = AppKitFlippedView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        container.layer?.cornerRadius = 999

        let iconView = NSImageView()
        iconView.image = appKitSymbolImage(
            named: "link",
            pointSize: 11,
            weight: .regular,
            color: .secondaryLabelColor
        )

        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [iconView, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        return container
    }

    private func makeRuleSetRowButton(
        set: RuleSet,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> ActionButton {
        makeSelectableRuleSetRowButton(
            title: set.name,
            isSelected: isSelected,
            accentColor: accentColor,
            action: action
        )
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
