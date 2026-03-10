import AppKit
import Combine

final class SettingsSectionViewController: NSViewController {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse
    typealias CalendarSettingsOpener = () -> Void

    static var makeStrictModeAlert: AlertFactory = { NSAlert() }
    static var runStrictModeAlert: AlertRunner = { alert in
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }
    static var makeCalendarPermissionAlert: AlertFactory = { NSAlert() }
    static var runCalendarPermissionAlert: AlertRunner = { alert in
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }
    static var openCalendarPrivacySettings: CalendarSettingsOpener = {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        else { return }
        NSWorkspace.shared.open(url)
    }
    static var calendarPermissionFallbackDelay: TimeInterval = 0.6

    private struct ObservationSignature: Equatable {
        let isBlocking: Bool
        let isUnblockable: Bool
        let isStrictActive: Bool
        let weekStartsOnMonday: Bool
        let calendarIntegrationEnabled: Bool
        let calendarImportsBlockTime: Bool
        let blockNewTabs: Bool
        let blockDeveloperHosts: Bool
        let blockLocalNetworkHosts: Bool
        let allowSearchEngineWebsites: Bool
        let allowAIProviderWebsites: Bool
        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let launchAtLoginEnabled: Bool

        static let fallback = ObservationSignature(
            isBlocking: false,
            isUnblockable: false,
            isStrictActive: false,
            weekStartsOnMonday: false,
            calendarIntegrationEnabled: false,
            calendarImportsBlockTime: false,
            blockNewTabs: false,
            blockDeveloperHosts: false,
            blockLocalNetworkHosts: false,
            allowSearchEngineWebsites: false,
            allowAIProviderWebsites: false,
            appearanceMode: .system,
            accentColorIndex: 0,
            launchAtLoginEnabled: false
        )
    }

    private let appState: AppState
    private let scrollContainer = VerticalStackScrollContainer()
    private var cancellables: Set<AnyCancellable> = []

    private let strictSection = AppKitCardStackView()
    private let strictToggle = AppKitToggleSwitch()
    private let strictDescriptionLabel = NSTextField(labelWithString: "When active, you cannot disable Focus Mode.")
    private let strictDisableButton = NSButton(title: "Disable...", target: nil, action: nil)
    private let strictStatusLabel = NSTextField(labelWithString: "Active and Locking Focus Mode.")
    private let weekStartsMondaySwitch = AppKitToggleSwitch()
    private let calendarIntegrationSwitch = AppKitToggleSwitch()
    private let calendarImportsSwitch = AppKitToggleSwitch()
    private let resyncButton = NSButton(title: "Resync Imported Schedules", target: nil, action: nil)
    private let launchAtLoginSwitch = AppKitToggleSwitch()
    private let blockNewTabsSwitch = AppKitToggleSwitch()
    private let blockDeveloperHostsSwitch = AppKitToggleSwitch()
    private let blockLocalNetworkHostsSwitch = AppKitToggleSwitch()
    private let allowSearchEngineWebsitesSwitch = AppKitToggleSwitch()
    private let allowAIProviderWebsitesSwitch = AppKitToggleSwitch()
    private var appearanceModeControl: AppKitSelectionButtonGroup<AppearanceMode>?
    private var accentButtons: [NSButton] = []
    private var pendingCalendarPermissionFallback = false

    init(appState: AppState) {
        self.appState = appState
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
        let appState = self.appState

        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.settingsPublisher(appState: appState),
            signature: {
                ObservationSignature(
                    isBlocking: appState.isBlocking,
                    isUnblockable: appState.isUnblockable,
                    isStrictActive: appState.isStrictActive,
                    weekStartsOnMonday: appState.weekStartsOnMonday,
                    calendarIntegrationEnabled: appState.calendarIntegrationEnabled,
                    calendarImportsBlockTime: appState.calendarImportsBlockTime,
                    blockNewTabs: appState.blockNewTabs,
                    blockDeveloperHosts: appState.blockDeveloperHosts,
                    blockLocalNetworkHosts: appState.blockLocalNetworkHosts,
                    allowSearchEngineWebsites: appState.allowSearchEngineWebsites,
                    allowAIProviderWebsites: appState.allowAIProviderWebsites,
                    appearanceMode: appState.appearanceMode,
                    accentColorIndex: appState.accentColorIndex,
                    launchAtLoginEnabled: appState.launchAtLoginStatus()
                )
            },
            cancellables: &cancellables
        ) { [weak self] _ in
            self?.reloadSettings()
        }

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
        allowSearchEngineWebsitesSwitch.target = self
        allowSearchEngineWebsitesSwitch.action = #selector(toggleAllowSearchEngineWebsites)
        allowAIProviderWebsitesSwitch.target = self
        allowAIProviderWebsitesSwitch.action = #selector(toggleAllowAIProviderWebsites)

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
            makeToggleRow(
                title: "Allow Search Engines",
                descriptionLabel: makeDescriptionLabel("Always allow popular search websites while blocking."),
                toggle: allowSearchEngineWebsitesSwitch
            ),
            makeToggleRow(
                title: "Allow AI Providers",
                descriptionLabel: makeDescriptionLabel("Always allow popular AI provider websites while blocking."),
                toggle: allowAIProviderWebsitesSwitch
            ),
        ].forEach { section.addArrangedSubview($0) }
        return section
    }

    private func makeAppearanceSection() -> NSView {
        let section = makeCardSection()
        if appearanceModeControl == nil {
            let control = AppKitSelectionButtonGroup(
                options: [
                    AppKitSelectionButtonOption(title: "System", value: AppearanceMode.system),
                    AppKitSelectionButtonOption(title: "Light", value: AppearanceMode.light),
                    AppKitSelectionButtonOption(title: "Dark", value: AppearanceMode.dark),
                ],
                selectedValue: appState.appearanceMode,
                accentColor: FocusColor.nsColor(for: appState.accentColorIndex)
            )
            control.onSelection = { [weak self] mode in
                self?.appState.appearanceMode = mode
            }
            appearanceModeControl = control
        }

        if let appearanceModeControl {
            section.addArrangedSubview(appearanceModeControl)
        }

        let colorsRow = makeAppKitHorizontalRow(
            views: [],
            alignment: .centerY,
            spacing: 12
        )
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
        let versionLabel = NSTextField(labelWithString: "1.0.0")
        versionLabel.textColor = .secondaryLabelColor
        let row = makeAppKitHorizontalRow(
            views: [NSTextField(labelWithString: "Version"), NSView(), versionLabel],
            alignment: .centerY,
            spacing: 8
        )
        section.addArrangedSubview(row)
        return section
    }

    private func makeCardSection() -> NSStackView {
        let section = AppKitCardStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 12
        section.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
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
        toggle: NSView
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let labelStack = makeAppKitVerticalStack(
            views: [],
            alignment: .leading,
            spacing: 4
        )
        labelStack.addArrangedSubview(titleLabel)
        if let descriptionLabel {
            labelStack.addArrangedSubview(descriptionLabel)
        }

        let row = makeAppKitHorizontalRow(
            views: [labelStack, NSView(), toggle],
            alignment: .centerY,
            spacing: 12
        )
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
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        allToggleControls.forEach { $0.accentColor = accentColor }
        appearanceModeControl?.accentColor = accentColor
        appearanceModeControl?.selectedValue = appState.appearanceMode

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
        allowSearchEngineWebsitesSwitch.state = appState.allowSearchEngineWebsites ? .on : .off
        allowAIProviderWebsitesSwitch.state = appState.allowAIProviderWebsites ? .on : .off

        for (index, button) in accentButtons.enumerated() {
            button.layer?.borderWidth = appState.accentColorIndex == index ? 2 : 0
            button.layer?.borderColor = NSColor.labelColor.cgColor
        }

        scrollContainer.needsLayout = true
    }

    private var allToggleControls: [AppKitToggleSwitch] {
        [
            strictToggle,
            weekStartsMondaySwitch,
            calendarIntegrationSwitch,
            calendarImportsSwitch,
            launchAtLoginSwitch,
            blockNewTabsSwitch,
            blockDeveloperHostsSwitch,
            blockLocalNetworkHostsSwitch,
            allowSearchEngineWebsitesSwitch,
            allowAIProviderWebsitesSwitch,
        ]
    }

    @objc
    private func toggleStrictMode() {
        appState.isUnblockable = strictToggle.state == .on
    }

    @objc
    private func disableStrictMode() {
        let alert = Self.makeStrictModeAlert()
        alert.messageText = "Emergency Unlock"
        alert.informativeText = "Type the phrase exactly to disable Unblockable Mode:\n\n\"\(AppState.challengePhrase)\""
        let input = NSTextField(string: "")
        input.placeholderString = "Type the phrase exactly"
        input.frame = CGRect(x: 0, y: 0, width: 420, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")
        let response = Self.runStrictModeAlert(alert)
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
        guard appState.calendarProvider.isAuthorized else {
            appState.calendarProvider.requestAccess()
            scheduleCalendarPermissionFallbackIfNeeded()
            return
        }
        appState.resyncImportedCalendarSchedules()
    }

    private func scheduleCalendarPermissionFallbackIfNeeded() {
        guard pendingCalendarPermissionFallback == false else { return }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            presentCalendarPermissionAlert()
            return
        }
        pendingCalendarPermissionFallback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.calendarPermissionFallbackDelay) { [weak self] in
            guard let self else { return }
            self.pendingCalendarPermissionFallback = false
            guard self.appState.calendarProvider.isAuthorized == false else { return }
            self.presentCalendarPermissionAlert()
        }
    }

    private func presentCalendarPermissionAlert() {
        let alert = Self.makeCalendarPermissionAlert()
        alert.messageText = "Calendar Access Needed"
        alert.informativeText =
            "Free could not access your calendars. Allow access in System Settings > Privacy & Security > Calendars."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if Self.runCalendarPermissionAlert(alert) == .alertFirstButtonReturn {
            Self.openCalendarPrivacySettings()
        }
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
    private func toggleAllowSearchEngineWebsites() {
        appState.allowSearchEngineWebsites = allowSearchEngineWebsitesSwitch.state == .on
    }

    @objc
    private func toggleAllowAIProviderWebsites() {
        appState.allowAIProviderWebsites = allowAIProviderWebsitesSwitch.state == .on
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
    var appearanceSelectionColorForTesting: NSColor? { appearanceModeControl?.selectedButtonTintColor }

    func selectAccentColorForTesting(index: Int) {
        let button = NSButton()
        button.tag = index
        selectAccentColor(button)
        reloadSettings()
    }

    func disableStrictModeForTesting(phrase: String) {
        _ = appState.disableUnblockableWithChallenge(phrase: phrase)
        reloadSettings()
    }

    func setLaunchAtLoginForTesting(_ enabled: Bool) {
        launchAtLoginSwitch.state = enabled ? .on : .off
        toggleLaunchAtLogin()
    }

    func setStrictModeForTesting(_ enabled: Bool) {
        strictToggle.state = enabled ? .on : .off
        toggleStrictMode()
        reloadSettings()
    }

    func setWeekStartsMondayForTesting(_ enabled: Bool) {
        weekStartsMondaySwitch.state = enabled ? .on : .off
        toggleWeekStartsMonday()
        reloadSettings()
    }

    func setCalendarIntegrationForTesting(_ enabled: Bool) {
        calendarIntegrationSwitch.state = enabled ? .on : .off
        toggleCalendarIntegration()
        reloadSettings()
    }

    func setCalendarImportsForTesting(_ enabled: Bool) {
        calendarImportsSwitch.state = enabled ? .on : .off
        toggleCalendarImports()
        reloadSettings()
    }

    func resyncImportedSchedulesForTesting() {
        resyncImportedSchedules()
    }

    func setBlockNewTabsForTesting(_ enabled: Bool) {
        blockNewTabsSwitch.state = enabled ? .on : .off
        toggleBlockNewTabs()
        reloadSettings()
    }

    func setBlockDeveloperHostsForTesting(_ enabled: Bool) {
        blockDeveloperHostsSwitch.state = enabled ? .on : .off
        toggleBlockDeveloperHosts()
        reloadSettings()
    }

    func setBlockLocalNetworkHostsForTesting(_ enabled: Bool) {
        blockLocalNetworkHostsSwitch.state = enabled ? .on : .off
        toggleBlockLocalNetworkHosts()
        reloadSettings()
    }

    func setAllowSearchEngineWebsitesForTesting(_ enabled: Bool) {
        allowSearchEngineWebsitesSwitch.state = enabled ? .on : .off
        toggleAllowSearchEngineWebsites()
        reloadSettings()
    }

    func setAllowAIProviderWebsitesForTesting(_ enabled: Bool) {
        allowAIProviderWebsitesSwitch.state = enabled ? .on : .off
        toggleAllowAIProviderWebsites()
        reloadSettings()
    }

    func selectAppearanceModeForTesting(_ mode: AppearanceMode) {
        appearanceModeControl?.onSelection?(mode)
        appearanceModeControl?.selectedValue = mode
        reloadSettings()
    }

    static func resetStrictModeAlertHooksForTesting() {
        makeStrictModeAlert = { NSAlert() }
        runStrictModeAlert = { alert in
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                return .alertSecondButtonReturn
            }
            return alert.runModal()
        }
        makeCalendarPermissionAlert = { NSAlert() }
        runCalendarPermissionAlert = { alert in
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                return .alertSecondButtonReturn
            }
            return alert.runModal()
        }
        openCalendarPrivacySettings = {
            guard
                let url = URL(
                    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            else { return }
            NSWorkspace.shared.open(url)
        }
        calendarPermissionFallbackDelay = 0.6
    }

    func invokeDisableStrictModeModalForTesting() {
        disableStrictMode()
        reloadSettings()
    }

    func invokeCalendarPermissionAlertForTesting() {
        presentCalendarPermissionAlert()
    }
}
