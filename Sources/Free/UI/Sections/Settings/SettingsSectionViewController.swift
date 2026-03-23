import AppKit
import Combine

final class SettingsSectionViewController: NSViewController {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse
    typealias CalendarSettingsOpener = () -> Void
    typealias URLOpener = (URL) -> Void
    typealias AsyncAfterScheduler = (TimeInterval, @escaping () -> Void) -> Void
    typealias TestProcessDetector = () -> Bool

    private static func defaultMakeStrictModeAlert() -> NSAlert { NSAlert() }
    private static func defaultRunStrictModeAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }
    private static func defaultMakeCalendarPermissionAlert() -> NSAlert { NSAlert() }
    private static func defaultRunCalendarPermissionAlert(
        _ alert: NSAlert
    ) -> NSApplication.ModalResponse {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }
    private static func defaultWorkspaceURLOpener(_ url: URL) {
        if let injectedWorkspaceURLOpener {
            injectedWorkspaceURLOpener(url)
            return
        }
        platformWorkspaceURLOpener(url)
    }
    private static func defaultScheduleAfter(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private static func defaultOpenCalendarPrivacySettings() {
        openCalendarPrivacySettingsIfPossible(
            urlString: calendarPrivacySettingsURLString,
            openURL: workspaceURLOpener
        )
    }

    static var makeStrictModeAlert: AlertFactory = defaultMakeStrictModeAlert
    static var runStrictModeAlert: AlertRunner = defaultRunStrictModeAlert
    private static var _makeCalendarPermissionAlert: AlertFactory?
    private static var _runCalendarPermissionAlert: AlertRunner?
    private static var _platformWorkspaceURLOpener: URLOpener?
    private static var _workspaceURLOpener: URLOpener?
    private static var _workspaceNativeOpenURLOpener: URLOpener?
    private static var _scheduleAfter: AsyncAfterScheduler?
    private static var _openCalendarPrivacySettings: CalendarSettingsOpener?
    private static var _isRunningInTestProcess: TestProcessDetector?
    private static var _nativeWorkspaceURLOpener: URLOpener?
    static var makeCalendarPermissionAlert: AlertFactory {
        get { _makeCalendarPermissionAlert ?? defaultMakeCalendarPermissionAlert }
        set { _makeCalendarPermissionAlert = newValue }
    }
    static var runCalendarPermissionAlert: AlertRunner {
        get { _runCalendarPermissionAlert ?? defaultRunCalendarPermissionAlert }
        set { _runCalendarPermissionAlert = newValue }
    }
    static var injectedWorkspaceURLOpener: URLOpener?
    static var isRunningInTestProcess: TestProcessDetector {
        get { _isRunningInTestProcess ?? { AppDelegate.isRunningInTestProcess() } }
        set { _isRunningInTestProcess = newValue }
    }
    static var nativeWorkspaceURLOpener: URLOpener {
        get { _nativeWorkspaceURLOpener ?? { url in workspaceNativeOpenURLOpener(url) } }
        set { _nativeWorkspaceURLOpener = newValue }
    }
    private static var workspaceNativeOpenURLOpener: URLOpener {
        _workspaceNativeOpenURLOpener ?? AppKitSystemBridges.openURL
    }
    static var platformWorkspaceURLOpener: URLOpener {
        get {
            _platformWorkspaceURLOpener ?? { url in
                if url.scheme == "x-free-test" || isRunningInTestProcess() {
                    return
                }
                nativeWorkspaceURLOpener(url)
            }
        }
        set { _platformWorkspaceURLOpener = newValue }
    }
    static var calendarPrivacySettingsURLString =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    static var workspaceURLOpener: URLOpener {
        get { _workspaceURLOpener ?? defaultWorkspaceURLOpener }
        set { _workspaceURLOpener = newValue }
    }
    static var scheduleAfter: AsyncAfterScheduler {
        get { _scheduleAfter ?? defaultScheduleAfter }
        set { _scheduleAfter = newValue }
    }
    static var openCalendarPrivacySettings: CalendarSettingsOpener {
        get { _openCalendarPrivacySettings ?? defaultOpenCalendarPrivacySettings }
        set { _openCalendarPrivacySettings = newValue }
    }
    static var calendarPermissionFallbackDelay: TimeInterval = 0.6

    private static func openCalendarPrivacySettingsIfPossible(
        urlString: String,
        openURL: URLOpener
    ) {
        guard let url = URL(string: urlString), url.scheme != nil else { return }
        openURL(url)
    }

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
        let cursorFluidAnimationEnabled: Bool
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
            cursorFluidAnimationEnabled: true,
            launchAtLoginEnabled: false
        )
    }

    private let appState: AppState
    private let scrollContainer = VerticalStackScrollContainer()
    private var cancellables: Set<AnyCancellable> = []

    private let strictSection = AppKitCardStackView()
    private let strictToggle = AppKitToggleSwitch()
    private let strictDescriptionLabel = NSTextField(
        labelWithString: "When active, you cannot disable Focus Mode.")
    private let strictDisableButton = NSButton(title: "Disable...", target: nil, action: nil)
    private let strictStatusLabel = NSTextField(labelWithString: "Active and Locking Focus Mode.")
    private let weekStartsMondaySwitch = AppKitToggleSwitch()
    private let calendarIntegrationSwitch = AppKitToggleSwitch()
    private let calendarImportsSwitch = AppKitToggleSwitch()
    private let resyncButton = NSButton(
        title: "Resync Imported Schedules", target: nil, action: nil)
    private let launchAtLoginSwitch = AppKitToggleSwitch()
    private let blockNewTabsSwitch = AppKitToggleSwitch()
    private let blockDeveloperHostsSwitch = AppKitToggleSwitch()
    private let blockLocalNetworkHostsSwitch = AppKitToggleSwitch()
    private let allowSearchEngineWebsitesSwitch = AppKitToggleSwitch()
    private let allowAIProviderWebsitesSwitch = AppKitToggleSwitch()
    private let cursorFluidAnimationSwitch = AppKitToggleSwitch()
    private let browserLockNotice = NSTextField(
        wrappingLabelWithString:
            "Unblockable mode is active. Browser blocking settings cannot be changed."
    )
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
        scrollContainer.maxContentWidth = 980
        scrollContainer.stackView.spacing = 18
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

        addSectionBlock(title: "Strict Mode", content: makeStrictSection())
        addSectionBlock(title: "Startup", content: makeStartupSection())
        addSectionBlock(title: "Browser", content: makeBrowserSection())
        addSectionBlock(title: "Appearance", content: makeAppearanceSection())
        addSectionBlock(title: "About", content: makeAboutSection())
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
                    cursorFluidAnimationEnabled: appState.cursorFluidAnimationEnabled,
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
        section.widthAnchor.constraint(equalTo: scrollContainer.stackView.widthAnchor).isActive =
            true
    }

    private func addSectionBlock(title: String, content: NSView) {
        let heading = makeSectionTitle(title)
        let block = makeAppKitVerticalStack(
            views: [heading, content],
            alignment: .leading,
            spacing: 8
        )
        content.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalTo: block.widthAnchor).isActive = true
        addFullWidthSection(block)
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

    private func makeStartupSection() -> NSView {
        let section = makeCardSection()
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(toggleLaunchAtLogin)
        section.addArrangedSubview(
            makeToggleRow(
                title: "Launch at Login",
                descriptionLabel: makeDescriptionLabel(
                    "Start Free automatically when you sign in."),
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
                descriptionLabel: makeDescriptionLabel(
                    "When off, blank/new-tab pages are allowed by default."),
                toggle: blockNewTabsSwitch
            ),
            makeToggleRow(
                title: "Block Localhost/Dev Ports",
                descriptionLabel: makeDescriptionLabel(
                    "When off, localhost and loopback hosts are allowed."),
                toggle: blockDeveloperHostsSwitch
            ),
            makeToggleRow(
                title: "Block Local Network IPs",
                descriptionLabel: makeDescriptionLabel(
                    "When off, private-network IPs are allowed."),
                toggle: blockLocalNetworkHostsSwitch
            ),
            makeToggleRow(
                title: "Allow Search Engines",
                descriptionLabel: makeDescriptionLabel(
                    "Always allow popular search websites while blocking."),
                toggle: allowSearchEngineWebsitesSwitch
            ),
            makeToggleRow(
                title: "Allow AI Providers",
                descriptionLabel: makeDescriptionLabel(
                    "Always allow popular AI provider websites while blocking."),
                toggle: allowAIProviderWebsitesSwitch
            ),
            browserLockNotice,
        ].forEach { section.addArrangedSubview($0) }
        browserLockNotice.font = .systemFont(ofSize: 13, weight: .medium)
        browserLockNotice.textColor = .systemOrange
        browserLockNotice.isHidden = true
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

        cursorFluidAnimationSwitch.target = self
        cursorFluidAnimationSwitch.action = #selector(toggleCursorFluidAnimation)
        section.addArrangedSubview(
            makeToggleRow(
                title: "Cursor Fluid Animation",
                descriptionLabel: makeDescriptionLabel(
                    "Show or hide the cursor fluid overlay effect."),
                toggle: cursorFluidAnimationSwitch
            )
        )

        let colorsRow = makeAppKitHorizontalRow(
            views: [],
            alignment: .centerY,
            spacing: 12
        )
        accentButtons = (0..<FocusColor.accentOptionCount).map { index in
            let button = NSButton(title: "", target: self, action: #selector(selectAccentColor(_:)))
            button.tag = index
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 12
            button.layer?.masksToBounds = true
            configureAccentButtonAppearance(button, index: index)
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
        calendarImportsSwitch.isEnabled =
            !appState.isStrictActive && appState.calendarIntegrationEnabled
        resyncButton.isEnabled = appState.calendarIntegrationEnabled

        launchAtLoginSwitch.state = appState.launchAtLoginStatus() ? .on : .off
        blockNewTabsSwitch.state = appState.blockNewTabs ? .on : .off
        blockDeveloperHostsSwitch.state = appState.blockDeveloperHosts ? .on : .off
        blockLocalNetworkHostsSwitch.state = appState.blockLocalNetworkHosts ? .on : .off
        allowSearchEngineWebsitesSwitch.state = appState.allowSearchEngineWebsites ? .on : .off
        allowAIProviderWebsitesSwitch.state = appState.allowAIProviderWebsites ? .on : .off
        cursorFluidAnimationSwitch.state = appState.cursorFluidAnimationEnabled ? .on : .off
        let browserLocked = appState.isUnblockable
        blockNewTabsSwitch.isEnabled = !browserLocked
        blockDeveloperHostsSwitch.isEnabled = !browserLocked
        blockLocalNetworkHostsSwitch.isEnabled = !browserLocked
        allowSearchEngineWebsitesSwitch.isEnabled = !browserLocked
        allowAIProviderWebsitesSwitch.isEnabled = !browserLocked
        browserLockNotice.isHidden = !browserLocked

        for button in accentButtons {
            button.layer?.borderWidth = appState.accentColorIndex == button.tag ? 2 : 0
            button.layer?.borderColor = NSColor.labelColor.cgColor
        }

        scrollContainer.needsLayout = true
    }

    private func configureAccentButtonAppearance(_ button: NSButton, index: Int) {
        button.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        if FocusColor.isRainbowAccentIndex(index) {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            let gradient = CAGradientLayer()
            gradient.colors = [
                NSColor.systemRed.cgColor,
                NSColor.systemOrange.cgColor,
                NSColor.systemYellow.cgColor,
                NSColor.systemGreen.cgColor,
                NSColor.systemTeal.cgColor,
                NSColor.systemBlue.cgColor,
                NSColor.systemPurple.cgColor,
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.cornerRadius = 12
            gradient.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            button.layer?.addSublayer(gradient)
        } else {
            button.layer?.backgroundColor = FocusColor.nsColor(for: index).cgColor
        }
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
            cursorFluidAnimationSwitch,
        ]
    }

    @objc
    private func toggleStrictMode() {
        let wantsEnabled = strictToggle.state == .on
        if wantsEnabled {
            appState.isUnblockable = true
        } else {
            guard appState.isUnblockable else { return }
            disableStrictMode()
        }
        // Keep control state aligned even when unlock is cancelled or phrase is wrong.
        strictToggle.state = appState.isUnblockable ? .on : .off
    }

    @objc
    private func disableStrictMode() {
        let alert = Self.makeStrictModeAlert()
        alert.messageText = "Emergency Unlock"
        alert.informativeText = ""
        let (accessoryView, input) = makeStrictModeUnlockAccessoryView()
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")
        let response = Self.runStrictModeAlert(alert)
        if response == .alertFirstButtonReturn {
            _ = appState.disableUnblockableWithChallenge(phrase: input.stringValue)
        }
    }

    private func makeStrictModeUnlockAccessoryView() -> (NSView, NSTextField) {
        let containerWidth: CGFloat = 340
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 120))
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let quote = NSTextField(
            wrappingLabelWithString:
                "The moment you give up is the moment you let someone else win. — Kobe Bryant")
        quote.font = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 13, weight: .heavy), toHaveTrait: .italicFontMask)
        quote.textColor = FocusColor.nsColor(for: appState.accentColorIndex)
        quote.alignment = .center
        quote.translatesAutoresizingMaskIntoConstraints = false

        let instruction = NSTextField(
            wrappingLabelWithString: "Type the phrase")
        instruction.font = .systemFont(ofSize: 13, weight: .semibold)
        instruction.textColor = .labelColor
        instruction.lineBreakMode = .byWordWrapping
        instruction.translatesAutoresizingMaskIntoConstraints = false

        let phrase = NSTextField(
            wrappingLabelWithString:
                "\"\(AppState.challengePhrase)\""
        )
        phrase.font = .systemFont(ofSize: 13)
        phrase.textColor = .secondaryLabelColor
        phrase.lineBreakMode = .byWordWrapping
        phrase.translatesAutoresizingMaskIntoConstraints = false
        let instruction2 = NSTextField(
            wrappingLabelWithString: "to disable Unblockable Mode:")
        instruction2.font = .systemFont(ofSize: 13, weight: .semibold)
        instruction2.textColor = .labelColor
        instruction2.lineBreakMode = .byWordWrapping
        instruction2.translatesAutoresizingMaskIntoConstraints = false

        let input = NSTextField(string: "")
        input.placeholderString = "Type the phrase..."
        input.translatesAutoresizingMaskIntoConstraints = false
        input.controlSize = .regular

        stack.addArrangedSubview(quote)
        let hStack = NSStackView(views: [instruction, phrase, instruction2])
        hStack.orientation = .horizontal
        hStack.spacing = 4
        hStack.alignment = .centerY
        hStack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(hStack)
        stack.addArrangedSubview(input)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            quote.widthAnchor.constraint(equalTo: container.widthAnchor),
            hStack.widthAnchor.constraint(equalTo: container.widthAnchor),
            input.widthAnchor.constraint(equalTo: container.widthAnchor),
            input.heightAnchor.constraint(equalToConstant: 24),
        ])
        container.layoutSubtreeIfNeeded()
        return (container, input)
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

        Self.scheduleAfter(Self.calendarPermissionFallbackDelay) { [weak self] in
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
        guard !appState.isUnblockable else { return }
        appState.blockNewTabs = blockNewTabsSwitch.state == .on
    }

    @objc
    private func toggleBlockDeveloperHosts() {
        guard !appState.isUnblockable else { return }
        appState.blockDeveloperHosts = blockDeveloperHostsSwitch.state == .on
    }

    @objc
    private func toggleBlockLocalNetworkHosts() {
        guard !appState.isUnblockable else { return }
        appState.blockLocalNetworkHosts = blockLocalNetworkHostsSwitch.state == .on
    }

    @objc
    private func toggleAllowSearchEngineWebsites() {
        guard !appState.isUnblockable else { return }
        appState.allowSearchEngineWebsites = allowSearchEngineWebsitesSwitch.state == .on
    }

    @objc
    private func toggleAllowAIProviderWebsites() {
        guard !appState.isUnblockable else { return }
        appState.allowAIProviderWebsites = allowAIProviderWebsitesSwitch.state == .on
    }

    @objc
    private func toggleCursorFluidAnimation() {
        appState.cursorFluidAnimationEnabled = cursorFluidAnimationSwitch.state == .on
    }

    @objc
    private func selectAccentColor(_ sender: NSButton) {
        appState.accentColorIndex = sender.tag
    }
}

extension SettingsSectionViewController {
    var shouldShowStrictDisableButtonForTesting: Bool { !strictDisableButton.isHidden }
    var calendarControlsLockedForTesting: Bool { !calendarIntegrationSwitch.isEnabled }
    var browserControlsLockedForTesting: Bool { !blockNewTabsSwitch.isEnabled }
    var launchAtLoginEnabledForTesting: Bool { launchAtLoginSwitch.state == .on }
    var appearanceSelectionColorForTesting: NSColor? {
        appearanceModeControl?.selectedButtonTintColor
    }

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

    func setCursorFluidAnimationForTesting(_ enabled: Bool) {
        cursorFluidAnimationSwitch.state = enabled ? .on : .off
        toggleCursorFluidAnimation()
        reloadSettings()
    }

    func reconfigureAccentButtonForTesting(index: Int) {
        guard accentButtons.indices.contains(index) else { return }
        configureAccentButtonAppearance(accentButtons[index], index: index)
    }

    func selectAppearanceModeForTesting(_ mode: AppearanceMode) {
        appearanceModeControl?.onSelection?(mode)
        appearanceModeControl?.selectedValue = mode
        reloadSettings()
    }

    static func resetStrictModeAlertHooksForTesting() {
        calendarPrivacySettingsURLString =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        injectedWorkspaceURLOpener = nil
        _platformWorkspaceURLOpener = nil
        _isRunningInTestProcess = nil
        _nativeWorkspaceURLOpener = nil
        _workspaceNativeOpenURLOpener = nil
        _workspaceURLOpener = nil
        _scheduleAfter = nil
        makeStrictModeAlert = defaultMakeStrictModeAlert
        runStrictModeAlert = defaultRunStrictModeAlert
        _makeCalendarPermissionAlert = nil
        _runCalendarPermissionAlert = nil
        _openCalendarPrivacySettings = nil
        calendarPermissionFallbackDelay = 0.6
    }

    func invokeDisableStrictModeModalForTesting() {
        disableStrictMode()
        reloadSettings()
    }

    func invokeCalendarPermissionAlertForTesting() {
        presentCalendarPermissionAlert()
    }

    static func setWorkspaceNativeOpenURLOpenerForTesting(_ opener: URLOpener?) {
        _workspaceNativeOpenURLOpener = opener
    }
}
