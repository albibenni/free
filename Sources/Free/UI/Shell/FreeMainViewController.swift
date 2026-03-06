import AppKit
import Combine

final class FreeMainViewController: NSViewController {
    private let appState: AppState
    private let shellState: FreeShellState
    private let focusOverviewController: FocusSectionViewController
    private let schedulesOverviewController: FocusSectionViewController
    private let pomodoroSectionController: FocusSectionViewController
    private let allowedWebsitesSectionController: FocusSectionViewController
    private let settingsSectionController: SettingsSectionViewController
    private let sectionRouter: MainSectionRouter

    private let sidebarView: MainSidebarView
    private let contentDivider = AppKitDynamicView()
    private let contentHostView = MainContentHostView()
    private let bindings = MainShellBindings()
    private lazy var sheetPresenter = MainSheetPresenter(
        appState: appState,
        onRulesDismissed: { [weak self] in
            if self?.shellState.showRules == true {
                self?.shellState.showRules = false
            }
        },
        onSchedulesDismissed: { [weak self] in
            if self?.shellState.showSchedules == true {
                self?.shellState.showSchedules = false
            }
        }
    )

    init(
        appState: AppState,
        initialSection: MainContentSection = .focus,
        initialShowSidebar: Bool = false
    ) {
        self.appState = appState
        let shellState = FreeShellState()
        shellState.selectedSection = initialSection
        shellState.showSidebar = initialShowSidebar
        self.shellState = shellState
        sidebarView = MainSidebarView(
            selectedSection: initialSection,
            isSidebarVisible: initialShowSidebar,
            accentColorIndex: appState.accentColorIndex
        )
        focusOverviewController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .all
        )
        schedulesOverviewController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .schedules
        )
        pomodoroSectionController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .pomodoro
        )
        allowedWebsitesSectionController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .allowedWebsites
        )
        settingsSectionController = SettingsSectionViewController(appState: appState)
        sectionRouter = MainSectionRouter(
            focusOverviewController: focusOverviewController,
            schedulesOverviewController: schedulesOverviewController,
            pomodoroSectionController: pomodoroSectionController,
            allowedWebsitesSectionController: allowedWebsitesSectionController,
            settingsSectionController: settingsSectionController
        )
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

        configureLayout()
        updateSidebarVisibility()
        updateSidebarSelection()
        updateContentController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindShellState()
    }

    func presentLaunchAtLoginPromptIfNeeded() {
        guard let window = view.window, appState.prepareLaunchAtLoginPromptIfNeeded() else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to launch at Login"
        alert.informativeText = "Would you like Free to start automatically when you log in?"
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not Now")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            _ = self?.appState.enableLaunchAtLogin()
        }
    }

    private func configureLayout() {
        sidebarView.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }
        sidebarView.onSelectSection = { [weak self] section in
            self?.applySelectedSection(section)
        }
        view.addSubview(sidebarView)

        contentHostView.parentViewController = self
        contentDivider.translatesAutoresizingMaskIntoConstraints = false
        contentDivider.backgroundColorProvider = { NSColor.separatorColor }
        view.addSubview(contentDivider)
        view.addSubview(contentHostView)

        NSLayoutConstraint.activate([
            sidebarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarView.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentDivider.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            contentDivider.topAnchor.constraint(equalTo: view.topAnchor),
            contentDivider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentDivider.widthAnchor.constraint(equalToConstant: 1),

            contentHostView.leadingAnchor.constraint(equalTo: contentDivider.trailingAnchor),
            contentHostView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentHostView.topAnchor.constraint(equalTo: view.topAnchor),
            contentHostView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindShellState() {
        bindings.bind(
            appStateChanges: appState.objectWillChange
                .map { () }
                .eraseToAnyPublisher(),
            shellState: shellState,
            onSelectedSectionChanged: { [weak self] in
                self?.updateSidebarSelection()
                self?.updateContentController()
            },
            onAppStateChanged: { [weak self] in
                self?.updateSidebarSelection()
            },
            onShowRulesChanged: { [weak self] isShown in
                guard let self else { return }
                isShown
                    ? sheetPresenter.presentRules(from: view.window)
                    : sheetPresenter.dismissRules()
            },
            onShowSchedulesChanged: { [weak self] isShown in
                guard let self else { return }
                isShown
                    ? sheetPresenter.presentSchedules(from: view.window)
                    : sheetPresenter.dismissSchedules()
            }
        )
    }

    private func updateSidebarSelection() {
        sidebarView.updateSelection(
            selectedSection: shellState.selectedSection,
            accentColorIndex: appState.accentColorIndex
        )
    }

    private func updateSidebarVisibility() {
        sidebarView.setSidebarVisible(shellState.showSidebar)
    }

    private func updateContentController() {
        let targetViewController = sectionRouter.controller(for: shellState.selectedSection)
        contentHostView.display(targetViewController)
    }

    private func applySelectedSection(_ section: MainContentSection) {
        if isTabSwitchBlockedByPresentedWindow, section != shellState.selectedSection {
            return
        }
        shellState.selectedSection = section
        updateSidebarSelection()
        updateContentController()
    }

    private var isTabSwitchBlockedByPresentedWindow: Bool {
        shellState.showRules || shellState.showSchedules
    }

    private func toggleSidebar() {
        shellState.showSidebar.toggle()
        updateSidebarVisibility()
    }
}

extension FreeMainViewController {
    var isSidebarVisibleForTesting: Bool { shellState.showSidebar }
    var selectedSectionForTesting: MainContentSection { shellState.selectedSection }
    var currentContentViewControllerForTesting: NSViewController? { contentHostView.currentViewController }
    var currentFocusSectionForTesting: FocusContentSection? {
        (contentHostView.currentViewController as? FocusSectionViewController)?.section
    }
    var pomodoroWidgetIdentifierForTesting: ObjectIdentifier? {
        pomodoroSectionController.widgetViewIdentifierForTesting
    }
    var selectedSidebarBackgroundColorForTesting: NSColor? {
        sidebarView.selectedBackgroundColor(for: shellState.selectedSection)
    }
    func sidebarButtonLeadingInsetForTesting(_ section: MainContentSection) -> CGFloat? {
        sidebarView.leadingInset(for: section)
    }

    func selectSectionForTesting(_ section: MainContentSection) {
        applySelectedSection(section)
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func isSidebarButtonSelectedForTesting(_ section: MainContentSection) -> Bool {
        guard let color = sidebarView.selectedBackgroundColor(for: section) else {
            return false
        }
        return color.alphaComponent > 0.01
    }

    func setPresentedWindowStatesForTesting(showRules: Bool, showSchedules: Bool) {
        shellState.showRules = showRules
        shellState.showSchedules = showSchedules
    }
}
