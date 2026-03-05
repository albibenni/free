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

    private let sidebarContainer = AppKitDynamicView()
    private let sidebarStack = NSStackView()
    private let headerRow = NSStackView()
    private let menuLabel = NSTextField(labelWithString: "Menu")
    private let sidebarToggleButton = NSButton()
    private let sidebarDivider = AppKitDynamicView()
    private let sectionButtonsStack = NSStackView()
    private let settingsDivider = AppKitDynamicView()
    private let contentDivider = AppKitDynamicView()
    private let contentContainer = NSView()

    private var sectionButtons: [MainContentSection: NSButton] = [:]
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var rulesSheetController: AllowedWebsitesSheetController?
    private var schedulesSheetController: FreeSheetWindowController?
    private var currentContentViewController: NSViewController?
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

        configureSidebar()
        configureContent()
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

    private func configureSidebar() {
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view.addSubview(sidebarContainer)

        contentDivider.translatesAutoresizingMaskIntoConstraints = false
        contentDivider.backgroundColorProvider = { NSColor.separatorColor }
        view.addSubview(contentDivider)

        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 12
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarStack)

        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        configureIconButton(sidebarToggleButton, symbolName: "sidebar.left")
        sidebarToggleButton.target = self
        sidebarToggleButton.action = #selector(toggleSidebar)
        menuLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerRow.addArrangedSubview(sidebarToggleButton)
        headerRow.addArrangedSubview(menuLabel)
        headerRow.addArrangedSubview(NSView())

        sidebarDivider.backgroundColorProvider = { NSColor.separatorColor }
        sidebarDivider.translatesAutoresizingMaskIntoConstraints = false
        sidebarDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        sidebarDivider.widthAnchor.constraint(equalToConstant: 156).isActive = true

        sectionButtonsStack.orientation = .vertical
        sectionButtonsStack.alignment = .leading
        sectionButtonsStack.spacing = 8

        for section in [.focus, .schedules, .pomodoro, .allowedWebsites] as [MainContentSection] {
            let button = sidebarButton(for: section)
            sectionButtons[section] = button
            sectionButtonsStack.addArrangedSubview(button)
        }

        settingsDivider.backgroundColorProvider = { NSColor.separatorColor }
        settingsDivider.translatesAutoresizingMaskIntoConstraints = false
        settingsDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        settingsDivider.widthAnchor.constraint(equalToConstant: 156).isActive = true

        if let settingsButton = sectionButtons[.settings] {
            settingsButton.removeFromSuperview()
        }
        let settingsButton = sidebarButton(for: .settings)
        sectionButtons[.settings] = settingsButton

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        [headerRow, sidebarDivider, sectionButtonsStack, spacer, settingsDivider, settingsButton]
            .forEach { sidebarStack.addArrangedSubview($0) }

        sidebarWidthConstraint = sidebarContainer.widthAnchor.constraint(equalToConstant: 56)
        sidebarWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentDivider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            contentDivider.topAnchor.constraint(equalTo: view.topAnchor),
            contentDivider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentDivider.widthAnchor.constraint(equalToConstant: 1),

            sidebarStack.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 12),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -12),
            sidebarStack.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 12),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor, constant: -12),
        ])
    }

    private func configureContent() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: contentDivider.trailingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
        for (section, button) in sectionButtons {
            applySidebarButtonStyle(button, section: section, isSelected: shellState.selectedSection == section)
        }
    }

    private func updateSidebarVisibility() {
        let isVisible = shellState.showSidebar
        menuLabel.isHidden = !isVisible
        sectionButtonsStack.isHidden = !isVisible
        sidebarDivider.isHidden = !isVisible
        settingsDivider.isHidden = !isVisible
        sectionButtons[.settings]?.isHidden = !isVisible
        sidebarWidthConstraint?.constant = isVisible ? 180 : 56
        let symbolName = isVisible ? "sidebar.left" : "sidebar.right"
        sidebarToggleButton.image = appKitSymbolImage(
            named: symbolName,
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor
        )
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

        guard currentContentViewController !== targetViewController else { return }

        currentContentViewController?.view.removeFromSuperview()
        currentContentViewController?.removeFromParent()

        addChild(targetViewController)
        let childView = targetViewController.view
        childView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            childView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            childView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        currentContentViewController = targetViewController
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

    private func configureIconButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbolName: symbolName,
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.05),
            cornerRadius: 8
        )
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func sidebarButton(for section: MainContentSection) -> NSButton {
        let button = LeadingInsetActionButton(title: section.rawValue)
        button.identifier = NSUserInterfaceItemIdentifier(section.rawValue)
        button.target = self
        button.action = #selector(handleSidebarButton(_:))
        button.leadingInset = 6
        button.titleAdditionalInset = 6
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 156).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        applySidebarButtonStyle(button, section: section, isSelected: shellState.selectedSection == section)
        return button
    }

    private func applySidebarButtonStyle(
        _ button: NSButton,
        section: MainContentSection,
        isSelected: Bool
    ) {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        let backgroundColor =
            isSelected
            ? accentColor.withAlphaComponent(0.18)
            : .clear
        let titleColor =
            isSelected
            ? NSColor.labelColor
            : NSColor.secondaryLabelColor
        let iconColor =
            isSelected
            ? accentColor
            : NSColor.secondaryLabelColor
        let fontWeight: NSFont.Weight = isSelected ? .semibold : .medium

        button.layer?.backgroundColor = backgroundColor.cgColor
        button.image = appKitSymbolImage(
            named: section.icon,
            pointSize: 13,
            weight: fontWeight,
            color: iconColor
        )
        button.attributedTitle = NSAttributedString(
            string: section.rawValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: fontWeight),
                .foregroundColor: titleColor,
            ]
        )
        button.needsDisplay = true
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

    private func section(for identifier: NSUserInterfaceItemIdentifier?) -> MainContentSection? {
        MainContentSection.allCases.first { section in
            identifier?.rawValue == section.rawValue
        }
    }

    @objc
    private func toggleSidebar() {
        shellState.showSidebar.toggle()
        updateSidebarVisibility()
    }

    @objc
    private func handleSidebarButton(_ sender: NSButton) {
        guard let section = section(for: sender.identifier) else { return }
        applySelectedSection(section)
    }
}

extension FreeMainViewController {
    var isSidebarVisibleForTesting: Bool { shellState.showSidebar }
    var selectedSectionForTesting: MainContentSection { shellState.selectedSection }
    var currentContentViewControllerForTesting: NSViewController? { currentContentViewController }
    var currentFocusSectionForTesting: FocusContentSection? {
        (currentContentViewController as? FocusSectionViewController)?.section
    }
    var pomodoroWidgetIdentifierForTesting: ObjectIdentifier? {
        pomodoroSectionController.widgetViewIdentifierForTesting
    }
    var selectedSidebarBackgroundColorForTesting: NSColor? {
        sectionButtons[shellState.selectedSection]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:))
    }
    func sidebarButtonLeadingInsetForTesting(_ section: MainContentSection) -> CGFloat? {
        (sectionButtons[section] as? LeadingInsetActionButton)?.leadingInset
    }

    func selectSectionForTesting(_ section: MainContentSection) {
        applySelectedSection(section)
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func isSidebarButtonSelectedForTesting(_ section: MainContentSection) -> Bool {
        guard let color = sectionButtons[section]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) else {
            return false
        }
        return color.alphaComponent > 0.01
    }

    func setPresentedWindowStatesForTesting(showRules: Bool, showSchedules: Bool) {
        shellState.showRules = showRules
        shellState.showSchedules = showSchedules
    }
}
