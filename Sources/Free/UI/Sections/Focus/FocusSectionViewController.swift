import AppKit
import Combine

final class FocusSectionViewController: NSViewController {
    private struct PomodoroWidgetSignature: Equatable {
        struct RuleSetSnapshot: Equatable {
            let id: UUID
            let name: String
        }

        struct ContentSignature: Equatable {
            let appearanceMode: AppearanceMode
            let accentColorIndex: Int
            let isBlocking: Bool
            let isStrictActive: Bool
            let pomodoroStatus: PomodoroStatus
            let pomodoroFocusDuration: Double
            let pomodoroBreakDuration: Double
            let pomodoroRemaining: TimeInterval
            let isPomodoroLocked: Bool
            let ruleSets: [RuleSetSnapshot]
        }

        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let isBlocking: Bool
        let isStrictActive: Bool
        let pomodoroStatus: PomodoroStatus
        let pomodoroFocusDuration: Double
        let pomodoroBreakDuration: Double
        let pomodoroRemaining: TimeInterval
        let isPomodoroLocked: Bool
        let activeRuleSetId: UUID?
        let currentPrimaryRuleSetId: UUID?
        let ruleSets: [RuleSetSnapshot]

        var contentSignature: ContentSignature {
            ContentSignature(
                appearanceMode: appearanceMode,
                accentColorIndex: accentColorIndex,
                isBlocking: isBlocking,
                isStrictActive: isStrictActive,
                pomodoroStatus: pomodoroStatus,
                pomodoroFocusDuration: pomodoroFocusDuration,
                pomodoroBreakDuration: pomodoroBreakDuration,
                pomodoroRemaining: pomodoroRemaining,
                isPomodoroLocked: isPomodoroLocked,
                ruleSets: ruleSets
            )
        }

        init(appState: AppState) {
            appearanceMode = appState.appearanceMode
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

    private struct SchedulesWidgetSignature: Equatable {
        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let todaySchedules: [Schedule]

        init(appState: AppState) {
            appearanceMode = appState.appearanceMode
            accentColorIndex = appState.accentColorIndex
            todaySchedules = appState.todaySchedules
        }
    }

    private struct AllowedWebsitesWidgetSignature: Equatable {
        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let activeRuleSetId: UUID?
        let isStrictActive: Bool
        let ruleSets: [RuleSet]

        init(appState: AppState) {
            appearanceMode = appState.appearanceMode
            accentColorIndex = appState.accentColorIndex
            activeRuleSetId = appState.activeRuleSetId
            isStrictActive = appState.isStrictActive
            ruleSets = appState.ruleSets
        }
    }

    private let appState: AppState
    private let shellState: FreeShellState
    var section: FocusContentSection {
        didSet { reloadContent() }
    }

    private let scrollContainer = VerticalStackScrollContainer()
    private let permissionWarningView = AppKitDynamicView()
    private let permissionTitleLabel = NSTextField(labelWithString: "Accessibility Permission Needed")
    private let grantPermissionButton = NSButton(title: "Grant", target: nil, action: nil)
    private let headerCardView = AppKitDynamicView()
    private let headerIconView = NSImageView()
    private let headerTitleLabel = NSTextField(labelWithString: "Focus Mode")
    private let headerStatusLabel = NSTextField(labelWithString: "")
    private let unblockableWarningLabel = NSTextField(labelWithString: "Unblockable mode is active. You cannot disable Focus Mode.")
    private let pauseDashboardView = AppKitDynamicView()
    private let pauseTitleLabel = NSTextField(labelWithString: "On Break")
    private let pauseTimeLabel = NSTextField(labelWithString: "")
    private let pauseEndButton = NSButton(title: "End Break & Focus", target: nil, action: nil)
    private let overviewCardView = AppKitDynamicView()
    private let overviewTitleLabel = NSTextField(labelWithString: "Live Overview")
    private let overviewRowsStack = NSStackView()
    private let widgetContainer = NSView()

    private var widgetView: NSView?
    private var cancellables: Set<AnyCancellable> = []
    private var pomodoroWidgetInteractionDepth = 0
    private var needsReloadAfterPomodoroInteraction = false
    private var pomodoroWidgetSignature: PomodoroWidgetSignature?
    private var schedulesWidgetSignature: SchedulesWidgetSignature?
    private var allowedWebsitesWidgetSignature: AllowedWebsitesWidgetSignature?

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
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

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

        AppKitAppStateObservation.bind(
            appState: appState,
            cancellables: &cancellables
        ) { [weak self] in
            self?.handleObservedAppStateChange()
        }

        reloadContent()
    }

    private func handleObservedAppStateChange() {
        guard !(section == .pomodoro && pomodoroWidgetInteractionDepth > 0) else {
            needsReloadAfterPomodoroInteraction = true
            return
        }
        if handlePomodoroSectionStateChange() {
            return
        }
        reloadContent()
    }

    private func applySharedState() {
        permissionWarningView.isHidden = appState.isTrusted

        let headerIconName = AppKitUISymbols.Name.focus
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
    }

    private func handlePomodoroSectionStateChange() -> Bool {
        guard section == .pomodoro,
              let pomodoroWidgetView = widgetView as? FocusPomodoroWidgetView,
              pomodoroWidgetSignature != nil
        else {
            return false
        }

        let nextSignature = PomodoroWidgetSignature(appState: appState)
        pomodoroWidgetSignature = nextSignature
        applySharedState()
        pomodoroWidgetView.updateRuleSetSelection()
        pomodoroWidgetView.updateForStateChange()
        return true
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
        handleObservedAppStateChange()
    }

    private func configurePermissionWarning() {
        permissionWarningView.wantsLayer = true
        permissionWarningView.layer?.backgroundColor = NSColor.systemRed.cgColor
        permissionWarningView.layer?.cornerRadius = 12

        let icon = NSImageView(image: NSImage(systemSymbolName: AppKitUISymbols.Name.warning, accessibilityDescription: nil) ?? NSImage())
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
        headerCardView.backgroundColorProvider = { NSColor.controlBackgroundColor }
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
        pauseDashboardView.backgroundColorProvider = { NSColor.systemOrange.withAlphaComponent(0.1) }
        pauseDashboardView.layer?.cornerRadius = 12
        pauseDashboardView.borderColorProvider = { NSColor.systemOrange.withAlphaComponent(0.3) }
        pauseDashboardView.borderWidthValue = 1

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
        overviewCardView.backgroundColorProvider = { NSColor.controlBackgroundColor }
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
        applySharedState()

        overviewCardView.isHidden = section != .all
        if section == .all {
            reloadOverviewRows()
        }
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
                    iconName: AppKitUISymbols.Name.schedules,
                    title: "Active Schedules",
                    value: activeScheduleNames.joined(separator: ", ")
                )
            )
        }

        if shouldShowAllowList, let currentRuleSet {
            overviewRowsStack.addArrangedSubview(
                makeOverviewRow(
                    iconName: AppKitUISymbols.Name.globe,
                    title: "Allow List",
                    value: "\(currentRuleSet.name) • \(currentRuleSet.urls.count) rules"
                )
            )
        }

        if shouldShowPomodoro {
            overviewRowsStack.addArrangedSubview(
                makeOverviewRow(
                    iconName: AppKitUISymbols.Name.pomodoro,
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
            widgetContainer.isHidden = false

            if let currentSignature = pomodoroWidgetSignature,
               currentSignature.contentSignature == nextSignature.contentSignature,
               currentSignature.activeRuleSetId != nextSignature.activeRuleSetId
                    || currentSignature.currentPrimaryRuleSetId != nextSignature.currentPrimaryRuleSetId
            {
                pomodoroWidgetSignature = nextSignature
                pomodoroWidgetView.updateRuleSetSelection()
            } else if pomodoroWidgetSignature != nextSignature {
                pomodoroWidgetSignature = nextSignature
                pomodoroWidgetView.refreshForStateChange()
            } else {
                pomodoroWidgetView.needsLayout = true
            }
            return
        } else if section != .pomodoro {
            pomodoroWidgetSignature = nil
        }

        if section == .schedules,
           widgetView is FocusSchedulesWidgetView
        {
            let nextSignature = SchedulesWidgetSignature(appState: appState)
            if schedulesWidgetSignature == nextSignature {
                return
            }
            schedulesWidgetSignature = nextSignature
        } else if section != .schedules {
            schedulesWidgetSignature = nil
        }

        if section == .allowedWebsites,
           widgetView is FocusAllowedWebsitesWidgetView
        {
            let nextSignature = AllowedWebsitesWidgetSignature(appState: appState)
            if allowedWebsitesWidgetSignature == nextSignature {
                return
            }
            allowedWebsitesWidgetSignature = nextSignature
        } else if section != .allowedWebsites {
            allowedWebsitesWidgetSignature = nil
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
            schedulesWidgetSignature = SchedulesWidgetSignature(appState: appState)
            nextWidgetView = FocusSchedulesWidgetView(appState: appState, shellState: shellState)
        case .allowedWebsites:
            allowedWebsitesWidgetSignature = AllowedWebsitesWidgetSignature(appState: appState)
            nextWidgetView = FocusAllowedWebsitesWidgetView(appState: appState, shellState: shellState)
        case .all:
            pomodoroWidgetSignature = nil
            schedulesWidgetSignature = nil
            allowedWebsitesWidgetSignature = nil
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
    var pomodoroWidgetRefreshGenerationForTesting: Int? {
        (widgetView as? FocusPomodoroWidgetView)?.refreshGeneration
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
