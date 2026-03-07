import AppKit

final class FocusPomodoroWidgetView: AppKitCardView {
    private static let stableMainStatusHeight: CGFloat = 320
    private static let stableMainStatusWidth: CGFloat = 560

    private enum RenderMode: Equatable {
        case idle
        case focusActive
        case breakActive
    }

    private let appState: AppState
    private let accentColor: NSColor
    private let onDialInteractionDidBegin: (() -> Void)?
    private let onDialInteractionDidEnd: (() -> Void)?
    private var renderMode: RenderMode?
    private var mainStatusContainer: AppKitFlippedView?
    private var currentMainStatusView: NSView?
    private var actionContainer: AppKitFlippedView?
    private var currentActionView: NSView?
    private var ruleSetButtons: [UUID: AppKitSelectableRowButton] = [:]
    private var presetButtons: [(focus: Double, breakTime: Double, button: AppKitPillButton)] = []
    private var quickBreakButtons: [AppKitPillButton] = []
    private var customBreakButton: AppKitPillButton?
    private var focusDialView: PomodoroDurationDialView?
    private var breakDialView: PomodoroDurationDialView?
    private var focusMinusButton: ActionButton?
    private var focusPlusButton: ActionButton?
    private var breakMinusButton: ActionButton?
    private var breakPlusButton: ActionButton?
    private var phaseLabel: NSTextField?
    private var progressDialView: PomodoroProgressDialView?
    private var activeRuleSetBadgeLabel: NSTextField?
    private var skipButton: ActionButton?
    private(set) var refreshGeneration = 0

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

        rebuildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshForStateChange() {
        updateForStateChange()
    }

    private func rebuildContent() {
        removeAllArrangedSubviews(from: contentStack)
        renderMode = currentRenderMode()
        mainStatusContainer = nil
        currentMainStatusView = nil
        actionContainer = nil
        currentActionView = nil
        ruleSetButtons = [:]
        presetButtons = []
        quickBreakButtons = []
        customBreakButton = nil
        focusDialView = nil
        breakDialView = nil
        focusMinusButton = nil
        focusPlusButton = nil
        breakMinusButton = nil
        breakPlusButton = nil
        phaseLabel = nil
        progressDialView = nil
        activeRuleSetBadgeLabel = nil
        skipButton = nil
        contentStack.spacing = 12
        contentStack.addArrangedSubview(FocusPomodoroWidgetLayoutBuilder.makePomodoroHeader())
        let topContentSection = makeTopContentSection()
        contentStack.addArrangedSubview(topContentSection)
        topContentSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        if !appState.ruleSets.isEmpty {
            let ruleSetSection = makeRuleSetSection()
            contentStack.addArrangedSubview(ruleSetSection)
            ruleSetSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            contentStack.setCustomSpacing(20, after: topContentSection)
        }

        let actionContainer = AppKitFlippedView()
        actionContainer.translatesAutoresizingMaskIntoConstraints = false
        self.actionContainer = actionContainer
        contentStack.addArrangedSubview(actionContainer)
        actionContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        replaceActionView(with: makeActionButtons())

        refreshGeneration += 1
    }

    func updateForStateChange() {
        let desiredMode = currentRenderMode()
        let currentRuleSetIds = Set(ruleSetButtons.keys)
        let desiredRuleSetIds = Set(appState.ruleSets.map(\.id))

        guard currentRuleSetIds == desiredRuleSetIds else {
            rebuildContent()
            return
        }

        if renderMode != desiredMode {
            renderMode = desiredMode
            replaceMainStatusView(with: makeMainStatusSection())
            replaceActionView(with: makeActionButtons())
        }

        switch desiredMode {
        case .idle:
            updateIdleControls()
        case .focusActive, .breakActive:
            updateActiveControls()
        }
    }

    func updateRuleSetSelection() {
        let selectedId = FocusPomodoroWidgetSupport.selectedRuleSetId(appState)
        for set in appState.ruleSets {
            guard let button = ruleSetButtons[set.id] else { continue }
            button.accentColor = accentColor
            button.applySelectionState(selectedId == set.id)
            button.isEnabled = !appState.isStrictActive
        }
    }

    private func currentRenderMode() -> RenderMode {
        switch appState.pomodoroStatus {
        case .none:
            return .idle
        case .focus:
            return .focusActive
        case .breakTime:
            return .breakActive
        }
    }

    private func replaceMainStatusView(with view: NSView) {
        guard let mainStatusContainer else { return }

        currentMainStatusView?.removeFromSuperview()
        currentMainStatusView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        mainStatusContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: mainStatusContainer.centerXAnchor),
            view.topAnchor.constraint(equalTo: mainStatusContainer.topAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: mainStatusContainer.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: mainStatusContainer.trailingAnchor),
            view.bottomAnchor.constraint(lessThanOrEqualTo: mainStatusContainer.bottomAnchor),
        ])
    }

    private func replaceActionView(with view: NSView) {
        guard let actionContainer else { return }

        currentActionView?.removeFromSuperview()
        currentActionView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        actionContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: actionContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor),
        ])
    }

    private func updateIdleControls() {
        presetButtons.forEach { $0.button.isEnabled = true }
        focusDialView?.setDurationMinutes(appState.pomodoroFocusDuration)
        breakDialView?.setDurationMinutes(appState.pomodoroBreakDuration)

        for preset in presetButtons {
            preset.button.selectedColor = accentColor
            preset.button.applySelectionState(
                appState.pomodoroFocusDuration == preset.focus
                    && appState.pomodoroBreakDuration == preset.breakTime
            )
        }

        let quickBreakEnabled = appState.isBlocking && !appState.isStrictActive
        quickBreakButtons.forEach { $0.isEnabled = quickBreakEnabled }
        customBreakButton?.isEnabled = quickBreakEnabled

        focusMinusButton?.isEnabled = appState.pomodoroFocusDuration > 5
        focusPlusButton?.isEnabled = appState.pomodoroFocusDuration < 120
        breakMinusButton?.isEnabled = appState.pomodoroBreakDuration > 5
        breakPlusButton?.isEnabled = appState.pomodoroBreakDuration < 60

        updateRuleSetSelection()
    }

    private func updateActiveControls() {
        presetButtons.forEach { $0.button.isEnabled = false }
        let isFocus = appState.pomodoroStatus == .focus
        phaseLabel?.stringValue = isFocus ? "FOCUSING" : "BREAKING"

        let totalDurationSeconds =
            isFocus
            ? appState.pomodoroFocusDuration * 60
            : appState.pomodoroBreakDuration * 60
        let progress =
            totalDurationSeconds > 0
            ? 1 - (appState.pomodoroRemaining / totalDurationSeconds)
            : 0
        progressDialView?.update(
            progress: progress,
            iconName: isFocus ? AppKitUISymbols.Name.focus : AppKitUISymbols.Name.breakCup,
            color: isFocus ? accentColor : .systemOrange,
            centerText: appState.timeString(time: appState.pomodoroRemaining)
        )
        skipButton?.isEnabled = !appState.isPomodoroLocked

        if isFocus {
            let currentSetName = appState.ruleSets.first(where: { $0.id == appState.currentPrimaryRuleSetId })?.name
            if let currentSetName {
                if let activeRuleSetBadgeLabel {
                    activeRuleSetBadgeLabel.stringValue = currentSetName
                } else {
                    replaceMainStatusView(with: makeMainStatusSection())
                }
            } else if activeRuleSetBadgeLabel != nil {
                replaceMainStatusView(with: makeMainStatusSection())
            }
        } else if activeRuleSetBadgeLabel != nil {
            replaceMainStatusView(with: makeMainStatusSection())
        }
    }

    private func makeTopContentSection() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 20

        let sidebar = makeSidebarSection()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let mainContainer = AppKitFlippedView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.heightAnchor.constraint(equalToConstant: Self.stableMainStatusHeight).isActive = true
        mainContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.stableMainStatusWidth).isActive = true
        self.mainStatusContainer = mainContainer

        row.addArrangedSubview(sidebar)
        row.addArrangedSubview(mainContainer)
        replaceMainStatusView(with: makeMainStatusSection())
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
                iconName: AppKitUISymbols.Name.focus,
                duration: appState.pomodoroFocusDuration,
                maxMinutes: 120
            ) { [weak appState] minutes in
                guard let appState else { return }
                appState.pomodoroFocusDuration = minutes
            }
            let breakColumn = makeDurationDialColumn(
                title: "BREAK",
                iconName: AppKitUISymbols.Name.breakCup,
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
        self.phaseLabel = phaseLabel

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
            iconName: appState.pomodoroStatus == .focus ? AppKitUISymbols.Name.focus : AppKitUISymbols.Name.breakCup,
            color: appState.pomodoroStatus == .focus ? accentColor : .systemOrange,
            centerText: appState.timeString(time: appState.pomodoroRemaining)
        )
        self.progressDialView = progressView
        progressView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        progressView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        column.addArrangedSubview(phaseLabel)
        column.addArrangedSubview(progressView)

        if let activeId = appState.currentPrimaryRuleSetId,
           let setName = appState.ruleSets.first(where: { $0.id == activeId })?.name,
           appState.pomodoroStatus == .focus {
            let badge = FocusPomodoroWidgetLayoutBuilder.makeActiveRuleSetBadge(name: setName)
            if let label = badge.subviews.compactMap({ FocusPomodoroWidgetSupport.firstLabel(in: $0) }).first {
                activeRuleSetBadgeLabel = label
            }
            column.addArrangedSubview(badge)
        }

        return column
    }

    private func makeRuleSetSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        container.addArrangedSubview(makeAppKitSectionLabel("SELECT LIST"))

        let scrollView = VerticalStackScrollContainer(
            contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        )
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let selectedId = FocusPomodoroWidgetSupport.selectedRuleSetId(appState)
        for set in appState.ruleSets {
            let isSelected = selectedId == set.id
            let button = FocusPomodoroWidgetLayoutBuilder.makeRuleSetRowButton(
                set: set,
                isSelected: isSelected,
                accentColor: accentColor
            ) { [weak appState] in
                guard let appState, !appState.isStrictActive else { return }
                appState.selectActiveRuleSet(set.id)
            }
            ruleSetButtons[set.id] = button
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
        self.skipButton = skipButton

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
        stack.addArrangedSubview(makeAppKitSectionLabel("PRESETS"))

        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 6

        for (focus, breakTime, label) in FocusPomodoroWidgetSupport.sidebarPresets {
            let button = makeAppKitPillButton(
                title: label,
                isSelected: appState.pomodoroFocusDuration == focus && appState.pomodoroBreakDuration == breakTime,
                selectedColor: accentColor,
                width: 50
            ) { [weak appState] in
                guard let appState, appState.pomodoroStatus == .none else { return }
                appState.pomodoroFocusDuration = focus
                appState.pomodoroBreakDuration = breakTime
            }
            button.isEnabled = appState.pomodoroStatus == .none
            presetButtons.append((focus: focus, breakTime: breakTime, button: button))
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
        stack.addArrangedSubview(makeAppKitSectionLabel("QUICK BREAK"))

        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 6

        for minutes in [5, 15, 30] {
            let button = makeAppKitPillButton(
                title: "\(minutes)m",
                isSelected: false,
                selectedColor: .secondaryLabelColor,
                width: 50
            ) { [weak appState] in
                appState?.startPause(minutes: Double(minutes))
            }
            button.isEnabled = appState.isBlocking && !appState.isStrictActive
            quickBreakButtons.append(button)
            buttons.addArrangedSubview(button)
        }

        let customButton = makeAppKitPillButton(
            title: "Cust",
            isSelected: false,
            selectedColor: .secondaryLabelColor,
            width: 50
        ) { [weak self] in
            self?.presentCustomBreakPrompt()
        }
        customButton.isEnabled = appState.isBlocking && !appState.isStrictActive
        customBreakButton = customButton
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
        let currentDuration: () -> Double = { [weak self] in
            guard let self else { return duration }
            return title == "FOCUS"
                ? self.appState.pomodoroFocusDuration
                : self.appState.pomodoroBreakDuration
        }
        let minusButton = FocusPomodoroWidgetLayoutBuilder.makeDialAdjustmentButton(
            symbol: "-",
            isEnabled: duration > minimumValue,
            action: { onCommit(max(minimumValue, currentDuration() - 5)) }
        )
        let plusButton = FocusPomodoroWidgetLayoutBuilder.makeDialAdjustmentButton(
            symbol: "+",
            isEnabled: duration < Double(maxMinutes),
            action: { onCommit(min(Double(maxMinutes), currentDuration() + 5)) }
        )
        controls.addArrangedSubview(minusButton)
        controls.addArrangedSubview(plusButton)

        if title == "FOCUS" {
            focusDialView = dial
            focusMinusButton = minusButton
            focusPlusButton = plusButton
        } else {
            breakDialView = dial
            breakMinusButton = minusButton
            breakPlusButton = plusButton
        }

        column.addArrangedSubview(titleLabel)
        column.addArrangedSubview(dial)
        column.addArrangedSubview(controls)
        return column
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
