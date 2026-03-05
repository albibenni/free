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

    private let sidebarView: MainSidebarView
    private let contentDivider = AppKitDynamicView()
    private let contentHostView = MainContentHostView()

    private var rulesSheetController: AllowedWebsitesSheetController?
    private var schedulesSheetController: FreeSheetWindowController?
    private var cancellables: Set<AnyCancellable> = []

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
        shellState.$selectedSection
            .sink { [weak self] _ in
                self?.updateSidebarSelection()
                self?.updateContentController()
            }
            .store(in: &cancellables)

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSidebarSelection()
            }
            .store(in: &cancellables)

        shellState.$showRules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? presentRulesSheetIfNeeded() : dismissRulesSheetIfNeeded()
            }
            .store(in: &cancellables)

        shellState.$showSchedules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? presentSchedulesSheetIfNeeded() : dismissSchedulesSheetIfNeeded()
            }
            .store(in: &cancellables)
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
        let targetViewController: NSViewController
        switch shellState.selectedSection {
        case .settings:
            targetViewController = settingsSectionController
        case .focus:
            targetViewController = focusOverviewController
        case .schedules:
            targetViewController = schedulesOverviewController
        case .pomodoro:
            targetViewController = pomodoroSectionController
        case .allowedWebsites:
            targetViewController = allowedWebsitesSectionController
        }

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

    private func presentRulesSheetIfNeeded() {
        guard let parentWindow = view.window else { return }
        if let rulesSheetController {
            rulesSheetController.present(
                for: parentWindow,
                selectedRuleSetId: appState.activeRuleSetId
            )
            return
        }

        let controller = AllowedWebsitesSheetController(
            appState: appState
        ) { [weak self] in
            self?.rulesSheetController = nil
            if self?.shellState.showRules == true {
                self?.shellState.showRules = false
            }
        }
        rulesSheetController = controller
        controller.present(
            for: parentWindow,
            selectedRuleSetId: appState.activeRuleSetId
        )
    }

    private func dismissRulesSheetIfNeeded() {
        guard let controller = rulesSheetController else { return }
        rulesSheetController = nil
        controller.dismiss()
    }

    private func presentSchedulesSheetIfNeeded() {
        guard let parentWindow = view.window else { return }
        if let attachedSheet = parentWindow.attachedSheet,
           attachedSheet !== schedulesSheetController?.window
        {
            parentWindow.endSheet(attachedSheet)
            attachedSheet.orderOut(nil)
        }
        if let schedulesSheetController {
            schedulesSheetController.present(for: parentWindow)
            return
        }

        let schedulesController = SchedulesSheetViewController(appState: appState) { [weak self] in
            self?.shellState.showSchedules = false
        }
        let controller = FreeSheetWindowController(
            contentViewController: schedulesController,
            contentSize: CGSize(width: 750, height: 700),
            presentsAsSheet: false,
            showsNativeCloseButton: true
        ) { [weak self] in
            self?.schedulesSheetController = nil
            if self?.shellState.showSchedules == true {
                self?.shellState.showSchedules = false
            }
        }
        schedulesSheetController = controller
        controller.present(for: parentWindow)
    }

    private func dismissSchedulesSheetIfNeeded() {
        guard let controller = schedulesSheetController else { return }
        schedulesSheetController = nil
        controller.dismiss()
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
