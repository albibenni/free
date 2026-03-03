import AppKit
import Combine

@MainActor
final class FreeShellState: ObservableObject {
    @Published var showSidebar = false
    @Published var selectedSection: MainContentSection = .focus
    @Published var showRules = false
    @Published var showSchedules = false
}

final class FreeStatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let statusLabelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")
    private let onQuit: () -> Void

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
        super.init()

        statusLabelItem.isEnabled = false
        quitItem.target = self
        quitItem.action = #selector(handleQuit)

        statusMenu.addItem(statusLabelItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
    }

    func update(statusText: String, isQuitDisabled: Bool, iconColor: NSColor) {
        statusLabelItem.title = statusText
        quitItem.isEnabled = !isQuitDisabled

        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = iconColor
    }

    @objc
    private func handleQuit() {
        onQuit()
    }
}

final class FreeSheetContainerViewController: NSViewController {
    private let titleText: String
    private let hostedController: NSViewController
    private let onDone: () -> Void

    private let titleLabel = NSTextField(labelWithString: "")
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let divider = NSView()
    private let contentContainer = NSView()

    init(title: String, contentController: NSViewController, onDone: @escaping () -> Void) {
        self.titleText = title
        self.hostedController = contentController
        self.onDone = onDone
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

        titleLabel.stringValue = titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        doneButton.target = self
        doneButton.action = #selector(handleDone)
        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .regular

        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor

        [titleLabel, doneButton, divider, contentContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        addChild(hostedController)
        let hostedView = hostedController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(hostedView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            contentContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostedView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    @objc
    private func handleDone() {
        onDone()
    }
}

final class FreeSheetWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void
    private var isClosingProgrammatically = false

    init(
        contentViewController: NSViewController,
        contentSize: CGSize,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose

        let window = NSWindow(contentViewController: contentViewController)
        window.setContentSize(contentSize)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(for parentWindow: NSWindow) {
        guard let window else { return }
        parentWindow.beginSheet(window)
    }

    func dismiss() {
        guard let window else { return }
        isClosingProgrammatically = true
        if let parentWindow = window.sheetParent {
            parentWindow.endSheet(window)
        }
        window.orderOut(nil)
        isClosingProgrammatically = false
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingProgrammatically else { return }
        onClose()
    }
}

final class FreeMainWindowController: NSWindowController {
    init(rootViewController: NSViewController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = CGSize(width: 900, height: 800)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.contentViewController = rootViewController
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FreeMainViewController: NSViewController {
    private let appState: AppState
    private let shellState: FreeShellState
    private let focusSectionController: FocusSectionViewController
    private let settingsSectionController: SettingsSectionViewController

    private let sidebarContainer = NSView()
    private let sidebarStack = NSStackView()
    private let headerRow = NSStackView()
    private let menuLabel = NSTextField(labelWithString: "Menu")
    private let sidebarToggleButton = NSButton()
    private let sidebarDivider = NSView()
    private let sectionButtonsStack = NSStackView()
    private let settingsDivider = NSView()
    private let contentDivider = NSView()
    private let contentContainer = NSView()

    private var sectionButtons: [MainContentSection: NSButton] = [:]
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var rulesSheetController: FreeSheetWindowController?
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
        self.focusSectionController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .all
        )
        self.settingsSectionController = SettingsSectionViewController(appState: appState)
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
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.addSubview(sidebarContainer)

        contentDivider.translatesAutoresizingMaskIntoConstraints = false
        contentDivider.wantsLayer = true
        contentDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
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

        sidebarDivider.wantsLayer = true
        sidebarDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
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

        settingsDivider.wantsLayer = true
        settingsDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
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

        shellState.$showRules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? self.presentRulesSheetIfNeeded() : self.dismissRulesSheetIfNeeded()
            }
            .store(in: &cancellables)

        shellState.$showSchedules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? self.presentSchedulesSheetIfNeeded() : self.dismissSchedulesSheetIfNeeded()
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
        sidebarToggleButton.image = symbolImage(
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
            focusSectionController.section = .all
            targetViewController = focusSectionController
        case .schedules:
            focusSectionController.section = .schedules
            targetViewController = focusSectionController
        case .pomodoro:
            focusSectionController.section = .pomodoro
            targetViewController = focusSectionController
        case .allowedWebsites:
            focusSectionController.section = .allowedWebsites
            targetViewController = focusSectionController
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
        shellState.selectedSection = section
        updateSidebarSelection()
        updateContentController()
    }

    private func configureIconButton(_ button: NSButton, symbolName: String) {
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        button.image = symbolImage(
            named: symbolName,
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor
        )
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func sidebarButton(for section: MainContentSection) -> NSButton {
        let button = NSButton(title: section.rawValue, target: self, action: #selector(handleSidebarButton(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(section.rawValue)
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
        let backgroundColor =
            isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : .clear
        let titleColor =
            isSelected
            ? NSColor.labelColor
            : NSColor.secondaryLabelColor
        let iconColor =
            isSelected
            ? NSColor.controlAccentColor
            : NSColor.secondaryLabelColor
        let fontWeight: NSFont.Weight = isSelected ? .semibold : .medium

        button.layer?.backgroundColor = backgroundColor.cgColor
        button.image = symbolImage(
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
        guard rulesSheetController == nil, let parentWindow = view.window else { return }

        let rulesController = RulesSheetViewController(appState: appState)
        let container = FreeSheetContainerViewController(title: "Allowed Websites", contentController: rulesController) { [weak self] in
            self?.shellState.showRules = false
        }
        let controller = FreeSheetWindowController(
            contentViewController: container,
            contentSize: CGSize(width: 700, height: 650)
        ) { [weak self] in
            self?.rulesSheetController = nil
            if self?.shellState.showRules == true {
                self?.shellState.showRules = false
            }
        }
        rulesSheetController = controller
        controller.present(for: parentWindow)
    }

    private func dismissRulesSheetIfNeeded() {
        guard let controller = rulesSheetController else { return }
        rulesSheetController = nil
        controller.dismiss()
    }

    private func presentSchedulesSheetIfNeeded() {
        guard schedulesSheetController == nil, let parentWindow = view.window else { return }

        let schedulesController = SchedulesSheetViewController(appState: appState) { [weak self] in
            self?.shellState.showSchedules = false
        }
        let controller = FreeSheetWindowController(
            contentViewController: schedulesController,
            contentSize: CGSize(width: 750, height: 700)
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

    private func symbolImage(
        named symbolName: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor? = nil
    ) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }

        let configured = baseImage.withSymbolConfiguration(
            .init(pointSize: pointSize, weight: weight)
        ) ?? baseImage
        guard let color else { return configured }
        return configured.withSymbolConfiguration(.init(paletteColors: [color])) ?? configured
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
    var selectedSectionForTesting: MainContentSection { shellState.selectedSection }

    func selectSectionForTesting(_ section: MainContentSection) {
        applySelectedSection(section)
    }

    func isSidebarButtonSelectedForTesting(_ section: MainContentSection) -> Bool {
        guard let color = sectionButtons[section]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) else {
            return false
        }
        return color.alphaComponent > 0.01
    }
}
