import AppKit
import Combine

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

private func removeAllArrangedSubviews(from stackView: NSStackView) {
    let subviews = stackView.arrangedSubviews
    subviews.forEach { subview in
        stackView.removeArrangedSubview(subview)
        subview.removeFromSuperview()
    }
}

private func makeDivider() -> NSView {
    makeAppKitDividerView(color: .separatorColor)
}

final class VerticalStackScrollContainer: NSScrollView {
    private let documentContainer = FlippedContentView()
    let stackView = NSStackView()
    private let stackInsets: NSEdgeInsets

    init(contentInsets: NSEdgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)) {
        self.stackInsets = contentInsets
        super.init(frame: .zero)

        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        autohidesScrollers = true

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12

        documentView = documentContainer
        documentContainer.addSubview(stackView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let width = max(contentSize.width, 1)
        let stackWidth = max(width - stackInsets.left - stackInsets.right, 1)
        let fittingSize = stackView.fittingSize
        let stackHeight = max(fittingSize.height, 1)

        documentContainer.frame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: max(
                stackHeight + stackInsets.top + stackInsets.bottom,
                contentSize.height
            )
        )
        stackView.frame = CGRect(
            x: stackInsets.left,
            y: stackInsets.top,
            width: stackWidth,
            height: stackHeight
        )
    }

    var usesFlippedDocumentCoordinatesForTesting: Bool {
        documentContainer.isFlipped
    }
}

final class FocusSectionViewController: NSViewController {
    private struct PomodoroWidgetSignature: Equatable {
        struct RuleSetSnapshot: Equatable {
            let id: UUID
            let name: String
        }

        let accentColorIndex: Int
        let isBlocking: Bool
        let isStrictActive: Bool
        let pomodoroStatus: AppState.PomodoroStatus
        let pomodoroFocusDuration: Double
        let pomodoroBreakDuration: Double
        let pomodoroRemaining: TimeInterval
        let isPomodoroLocked: Bool
        let activeRuleSetId: UUID?
        let currentPrimaryRuleSetId: UUID?
        let ruleSets: [RuleSetSnapshot]

        init(appState: AppState) {
            accentColorIndex = appState.accentColorIndex
            isBlocking = appState.isBlocking
            isStrictActive = appState.isStrictActive
            pomodoroStatus = appState.pomodoroStatus
            pomodoroFocusDuration = appState.pomodoroFocusDuration
            pomodoroBreakDuration = appState.pomodoroBreakDuration
            pomodoroRemaining = appState.pomodoroRemaining
            isPomodoroLocked = appState.isPomodoroLocked
            activeRuleSetId = appState.activeRuleSetId
            currentPrimaryRuleSetId = appState.currentPrimaryRuleSetId
            ruleSets = appState.ruleSets.map { RuleSetSnapshot(id: $0.id, name: $0.name) }
        }
    }

    private let appState: AppState
    private let shellState: FreeShellState
    var section: FocusContentSection {
        didSet { reloadContent() }
    }

    private let scrollContainer = VerticalStackScrollContainer()
    private let permissionWarningView = NSView()
    private let permissionTitleLabel = NSTextField(labelWithString: "Accessibility Permission Needed")
    private let grantPermissionButton = NSButton(title: "Grant", target: nil, action: nil)
    private let headerCardView = NSView()
    private let headerIconView = NSImageView()
    private let headerTitleLabel = NSTextField(labelWithString: "Focus Mode")
    private let headerStatusLabel = NSTextField(labelWithString: "")
    private let unblockableWarningLabel = NSTextField(labelWithString: "Unblockable mode is active. You cannot disable Focus Mode.")
    private let pauseDashboardView = NSView()
    private let pauseTitleLabel = NSTextField(labelWithString: "On Break")
    private let pauseTimeLabel = NSTextField(labelWithString: "")
    private let pauseEndButton = NSButton(title: "End Break & Focus", target: nil, action: nil)
    private let overviewCardView = NSView()
    private let overviewTitleLabel = NSTextField(labelWithString: "Live Overview")
    private let overviewRowsStack = NSStackView()
    private let widgetContainer = NSView()

    private var widgetView: NSView?
    private var cancellables: Set<AnyCancellable> = []
    private var pomodoroWidgetInteractionDepth = 0
    private var needsReloadAfterPomodoroInteraction = false
    private var pomodoroWidgetSignature: PomodoroWidgetSignature?

    init(appState: AppState, shellState: FreeShellState, section: FocusContentSection) {
        self.appState = appState
        self.shellState = shellState
        self.section = section
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollContainer)
        NSLayoutConstraint.activate([
            scrollContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollContainer.topAnchor.constraint(equalTo: view.topAnchor),
            scrollContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configurePermissionWarning()
        configureHeaderCard()
        configurePauseDashboard()
        configureOverview()
        configureWidgetContainer()

        let stack = scrollContainer.stackView
        [permissionWarningView, headerCardView, unblockableWarningLabel, pauseDashboardView, overviewCardView, widgetContainer].forEach {
            stack.addArrangedSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleObservedAppStateChange()
            }
            .store(in: &cancellables)

        reloadContent()
    }

    private func handleObservedAppStateChange() {
        guard !(section == .pomodoro && pomodoroWidgetInteractionDepth > 0) else {
            needsReloadAfterPomodoroInteraction = true
            return
        }
        reloadContent()
    }

    private func beginPomodoroWidgetInteraction() {
        pomodoroWidgetInteractionDepth += 1
    }

    private func endPomodoroWidgetInteraction() {
        guard pomodoroWidgetInteractionDepth > 0 else { return }
        pomodoroWidgetInteractionDepth -= 1

        guard pomodoroWidgetInteractionDepth == 0 else { return }
        guard needsReloadAfterPomodoroInteraction else { return }

        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }

    private func configurePermissionWarning() {
        permissionWarningView.wantsLayer = true
        permissionWarningView.layer?.backgroundColor = NSColor.systemRed.cgColor
        permissionWarningView.layer?.cornerRadius = 12

        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .white

        permissionTitleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        permissionTitleLabel.textColor = .white

        grantPermissionButton.isBordered = false
        grantPermissionButton.wantsLayer = true
        grantPermissionButton.layer?.cornerRadius = 8
        grantPermissionButton.layer?.backgroundColor = NSColor.white.cgColor
        grantPermissionButton.contentTintColor = .black
        grantPermissionButton.font = .systemFont(ofSize: 12, weight: .semibold)
        grantPermissionButton.target = self
        grantPermissionButton.action = #selector(grantAccessibility)

        let row = NSStackView(views: [icon, permissionTitleLabel, NSView(), grantPermissionButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false

        permissionWarningView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: permissionWarningView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: permissionWarningView.trailingAnchor),
            row.topAnchor.constraint(equalTo: permissionWarningView.topAnchor),
            row.bottomAnchor.constraint(equalTo: permissionWarningView.bottomAnchor),
        ])
    }

    private func configureHeaderCard() {
        headerCardView.wantsLayer = true
        headerCardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        headerCardView.layer?.cornerRadius = 12

        headerIconView.imageScaling = .scaleProportionallyUpOrDown
        headerIconView.symbolConfiguration = .init(pointSize: 30, weight: .regular)

        headerTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        headerStatusLabel.font = .systemFont(ofSize: 13)
        headerStatusLabel.textColor = .secondaryLabelColor

        let labelStack = NSStackView(views: [headerTitleLabel, headerStatusLabel])
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 4

        let row = NSStackView(views: [headerIconView, labelStack, NSView()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false

        headerCardView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: headerCardView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: headerCardView.trailingAnchor),
            row.topAnchor.constraint(equalTo: headerCardView.topAnchor),
            row.bottomAnchor.constraint(equalTo: headerCardView.bottomAnchor),
        ])
    }

    private func configurePauseDashboard() {
        pauseDashboardView.wantsLayer = true
        pauseDashboardView.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        pauseDashboardView.layer?.cornerRadius = 12
        pauseDashboardView.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.3).cgColor
        pauseDashboardView.layer?.borderWidth = 1

        pauseTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        pauseTitleLabel.textColor = .secondaryLabelColor

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        pauseTimeLabel.textColor = .systemOrange
        pauseTimeLabel.alignment = .center

        pauseEndButton.bezelStyle = .rounded
        pauseEndButton.contentTintColor = .systemGreen
        pauseEndButton.target = self
        pauseEndButton.action = #selector(cancelPause)

        let stack = NSStackView(views: [pauseTitleLabel, pauseTimeLabel, pauseEndButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        pauseDashboardView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pauseDashboardView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: pauseDashboardView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: pauseDashboardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: pauseDashboardView.bottomAnchor),
        ])
    }

    private func configureOverview() {
        overviewCardView.wantsLayer = true
        overviewCardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        overviewCardView.layer?.cornerRadius = 12

        overviewTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        overviewRowsStack.orientation = .vertical
        overviewRowsStack.alignment = .leading
        overviewRowsStack.spacing = 10

        let stack = NSStackView(views: [overviewTitleLabel, overviewRowsStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        overviewCardView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: overviewCardView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: overviewCardView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: overviewCardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: overviewCardView.bottomAnchor),
        ])
    }

    private func configureWidgetContainer() {
        widgetContainer.translatesAutoresizingMaskIntoConstraints = false
    }

    private func reloadContent() {
        permissionWarningView.isHidden = appState.isTrusted

        let headerIconName = "leaf.fill"
        headerIconView.image = NSImage(
            systemSymbolName: headerIconName,
            accessibilityDescription: nil
        )
        headerIconView.contentTintColor = FocusSectionSupport.focusIconColor(
            isBlocking: appState.isBlocking,
            isPaused: appState.isPaused
        )
        headerStatusLabel.stringValue = headerStatusText()

        unblockableWarningLabel.font = .systemFont(ofSize: 12)
        unblockableWarningLabel.textColor = .systemOrange
        unblockableWarningLabel.isHidden = !FocusSectionSupport.shouldShowUnblockableWarning(
            isBlocking: appState.isBlocking,
            isUnblockable: appState.isUnblockable
        )

        pauseDashboardView.isHidden = !FocusSectionSupport.shouldShowPauseDashboard(
            isBlocking: appState.isBlocking,
            isPaused: appState.isPaused
        )
        pauseTimeLabel.stringValue = appState.timeString(time: appState.pauseRemaining)

        overviewCardView.isHidden = section != .all
        reloadOverviewRows()
        reloadWidget()
        scrollContainer.needsLayout = true
    }

    private func headerStatusText() -> String {
        let status = FocusSectionSupport.statusLabel(
            isBlocking: appState.isBlocking,
            isPaused: appState.isPaused
        )
        guard FocusSectionSupport.shouldShowRuleSetName(
            isBlocking: appState.isBlocking,
            isPaused: appState.isPaused
        ) else {
            return status
        }
        return "\(status) • \(appState.currentPrimaryRuleSetName)"
    }

    private func reloadOverviewRows() {
        removeAllArrangedSubviews(from: overviewRowsStack)

        let activeScheduleNames = appState.schedules
            .filter { $0.type == .focus && $0.isActive() }
            .map(\.name)
        let currentRuleSet = appState.ruleSets.first(where: { $0.id == appState.currentPrimaryRuleSetId })

        let shouldShowAllowList = FocusSectionSupport.shouldShowAllowListPreview(
            isBlocking: appState.isBlocking,
            pomodoroStatus: appState.pomodoroStatus,
            hasActiveFocusSchedule: !activeScheduleNames.isEmpty,
            hasCurrentRuleSet: currentRuleSet != nil
        )
        let shouldShowPomodoro = appState.pomodoroStatus != .none
        let shouldShowSchedules = !activeScheduleNames.isEmpty

        if shouldShowSchedules {
            overviewRowsStack.addArrangedSubview(
                makeOverviewRow(
                    iconName: "calendar",
                    title: "Active Schedules",
                    value: activeScheduleNames.joined(separator: ", ")
                )
            )
        }

        if shouldShowAllowList, let currentRuleSet {
            overviewRowsStack.addArrangedSubview(
                makeOverviewRow(
                    iconName: "globe",
                    title: "Allow List",
                    value: "\(currentRuleSet.name) • \(currentRuleSet.urls.count) rules"
                )
            )
        }

        if shouldShowPomodoro {
            overviewRowsStack.addArrangedSubview(
                makeOverviewRow(
                    iconName: "timer",
                    title: "Pomodoro",
                    value: "\(FocusSectionSupport.pomodoroPhaseLabel(status: appState.pomodoroStatus)) • \(appState.timeString(time: appState.pomodoroRemaining))"
                )
            )
        }

        if !shouldShowSchedules && !shouldShowAllowList && !shouldShowPomodoro {
            let emptyLabel = NSTextField(labelWithString: "No active schedule, allow list, or pomodoro session.")
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            overviewRowsStack.addArrangedSubview(emptyLabel)
        }
    }

    private func makeOverviewRow(iconName: String, title: String, value: String) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: iconName, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = FocusColor.nsColor(for: appState.accentColorIndex)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail

        let row = NSStackView(views: [icon, titleLabel, NSView(), valueLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: max(scrollContainer.stackView.bounds.width, 1)).isActive = true
        return row
    }

    private func reloadWidget() {
        if section == .pomodoro,
           let widgetView,
           let pomodoroWidgetView = widgetView as? FocusPomodoroWidgetView
        {
            let nextSignature = PomodoroWidgetSignature(appState: appState)
            if pomodoroWidgetSignature == nextSignature {
                widgetContainer.isHidden = false
                pomodoroWidgetView.needsLayout = true
                return
            }
            pomodoroWidgetSignature = nextSignature
        } else if section != .pomodoro {
            pomodoroWidgetSignature = nil
        }

        widgetView?.removeFromSuperview()
        widgetView = nil
        widgetContainer.isHidden = section == .all

        let nextWidgetView: NSView
        switch section {
        case .pomodoro:
            pomodoroWidgetSignature = PomodoroWidgetSignature(appState: appState)
            nextWidgetView = FocusPomodoroWidgetView(
                appState: appState,
                onDialInteractionDidBegin: { [weak self] in
                    self?.beginPomodoroWidgetInteraction()
                },
                onDialInteractionDidEnd: { [weak self] in
                    self?.endPomodoroWidgetInteraction()
                }
            )
        case .schedules:
            nextWidgetView = FocusSchedulesWidgetView(appState: appState, shellState: shellState)
        case .allowedWebsites:
            nextWidgetView = FocusAllowedWebsitesWidgetView(appState: appState, shellState: shellState)
        case .all:
            pomodoroWidgetSignature = nil
            return
        }

        nextWidgetView.translatesAutoresizingMaskIntoConstraints = false
        widgetContainer.addSubview(nextWidgetView)
        NSLayoutConstraint.activate([
            nextWidgetView.leadingAnchor.constraint(equalTo: widgetContainer.leadingAnchor),
            nextWidgetView.trailingAnchor.constraint(equalTo: widgetContainer.trailingAnchor),
            nextWidgetView.topAnchor.constraint(equalTo: widgetContainer.topAnchor),
            nextWidgetView.bottomAnchor.constraint(equalTo: widgetContainer.bottomAnchor),
        ])
        widgetView = nextWidgetView
    }

    @objc
    private func grantAccessibility() {
        FocusSectionSupport.makeGrantAccessibilityAction()()
    }

    @objc
    private func cancelPause() {
        appState.cancelPause()
    }
}

extension FocusSectionViewController {
    var headerStatusTextForTesting: String { headerStatusLabel.stringValue }
    var isPermissionWarningHiddenForTesting: Bool { permissionWarningView.isHidden }
    var isUnblockableWarningHiddenForTesting: Bool { unblockableWarningLabel.isHidden }
    var isPauseDashboardHiddenForTesting: Bool { pauseDashboardView.isHidden }
    var pauseTimeTextForTesting: String { pauseTimeLabel.stringValue }
    var currentWidgetViewTypeForTesting: String? {
        widgetView.map { String(describing: type(of: $0)) }
    }
    var widgetViewIdentifierForTesting: ObjectIdentifier? {
        widgetView.map(ObjectIdentifier.init)
    }
    var hasDeferredPomodoroReloadForTesting: Bool {
        needsReloadAfterPomodoroInteraction
    }
    func beginPomodoroWidgetInteractionForTesting() {
        beginPomodoroWidgetInteraction()
    }
    func endPomodoroWidgetInteractionForTesting() {
        endPomodoroWidgetInteraction()
    }
    func simulateObservedAppStateChangeForTesting() {
        handleObservedAppStateChange()
    }
}

final class SettingsSectionViewController: NSViewController {
    private let appState: AppState
    private let scrollContainer = VerticalStackScrollContainer()
    private var cancellables: Set<AnyCancellable> = []

    private let strictSection = NSStackView()
    private let strictToggle = NSSwitch()
    private let strictDescriptionLabel = NSTextField(labelWithString: "When active, you cannot disable Focus Mode.")
    private let strictDisableButton = NSButton(title: "Disable...", target: nil, action: nil)
    private let strictStatusLabel = NSTextField(labelWithString: "Active and Locking Focus Mode.")
    private let weekStartsMondaySwitch = NSSwitch()
    private let calendarIntegrationSwitch = NSSwitch()
    private let calendarImportsSwitch = NSSwitch()
    private let resyncButton = NSButton(title: "Resync Imported Schedules", target: nil, action: nil)
    private let launchAtLoginSwitch = NSSwitch()
    private let blockNewTabsSwitch = NSSwitch()
    private let blockDeveloperHostsSwitch = NSSwitch()
    private let blockLocalNetworkHostsSwitch = NSSwitch()
    private let appearanceControl = NSSegmentedControl(labels: ["System", "Light", "Dark"], trackingMode: .selectOne, target: nil, action: nil)
    private var accentButtons: [NSButton] = []

    init(appState: AppState) {
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollContainer)
        NSLayoutConstraint.activate([
            scrollContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollContainer.topAnchor.constraint(equalTo: view.topAnchor),
            scrollContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        scrollContainer.stackView.addArrangedSubview(titleLabel)

        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("Strict Mode"))
        addFullWidthSection(makeStrictSection())
        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("Calendar"))
        addFullWidthSection(makeCalendarSection())
        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("Startup"))
        addFullWidthSection(makeStartupSection())
        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("Browser"))
        addFullWidthSection(makeBrowserSection())
        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("Appearance"))
        addFullWidthSection(makeAppearanceSection())
        scrollContainer.stackView.addArrangedSubview(makeSectionTitle("About"))
        addFullWidthSection(makeAboutSection())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSettings()
            }
            .store(in: &cancellables)

        reloadSettings()
    }

    private func makeSectionTitle(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        return label
    }

    private func addFullWidthSection(_ section: NSView) {
        scrollContainer.stackView.addArrangedSubview(section)
        section.translatesAutoresizingMaskIntoConstraints = false
        section.widthAnchor.constraint(equalTo: scrollContainer.stackView.widthAnchor).isActive = true
    }

    private func makeStrictSection() -> NSView {
        strictSection.orientation = .vertical
        strictSection.alignment = .leading
        strictSection.spacing = 10
        strictSection.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        strictSection.wantsLayer = true
        strictSection.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        strictSection.layer?.cornerRadius = 12

        let toggleRow = makeToggleRow(
            title: "Unblockable Mode",
            descriptionLabel: strictDescriptionLabel,
            toggle: strictToggle
        )
        strictToggle.target = self
        strictToggle.action = #selector(toggleStrictMode)

        strictDisableButton.target = self
        strictDisableButton.action = #selector(disableStrictMode)
        strictDisableButton.bezelStyle = .rounded

        strictStatusLabel.font = .systemFont(ofSize: 12)
        strictStatusLabel.textColor = .systemOrange

        strictSection.addArrangedSubview(toggleRow)
        strictSection.addArrangedSubview(strictStatusLabel)
        strictSection.addArrangedSubview(strictDisableButton)
        return strictSection
    }

    private func makeCalendarSection() -> NSView {
        let section = makeCardSection()
        weekStartsMondaySwitch.target = self
        weekStartsMondaySwitch.action = #selector(toggleWeekStartsMonday)
        calendarIntegrationSwitch.target = self
        calendarIntegrationSwitch.action = #selector(toggleCalendarIntegration)
        calendarImportsSwitch.target = self
        calendarImportsSwitch.action = #selector(toggleCalendarImports)
        resyncButton.target = self
        resyncButton.action = #selector(resyncImportedSchedules)

        [
            makeToggleRow(
                title: "Start week on Monday",
                descriptionLabel: nil,
                toggle: weekStartsMondaySwitch
            ),
            makeToggleRow(
                title: "Enable Calendar Integration",
                descriptionLabel: makeDescriptionLabel("Use macOS Calendar events for scheduling."),
                toggle: calendarIntegrationSwitch
            ),
            makeToggleRow(
                title: "Calendar Imports Block Time",
                descriptionLabel: makeDescriptionLabel("Imported calendar events can act as blocking sessions."),
                toggle: calendarImportsSwitch
            ),
            resyncButton,
        ].forEach { section.addArrangedSubview($0) }
        return section
    }

    private func makeStartupSection() -> NSView {
        let section = makeCardSection()
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(toggleLaunchAtLogin)
        section.addArrangedSubview(
            makeToggleRow(
                title: "Launch at Login",
                descriptionLabel: makeDescriptionLabel("Start Free automatically when you sign in."),
                toggle: launchAtLoginSwitch
            )
        )
        return section
    }

    private func makeBrowserSection() -> NSView {
        let section = makeCardSection()
        blockNewTabsSwitch.target = self
        blockNewTabsSwitch.action = #selector(toggleBlockNewTabs)
        blockDeveloperHostsSwitch.target = self
        blockDeveloperHostsSwitch.action = #selector(toggleBlockDeveloperHosts)
        blockLocalNetworkHostsSwitch.target = self
        blockLocalNetworkHostsSwitch.action = #selector(toggleBlockLocalNetworkHosts)

        [
            makeToggleRow(
                title: "Block New Tabs",
                descriptionLabel: makeDescriptionLabel("When off, blank/new-tab pages are allowed by default."),
                toggle: blockNewTabsSwitch
            ),
            makeToggleRow(
                title: "Block Localhost/Dev Ports",
                descriptionLabel: makeDescriptionLabel("When off, localhost and loopback hosts are allowed."),
                toggle: blockDeveloperHostsSwitch
            ),
            makeToggleRow(
                title: "Block Local Network IPs",
                descriptionLabel: makeDescriptionLabel("When off, private-network IPs are allowed."),
                toggle: blockLocalNetworkHostsSwitch
            ),
        ].forEach { section.addArrangedSubview($0) }
        return section
    }

    private func makeAppearanceSection() -> NSView {
        let section = makeCardSection()
        appearanceControl.target = self
        appearanceControl.action = #selector(changeAppearanceMode)
        section.addArrangedSubview(appearanceControl)

        let colorsRow = NSStackView()
        colorsRow.orientation = .horizontal
        colorsRow.alignment = .centerY
        colorsRow.spacing = 12
        accentButtons = FocusColor.all.enumerated().map { index, color in
            let button = NSButton(title: "", target: self, action: #selector(selectAccentColor(_:)))
            button.tag = index
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 12
            button.layer?.backgroundColor = color.cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 24).isActive = true
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            colorsRow.addArrangedSubview(button)
            return button
        }
        section.addArrangedSubview(colorsRow)
        return section
    }

    private func makeAboutSection() -> NSView {
        let section = makeCardSection()
        let row = NSStackView(views: [
            NSTextField(labelWithString: "Version"),
            NSView(),
            {
                let label = NSTextField(labelWithString: "1.0.0")
                label.textColor = .secondaryLabelColor
                return label
            }()
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        section.addArrangedSubview(row)
        return section
    }

    private func makeCardSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 12
        section.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        section.wantsLayer = true
        section.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        section.layer?.cornerRadius = 12
        return section
    }

    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeToggleRow(
        title: String,
        descriptionLabel: NSTextField?,
        toggle: NSSwitch
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 4
        labelStack.addArrangedSubview(titleLabel)
        if let descriptionLabel {
            labelStack.addArrangedSubview(descriptionLabel)
        }

        let row = NSStackView(views: [labelStack, NSView(), toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        labelStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func reloadSettings() {
        let strictLocked = appState.isBlocking && appState.isUnblockable
        strictToggle.isHidden = strictLocked
        strictDescriptionLabel.isHidden = strictLocked
        strictStatusLabel.isHidden = !strictLocked
        strictDisableButton.isHidden = !strictLocked
        strictToggle.state = appState.isUnblockable ? .on : .off

        weekStartsMondaySwitch.state = appState.weekStartsOnMonday ? .on : .off
        calendarIntegrationSwitch.state = appState.calendarIntegrationEnabled ? .on : .off
        calendarImportsSwitch.state = appState.calendarImportsBlockTime ? .on : .off
        calendarIntegrationSwitch.isEnabled = !appState.isStrictActive
        calendarImportsSwitch.isEnabled = !appState.isStrictActive && appState.calendarIntegrationEnabled
        resyncButton.isEnabled = appState.calendarIntegrationEnabled

        launchAtLoginSwitch.state = appState.launchAtLoginStatus() ? .on : .off
        blockNewTabsSwitch.state = appState.blockNewTabs ? .on : .off
        blockDeveloperHostsSwitch.state = appState.blockDeveloperHosts ? .on : .off
        blockLocalNetworkHostsSwitch.state = appState.blockLocalNetworkHosts ? .on : .off

        let selectedAppearanceIndex: Int
        switch appState.appearanceMode {
        case .system:
            selectedAppearanceIndex = 0
        case .light:
            selectedAppearanceIndex = 1
        case .dark:
            selectedAppearanceIndex = 2
        }
        appearanceControl.selectedSegment = selectedAppearanceIndex

        for (index, button) in accentButtons.enumerated() {
            button.layer?.borderWidth = appState.accentColorIndex == index ? 2 : 0
            button.layer?.borderColor = NSColor.labelColor.cgColor
        }

        scrollContainer.needsLayout = true
    }

    @objc
    private func toggleStrictMode() {
        appState.isUnblockable = strictToggle.state == .on
    }

    @objc
    private func disableStrictMode() {
        let alert = NSAlert()
        alert.messageText = "Emergency Unlock"
        alert.informativeText = "Type the phrase exactly to disable Unblockable Mode:\n\n\"\(AppState.challengePhrase)\""
        let input = NSTextField(string: "")
        input.placeholderString = "Type the phrase exactly"
        input.frame = CGRect(x: 0, y: 0, width: 420, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = appState.disableUnblockableWithChallenge(phrase: input.stringValue)
        }
    }

    @objc
    private func toggleWeekStartsMonday() {
        appState.weekStartsOnMonday = weekStartsMondaySwitch.state == .on
    }

    @objc
    private func toggleCalendarIntegration() {
        appState.calendarIntegrationEnabled = calendarIntegrationSwitch.state == .on
    }

    @objc
    private func toggleCalendarImports() {
        appState.calendarImportsBlockTime = calendarImportsSwitch.state == .on
    }

    @objc
    private func resyncImportedSchedules() {
        appState.resyncImportedCalendarSchedules()
    }

    @objc
    private func toggleLaunchAtLogin() {
        let enabled = launchAtLoginSwitch.state == .on
        if !appState.setLaunchAtLoginEnabled(enabled) {
            launchAtLoginSwitch.state = appState.launchAtLoginStatus() ? .on : .off
        }
    }

    @objc
    private func toggleBlockNewTabs() {
        appState.blockNewTabs = blockNewTabsSwitch.state == .on
    }

    @objc
    private func toggleBlockDeveloperHosts() {
        appState.blockDeveloperHosts = blockDeveloperHostsSwitch.state == .on
    }

    @objc
    private func toggleBlockLocalNetworkHosts() {
        appState.blockLocalNetworkHosts = blockLocalNetworkHostsSwitch.state == .on
    }

    @objc
    private func changeAppearanceMode() {
        switch appearanceControl.selectedSegment {
        case 1:
            appState.appearanceMode = .light
        case 2:
            appState.appearanceMode = .dark
        default:
            appState.appearanceMode = .system
        }
    }

    @objc
    private func selectAccentColor(_ sender: NSButton) {
        appState.accentColorIndex = sender.tag
    }
}

extension SettingsSectionViewController {
    var shouldShowStrictDisableButtonForTesting: Bool { !strictDisableButton.isHidden }
    var calendarControlsLockedForTesting: Bool { !calendarIntegrationSwitch.isEnabled }
    var launchAtLoginEnabledForTesting: Bool { launchAtLoginSwitch.state == .on }

    func selectAccentColorForTesting(index: Int) {
        let button = NSButton()
        button.tag = index
        selectAccentColor(button)
    }

    func disableStrictModeForTesting(phrase: String) {
        _ = appState.disableUnblockableWithChallenge(phrase: phrase)
        reloadSettings()
    }

    func setLaunchAtLoginForTesting(_ enabled: Bool) {
        launchAtLoginSwitch.state = enabled ? .on : .off
        toggleLaunchAtLogin()
    }
}

final class RulesSheetViewController: NSViewController {
    private let appState: AppState
    private var selectedSetId: UUID?
    private var isSidebarVisible = true
    private var isSuggestionsExpanded = false

    private let sidebarContainer = NSView()
    private let sidebarHeader = NSStackView()
    private let sidebarScrollView = VerticalStackScrollContainer(contentInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
    private let mainContainer = NSView()
    private let mainHeader = NSStackView()
    private let mainTitleLabel = NSTextField(labelWithString: "")
    private let toggleSidebarButton = NSButton()
    private let contentScrollView = VerticalStackScrollContainer()
    private let addRuleField = NSTextField(string: "")
    private let addRuleButton = NSButton()
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
        self.selectedSetId = appState.currentPrimaryRuleSetId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        let divider = makeDivider()
        divider.translatesAutoresizingMaskIntoConstraints = false

        [sidebarContainer, divider, mainContainer].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 200),

            divider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: view.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            mainContainer.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContainer.topAnchor.constraint(equalTo: view.topAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureSidebar()
        configureMainContent()
        updateSidebarVisibility()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadContent()
            }
            .store(in: &cancellables)

        appState.refreshCurrentOpenUrls()
        reloadContent()
    }

    private func configureSidebar() {
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "ALLOWED LISTS")
        title.font = .systemFont(ofSize: 11, weight: .bold)
        title.textColor = .secondaryLabelColor

        let addButton = NSButton()
        addButton.isBordered = false
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        addButton.contentTintColor = .controlAccentColor
        addButton.target = self
        addButton.action = #selector(addRuleSet)

        sidebarHeader.orientation = .horizontal
        sidebarHeader.alignment = .centerY
        sidebarHeader.spacing = 8
        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false
        sidebarHeader.addArrangedSubview(title)
        sidebarHeader.addArrangedSubview(NSView())
        sidebarHeader.addArrangedSubview(addButton)
        sidebarContainer.addSubview(sidebarHeader)

        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarScrollView)

        NSLayoutConstraint.activate([
            sidebarHeader.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 16),
            sidebarHeader.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -16),
            sidebarHeader.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 12),

            sidebarScrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScrollView.topAnchor.constraint(equalTo: sidebarHeader.bottomAnchor, constant: 8),
            sidebarScrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])
    }

    private func configureMainContent() {
        mainHeader.orientation = .horizontal
        mainHeader.alignment = .centerY
        mainHeader.spacing = 8
        mainHeader.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(
            toggleSidebarButton,
            symbolName: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible)
        )
        toggleSidebarButton.target = self
        toggleSidebarButton.action = #selector(toggleSidebar)
        mainTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        mainHeader.addArrangedSubview(toggleSidebarButton)
        mainHeader.addArrangedSubview(mainTitleLabel)
        mainHeader.addArrangedSubview(NSView())

        let divider = makeDivider()
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        footer.translatesAutoresizingMaskIntoConstraints = false

        addRuleField.placeholderString = "Add URL to allow..."
        addRuleButton.isBordered = true
        addRuleButton.title = "+"
        addRuleButton.target = self
        addRuleButton.action = #selector(addRule)
        footer.addArrangedSubview(addRuleField)
        footer.addArrangedSubview(addRuleButton)

        [mainHeader, divider, contentScrollView, footer].forEach { mainContainer.addSubview($0) }

        NSLayoutConstraint.activate([
            mainHeader.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 12),
            mainHeader.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -12),
            mainHeader.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            mainHeader.heightAnchor.constraint(equalToConstant: 44),

            divider.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: mainHeader.bottomAnchor),

            contentScrollView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),

            footer.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 16),
            footer.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -16),
            footer.topAnchor.constraint(equalTo: contentScrollView.bottomAnchor, constant: 8),
            footer.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -16),
        ])
    }

    private func configureIconButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbolName: symbolName,
            color: .secondaryLabelColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.05),
            cornerRadius: 12
        )
    }

    private var selectedSet: RuleSet? {
        appState.ruleSets.first(where: { $0.id == selectedSetId })
    }

    private func reloadContent() {
        if selectedSetId == nil || selectedSet == nil {
            selectedSetId = appState.currentPrimaryRuleSetId ?? appState.ruleSets.first?.id
        }

        reloadSidebar()
        reloadRuleContent()
    }

    private func reloadSidebar() {
        removeAllArrangedSubviews(from: sidebarScrollView.stackView)
        for ruleSet in appState.ruleSets {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            row.wantsLayer = true
            row.layer?.cornerRadius = 6
            row.layer?.backgroundColor =
                selectedSetId == ruleSet.id
                ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
                : NSColor.clear.cgColor

            let button = NSButton(title: ruleSet.name, target: self, action: #selector(selectRuleSet(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
            button.isBordered = false
            button.alignment = .left
            button.font = .systemFont(
                ofSize: 13,
                weight: selectedSetId == ruleSet.id ? .semibold : .regular
            )
            button.contentTintColor =
                selectedSetId == ruleSet.id
                ? .labelColor
                : .secondaryLabelColor
            row.addArrangedSubview(button)
            row.addArrangedSubview(NSView())

            if RulesSectionSupport.shouldShowDeleteSetButton(
                ruleSetCount: appState.ruleSets.count,
                isBlocking: appState.isBlocking
            ) {
                let deleteButton = NSButton()
                deleteButton.isBordered = false
                deleteButton.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
                deleteButton.image = appKitSymbolImage(
                    named: "minus.circle.fill",
                    pointSize: 15,
                    weight: .regular,
                    color: .systemRed
                )
                deleteButton.contentTintColor = .systemRed
                deleteButton.target = self
                deleteButton.action = #selector(deleteRuleSet(_:))
                row.addArrangedSubview(deleteButton)
            }

            sidebarScrollView.stackView.addArrangedSubview(row)
        }
        sidebarScrollView.needsLayout = true
    }

    private func reloadRuleContent() {
        removeAllArrangedSubviews(from: contentScrollView.stackView)
        mainTitleLabel.stringValue = selectedSet?.name ?? ""
        toggleSidebarButton.image = appKitSymbolImage(
            named: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible),
            pointSize: 11,
            weight: .semibold,
            color: .secondaryLabelColor
        )

        guard let selectedSet else {
            let emptyLabel = NSTextField(labelWithString: "Select a list to edit")
            emptyLabel.textColor = .secondaryLabelColor
            contentScrollView.stackView.addArrangedSubview(emptyLabel)
            return
        }

        let rulesHeader = NSTextField(labelWithString: "Allowed in this list")
        rulesHeader.font = .systemFont(ofSize: 12, weight: .semibold)
        rulesHeader.textColor = .secondaryLabelColor
        contentScrollView.stackView.addArrangedSubview(rulesHeader)

        if selectedSet.urls.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No rules yet.")
            emptyLabel.textColor = .secondaryLabelColor
            contentScrollView.stackView.addArrangedSubview(emptyLabel)
        } else {
            for rule in selectedSet.urls {
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 8
                let label = NSTextField(labelWithString: rule)
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                let deleteButton = NSButton()
                deleteButton.isBordered = false
                deleteButton.identifier = NSUserInterfaceItemIdentifier(rule)
                deleteButton.image = appKitSymbolImage(
                    named: "trash",
                    pointSize: 13,
                    weight: .regular,
                    color: .systemRed
                )
                deleteButton.contentTintColor = .systemRed
                deleteButton.target = self
                deleteButton.action = #selector(deleteRule(_:))
                row.addArrangedSubview(label)
                row.addArrangedSubview(NSView())
                row.addArrangedSubview(deleteButton)
                contentScrollView.stackView.addArrangedSubview(row)
            }
        }

        contentScrollView.stackView.addArrangedSubview(makeDivider())

        let suggestionsButton = NSButton(
            title: "Open Tabs Suggestions",
            target: self,
            action: #selector(toggleSuggestions)
        )
        suggestionsButton.isBordered = false
        suggestionsButton.alignment = .left
        suggestionsButton.contentTintColor = .labelColor
        contentScrollView.stackView.addArrangedSubview(suggestionsButton)

        if isSuggestionsExpanded {
            let filtered = RulesSectionSupport.filterSuggestions(
                appState.currentOpenUrls,
                existing: selectedSet
            )
            if filtered.isEmpty {
                let label = NSTextField(
                    labelWithString: RulesSectionSupport.suggestionsEmptyText(
                        currentOpenUrls: appState.currentOpenUrls
                    )
                )
                label.font = .systemFont(ofSize: 12)
                label.textColor = .secondaryLabelColor
                contentScrollView.stackView.addArrangedSubview(label)
            } else {
                for suggestion in filtered {
                    let row = NSStackView()
                    row.orientation = .horizontal
                    row.alignment = .centerY
                    row.spacing = 8
                    let icon = NSImageView(
                        image: NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil) ?? NSImage()
                    )
                    icon.contentTintColor = .systemGreen
                    let label = NSTextField(labelWithString: suggestion)
                    label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                    let addButton = NSButton(title: "Add", target: self, action: #selector(addSuggestion(_:)))
                    addButton.identifier = NSUserInterfaceItemIdentifier(suggestion)
                    row.addArrangedSubview(icon)
                    row.addArrangedSubview(label)
                    row.addArrangedSubview(NSView())
                    row.addArrangedSubview(addButton)
                    contentScrollView.stackView.addArrangedSubview(row)
                }
            }
        }

        contentScrollView.needsLayout = true
    }

    private func updateSidebarVisibility() {
        sidebarContainer.isHidden = !isSidebarVisible
    }

    @objc
    private func toggleSidebar() {
        isSidebarVisible.toggle()
        updateSidebarVisibility()
        reloadRuleContent()
    }

    @objc
    private func addRuleSet() {
        let alert = NSAlert()
        alert.messageText = "New Allowed List"
        let input = NSTextField(string: "")
        input.placeholderString = "List Name"
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let newSet = RuleSet(name: input.stringValue, urls: [])
        appState.ruleSets.append(newSet)
        selectedSetId = newSet.id
        reloadContent()
    }

    @objc
    private func selectRuleSet(_ sender: NSButton) {
        guard !appState.isBlocking else { return }
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        selectedSetId = id
        reloadContent()
    }

    @objc
    private func deleteRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        appState.deleteSet(id: id)
        if selectedSetId == id {
            selectedSetId = appState.ruleSets.first?.id
        }
        reloadContent()
    }

    @objc
    private func deleteRule(_ sender: NSButton) {
        guard let rule = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.removeRule(rule, from: setId)
    }

    @objc
    private func addRule() {
        guard let setId = selectedSet?.id else { return }
        appState.addRule(addRuleField.stringValue, to: setId)
        addRuleField.stringValue = ""
    }

    @objc
    private func toggleSuggestions() {
        isSuggestionsExpanded.toggle()
        if isSuggestionsExpanded {
            appState.refreshCurrentOpenUrls()
        }
        reloadRuleContent()
    }

    @objc
    private func addSuggestion(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.addSpecificRule(url, to: setId)
    }
}

extension RulesSheetViewController {
    var selectedSetIdForTesting: UUID? { selectedSetId }
    var isSidebarVisibleForTesting: Bool { isSidebarVisible }
    var isSuggestionsExpandedForTesting: Bool { isSuggestionsExpanded }

    func createSetForTesting(name: String) {
        let newSet = RuleSet(name: name, urls: [])
        appState.ruleSets.append(newSet)
        selectedSetId = newSet.id
        reloadContent()
    }

    func selectRuleSetForTesting(_ ruleSet: RuleSet) {
        guard !appState.isBlocking else { return }
        selectedSetId = ruleSet.id
        reloadContent()
    }

    func deleteRuleSetForTesting(_ ruleSet: RuleSet) {
        appState.deleteSet(id: ruleSet.id)
        if selectedSetId == ruleSet.id {
            selectedSetId = appState.ruleSets.first?.id
        }
        reloadContent()
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func toggleSuggestionsForTesting() {
        toggleSuggestions()
    }

    func setSuggestionsExpandedForTesting(_ expanded: Bool) {
        isSuggestionsExpanded = expanded
        reloadRuleContent()
    }

    func refreshSuggestionsForTesting() {
        appState.refreshCurrentOpenUrls()
        reloadRuleContent()
    }

    func addSuggestionForTesting(url: String, setId: UUID) {
        appState.addSpecificRule(url, to: setId)
        reloadRuleContent()
    }

    func addRuleForTesting(_ rule: String, setId: UUID) {
        selectedSetId = setId
        addRuleField.stringValue = rule
        addRule()
    }

    func filteredSuggestionsForTesting(for selectedSet: RuleSet) -> [String] {
        RulesSectionSupport.filterSuggestions(appState.currentOpenUrls, existing: selectedSet)
    }
}
