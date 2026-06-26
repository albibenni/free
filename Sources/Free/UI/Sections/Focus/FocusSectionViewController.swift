import AppKit
import Combine

final class FocusSectionViewController: NSViewController {
    let appState: AppState
    let shellState: FreeShellState
    var section: FocusContentSection {
        didSet { reloadContent() }
    }

    let scrollContainer = VerticalStackScrollContainer()
    let permissionWarningView = AppKitDynamicView()
    let permissionTitleLabel = NSTextField(labelWithString: "Accessibility Permission Needed")
    let grantPermissionButton = NSButton(title: "Grant", target: nil, action: nil)
    let headerCardView = AppKitDynamicView()
    let headerIconView = NSImageView()
    let headerTitleLabel = NSTextField(labelWithString: "Focus Mode")
    let headerStatusLabel = NSTextField(labelWithString: "")
    let strictWarningLabel = NSTextField(
        labelWithString: StrictModeCopy.active(
            withSuffix: " A challenge phrase is required to disable Focus Mode."
        )
    )
    let pauseDashboardView = AppKitDynamicView()
    let pauseTitleLabel = NSTextField(labelWithString: "On Break")
    let pauseTimeLabel = NSTextField(labelWithString: "")
    let pauseEndButton = ActionButton(title: "End Break & Focus")
    let quickBreakDashboardView = AppKitDynamicView()
    let quickBreakTitleLabel = NSTextField(labelWithString: "Quick Break")
    let quickBreakFiveButton = ActionButton(title: "5m")
    let quickBreakFifteenButton = ActionButton(title: "15m")
    let quickBreakThirtyButton = ActionButton(title: "30m")
    let quickBreakCustomMinutesField = VerticallyCenteredTextField(string: "")
    let quickBreakCustomButton = ActionButton(title: "Start")
    let overviewCardView = AppKitDynamicView()
    let overviewTitleLabel = NSTextField(labelWithString: "Live Overview")
    let overviewRowsStack = NSStackView()
    let widgetContainer = NSView()

    var widgetView: NSView?
    var cancellables: Set<AnyCancellable> = []
    var pomodoroWidgetInteractionDepth = 0
    var needsReloadAfterPomodoroInteraction = false
    var pomodoroWidgetSignature: FocusPomodoroWidgetSignature?
    var schedulesWidgetSignature: FocusSchedulesWidgetSignature?
    var allowedWebsitesWidgetSignature: FocusAllowedWebsitesWidgetSignature?
    var grantAccessibilityActionFactory: () -> () -> Void = {
        FocusSectionSupport.makeGrantAccessibilityAction()
    }

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
        configureQuickBreakDashboard()
        configureOverview()
        configureWidgetContainer()

        let stack = scrollContainer.stackView
        [
            permissionWarningView,
            headerCardView,
            strictWarningLabel,
            pauseDashboardView,
            quickBreakDashboardView,
            overviewCardView,
            widgetContainer,
        ].forEach {
            stack.addArrangedSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let appState = self.appState
        AppKitAppStateObservation.observe(appState: appState, readProperties: { [weak self, weak appState] () -> Bool in
            guard self != nil, let appState = appState else { return false }
            _ = appState.isBlocking
            _ = appState.isStrict
            _ = appState.isTrusted
            _ = appState.isPaused
            _ = appState.pauseRemaining
            _ = appState.pomodoroStatus
            _ = appState.pomodoroRemaining
            _ = appState.pomodoroStartedAt
            _ = appState.pomodoroFocusDuration
            _ = appState.pomodoroBreakDuration
            _ = appState.ruleSets
            _ = appState.activeRuleSetId
            _ = appState.schedules
            _ = appState.accentColorIndex
            _ = appState.appearanceMode
            return true
        }) { [weak self] _ in
            self?.handleObservedAppStateChange()
        }

        reloadContent()
    }
}
