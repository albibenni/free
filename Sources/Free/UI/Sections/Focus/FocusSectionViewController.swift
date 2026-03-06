import AppKit
import Combine

final class FocusSectionViewController: NSViewController {
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
    private var pomodoroWidgetSignature: FocusPomodoroWidgetSignature?
    private var schedulesWidgetSignature: FocusSchedulesWidgetSignature?
    private var allowedWebsitesWidgetSignature: FocusAllowedWebsitesWidgetSignature?

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
        guard !FocusInteractionReloadCoordinator.shouldDeferObservedChange(
            section: section,
            interactionDepth: pomodoroWidgetInteractionDepth
        ) else {
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

        let nextSignature = FocusPomodoroWidgetSignature(appState: appState)
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

        guard FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
            interactionDepth: pomodoroWidgetInteractionDepth,
            needsReloadAfterInteraction: needsReloadAfterPomodoroInteraction
        ) else { return }

        needsReloadAfterPomodoroInteraction = false
        handleObservedAppStateChange()
    }

    private func configurePermissionWarning() {
        FocusSectionLayoutBuilder.configurePermissionWarning(
            permissionWarningView: permissionWarningView,
            permissionTitleLabel: permissionTitleLabel,
            grantPermissionButton: grantPermissionButton,
            target: self,
            grantAction: #selector(grantAccessibility)
        )
    }

    private func configureHeaderCard() {
        FocusSectionLayoutBuilder.configureHeaderCard(
            headerCardView: headerCardView,
            headerIconView: headerIconView,
            headerTitleLabel: headerTitleLabel,
            headerStatusLabel: headerStatusLabel
        )
    }

    private func configurePauseDashboard() {
        FocusSectionLayoutBuilder.configurePauseDashboard(
            pauseDashboardView: pauseDashboardView,
            pauseTitleLabel: pauseTitleLabel,
            pauseTimeLabel: pauseTimeLabel,
            pauseEndButton: pauseEndButton,
            target: self,
            cancelAction: #selector(cancelPause)
        )
    }

    private func configureOverview() {
        FocusSectionLayoutBuilder.configureOverview(
            overviewCardView: overviewCardView,
            overviewTitleLabel: overviewTitleLabel,
            overviewRowsStack: overviewRowsStack
        )
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
        let rows = FocusSectionOverviewCoordinator.rows(appState: appState)
        for row in rows {
            overviewRowsStack.addArrangedSubview(
                FocusSectionLayoutBuilder.makeOverviewRow(
                    iconName: row.iconName,
                    title: row.title,
                    value: row.value,
                    accentColorIndex: appState.accentColorIndex,
                    availableWidth: scrollContainer.stackView.bounds.width
                )
            )
        }

        if rows.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No active schedule, allow list, or pomodoro session.")
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            overviewRowsStack.addArrangedSubview(emptyLabel)
        }
    }

    private func reloadWidget() {
        let decision = FocusSectionWidgetReloadCoordinator.decide(
            section: section,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: FocusSectionWidgetReloadCoordinator.widgetKind(for: widgetView),
            currentSignatures: FocusSectionWidgetReloadCoordinator.Signatures(
                pomodoro: pomodoroWidgetSignature,
                schedules: schedulesWidgetSignature,
                allowedWebsites: allowedWebsitesWidgetSignature
            ),
            onPomodoroInteractionDidBegin: { [weak self] in self?.beginPomodoroWidgetInteraction() },
            onPomodoroInteractionDidEnd: { [weak self] in self?.endPomodoroWidgetInteraction() }
        )

        pomodoroWidgetSignature = decision.signatures.pomodoro
        schedulesWidgetSignature = decision.signatures.schedules
        allowedWebsitesWidgetSignature = decision.signatures.allowedWebsites

        switch decision.operation {
        case .reusePomodoro(let action):
            guard let pomodoroWidgetView = widgetView as? FocusPomodoroWidgetView else { return }
            widgetContainer.isHidden = false
            switch action {
            case .updateSelection:
                pomodoroWidgetView.updateRuleSetSelection()
            case .refresh:
                pomodoroWidgetView.refreshForStateChange()
            case .keepLayout:
                pomodoroWidgetView.needsLayout = true
            }
            return
        case .keepExisting:
            widgetContainer.isHidden = section == .all
            return
        case .rebuild(let buildResult):
            widgetView?.removeFromSuperview()
            widgetView = nil
            widgetContainer.isHidden = section == .all
            guard let nextWidgetView = buildResult.widgetView else {
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
