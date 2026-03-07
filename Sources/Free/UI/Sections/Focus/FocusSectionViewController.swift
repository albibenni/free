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
    let unblockableWarningLabel = NSTextField(labelWithString: "Unblockable mode is active. You cannot disable Focus Mode.")
    let pauseDashboardView = AppKitDynamicView()
    let pauseTitleLabel = NSTextField(labelWithString: "On Break")
    let pauseTimeLabel = NSTextField(labelWithString: "")
    let pauseEndButton = NSButton(title: "End Break & Focus", target: nil, action: nil)
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
            publisher: AppKitAppStateObservation.focusPublisher(appState: appState),
            cancellables: &cancellables
        ) { [weak self] in
            self?.handleObservedAppStateChange()
        }

        reloadContent()
    }
}
