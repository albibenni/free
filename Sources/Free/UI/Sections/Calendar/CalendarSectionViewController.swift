import AppKit
import Combine

final class CalendarSectionViewController: NSViewController {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse
    typealias URLOpener = (URL) -> Void
    typealias AsyncAfterScheduler = (TimeInterval, @escaping () -> Void) -> Void
    typealias TestProcessDetector = () -> Bool

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
        platformWorkspaceURLOpener(url)
    }
    private static func defaultPlatformWorkspaceURLOpener(_ url: URL) {
        if url.scheme == "x-free-test" || isRunningInTestProcess() {
            return
        }
        nativeWorkspaceURLOpener(url)
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
    private static func openCalendarPrivacySettingsIfPossible(
        urlString: String,
        openURL: URLOpener
    ) {
        guard let url = URL(string: urlString), url.scheme != nil else { return }
        openURL(url)
    }

    private static var _makeCalendarPermissionAlert: AlertFactory?
    private static var _runCalendarPermissionAlert: AlertRunner?
    private static var _platformWorkspaceURLOpener: URLOpener?
    private static var _workspaceURLOpener: URLOpener?
    private static var _scheduleAfter: AsyncAfterScheduler?
    private static var _openCalendarPrivacySettings: (() -> Void)?
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
    static var platformWorkspaceURLOpener: URLOpener {
        get { _platformWorkspaceURLOpener ?? defaultPlatformWorkspaceURLOpener }
        set { _platformWorkspaceURLOpener = newValue }
    }
    static var isRunningInTestProcess: TestProcessDetector {
        get { _isRunningInTestProcess ?? { AppDelegate.isRunningInTestProcess() } }
        set { _isRunningInTestProcess = newValue }
    }
    static var nativeWorkspaceURLOpener: URLOpener {
        get { _nativeWorkspaceURLOpener ?? { url in NSWorkspace.shared.open(url) } }
        set { _nativeWorkspaceURLOpener = newValue }
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
    static var openCalendarPrivacySettings: () -> Void {
        get { _openCalendarPrivacySettings ?? defaultOpenCalendarPrivacySettings }
        set { _openCalendarPrivacySettings = newValue }
    }
    static var calendarPermissionFallbackDelay: TimeInterval = 0.6

    private struct ObservationSignature: Equatable {
        let weekStartsOnMonday: Bool
        let calendarIntegrationEnabled: Bool
        let isStrictActive: Bool
        let calendarImportFocusTitleRules: [String]
        let calendarImportBreakTitleRules: [String]
        let calendarImportedScheduleRuleSetId: UUID?
        let ruleSetsSignature: [String]
    }

    private let appState: AppState
    private let scrollContainer = VerticalStackScrollContainer()
    private var cancellables: Set<AnyCancellable> = []

    private let weekStartsMondaySwitch = AppKitToggleSwitch()
    private let calendarIntegrationSwitch = AppKitToggleSwitch()
    private let importedRuleSetScrollView = VerticalStackScrollContainer(
        contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    )
    private var importedActiveRuleSetButton: AppKitSelectableRowButton?
    private var importedRuleSetButtons: [UUID: AppKitSelectableRowButton] = [:]
    private let resyncButton = ActionButton(title: "Resync Imported Schedules")
    private let integrationNotice = NSTextField(
        wrappingLabelWithString: "Enable Calendar Integration to use calendar title rules."
    )
    private let strictLockNotice = NSTextField(
        wrappingLabelWithString:
            StrictModeCopy.active(
                withSuffix: " A challenge phrase is required to change Calendar integration settings."
            )
    )
    private let focusRuleField = VerticallyCenteredTextField(string: "")
    private let breakRuleField = VerticallyCenteredTextField(string: "")
    private let focusRulesTableView = NSTableView()
    private let breakRulesTableView = NSTableView()
    private let focusRulesScrollView = NSScrollView()
    private let breakRulesScrollView = NSScrollView()
    private let addFocusRuleButton = ActionButton(title: "Add")
    private let addBreakRuleButton = ActionButton(title: "Add")
    private let removeFocusRuleButton = ActionButton(title: "Remove Selected")
    private let removeBreakRuleButton = ActionButton(title: "Remove Selected")
    private let focusRulesTableController = AllowedWebsitesRulesTableController()
    private let breakRulesTableController = AllowedWebsitesRulesTableController()
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

        let titleLabel = NSTextField(labelWithString: "Calendar")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        scrollContainer.stackView.addArrangedSubview(titleLabel)

        let integrationSection = makeCardSection()
        weekStartsMondaySwitch.target = self
        weekStartsMondaySwitch.action = #selector(toggleWeekStartsMonday)
        calendarIntegrationSwitch.target = self
        calendarIntegrationSwitch.action = #selector(toggleCalendarIntegration)
        resyncButton.target = self
        resyncButton.action = #selector(resyncImportedSchedules)
        resyncButton.translatesAutoresizingMaskIntoConstraints = false
        resyncButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let integrationRows: [NSView] = [
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
            strictLockNotice,
            makeImportedRuleSetRow(),
            makeAppKitDividerView(),
            resyncButton,
        ]
        integrationRows.forEach {
            integrationSection.addArrangedSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: integrationSection.widthAnchor).isActive = true
        }
        addSectionBlock(title: "Integration", content: integrationSection)

        let section = makeCardSection()
        let focusRuleRow = makeRuleListRow(
            title: "Focus Title Rules",
            description: "Match any rule in this list to import as Focus.",
            inputField: focusRuleField,
            addButton: addFocusRuleButton,
            removeButton: removeFocusRuleButton,
            tableView: focusRulesTableView,
            tableScrollView: focusRulesScrollView
        )
        let breakRuleRow = makeRuleListRow(
            title: "Break Title Rules",
            description: "Match any rule in this list to import as Break.",
            inputField: breakRuleField,
            addButton: addBreakRuleButton,
            removeButton: removeBreakRuleButton,
            tableView: breakRulesTableView,
            tableScrollView: breakRulesScrollView
        )
        [integrationNotice, focusRuleRow, breakRuleRow].forEach {
            section.addArrangedSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        }
        addSectionBlock(title: "Import Rules", content: section)

        configureRuleField(
            focusRuleField,
            placeholder: "Add focus title rule...",
            action: #selector(addFocusRuleFromField(_:))
        )
        configureRuleField(
            breakRuleField,
            placeholder: "Add break title rule...",
            action: #selector(addBreakRuleFromField(_:))
        )
        addFocusRuleButton.target = self
        addFocusRuleButton.action = #selector(addFocusRule)
        addBreakRuleButton.target = self
        addBreakRuleButton.action = #selector(addBreakRule)
        removeFocusRuleButton.target = self
        removeFocusRuleButton.action = #selector(removeSelectedFocusRule)
        removeBreakRuleButton.target = self
        removeBreakRuleButton.action = #selector(removeSelectedBreakRule)

        configureRulesTable(
            focusRulesTableView,
            in: focusRulesScrollView,
            selectionAction: #selector(handleFocusSelectionChange)
        )
        configureRulesTable(
            breakRulesTableView,
            in: breakRulesScrollView,
            selectionAction: #selector(handleBreakSelectionChange)
        )

        focusRulesTableController.numberOfRules = { [weak self] in
            self?.appState.calendarImportFocusTitleRules.count ?? 0
        }
        focusRulesTableController.ruleAt = { [weak self] row in
            guard let self else { return nil }
            guard self.appState.calendarImportFocusTitleRules.indices.contains(row) else { return nil }
            return self.appState.calendarImportFocusTitleRules[row]
        }
        focusRulesTableView.dataSource = focusRulesTableController
        focusRulesTableView.delegate = focusRulesTableController

        breakRulesTableController.numberOfRules = { [weak self] in
            self?.appState.calendarImportBreakTitleRules.count ?? 0
        }
        breakRulesTableController.ruleAt = { [weak self] row in
            guard let self else { return nil }
            guard self.appState.calendarImportBreakTitleRules.indices.contains(row) else { return nil }
            return self.appState.calendarImportBreakTitleRules[row]
        }
        breakRulesTableView.dataSource = breakRulesTableController
        breakRulesTableView.delegate = breakRulesTableController

        integrationNotice.font = .systemFont(ofSize: 12, weight: .medium)
        integrationNotice.textColor = .secondaryLabelColor
        strictLockNotice.font = .systemFont(ofSize: 13, weight: .medium)
        strictLockNotice.textColor = .systemOrange
        strictLockNotice.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let appState = self.appState
        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.calendarPublisher(appState: appState),
            signature: {
                ObservationSignature(
                    weekStartsOnMonday: appState.weekStartsOnMonday,
                    calendarIntegrationEnabled: appState.calendarIntegrationEnabled,
                    isStrictActive: appState.isStrictActive,
                    calendarImportFocusTitleRules: appState.calendarImportFocusTitleRules,
                    calendarImportBreakTitleRules: appState.calendarImportBreakTitleRules,
                    calendarImportedScheduleRuleSetId: appState.calendarImportedScheduleRuleSetId,
                    ruleSetsSignature: appState.ruleSets.map { "\($0.id.uuidString)|\($0.name)" }
                )
            },
            cancellables: &cancellables
        ) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    private func addFullWidthSection(_ section: NSView) {
        scrollContainer.stackView.addArrangedSubview(section)
        section.translatesAutoresizingMaskIntoConstraints = false
        section.widthAnchor.constraint(equalTo: scrollContainer.stackView.widthAnchor).isActive = true
    }

    private func addSectionBlock(title: String, content: NSView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        let block = makeAppKitVerticalStack(
            views: [label, content],
            alignment: .leading,
            spacing: 8
        )
        content.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalTo: block.widthAnchor).isActive = true
        addFullWidthSection(block)
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

    private func configureRuleField(
        _ textField: NSTextField,
        placeholder: String,
        action: Selector
    ) {
        textField.placeholderString = placeholder
        applyAppKitInputFieldStyle(textField)
        textField.target = self
        textField.action = action
        if let cell = textField.cell as? NSTextFieldCell {
            cell.sendsActionOnEndEditing = true
        }
        textField.controlSize = .regular
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func configureRulesTable(
        _ tableView: NSTableView,
        in scrollView: NSScrollView,
        selectionAction: Selector
    ) {
        let ruleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CalendarRule"))
        ruleColumn.title = ""
        ruleColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(ruleColumn)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.target = self
        tableView.action = selectionAction
        tableView.doubleAction = selectionAction

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeImportedRuleSetRow() -> NSView {
        importedRuleSetScrollView.stackView.alignment = .width
        importedRuleSetScrollView.stackView.spacing = 6
        importedRuleSetScrollView.stackView.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        importedRuleSetScrollView.drawsBackground = false
        importedRuleSetScrollView.borderType = .noBorder
        importedRuleSetScrollView.hasVerticalScroller = true
        importedRuleSetScrollView.autohidesScrollers = true
        importedRuleSetScrollView.translatesAutoresizingMaskIntoConstraints = false
        importedRuleSetScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        importedRuleSetScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        let titleLabel = NSTextField(labelWithString: "Imported Schedule Allowed List")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let helperLabel = makeDescriptionLabel(
            "Choose which allowed list imported calendar schedules should use."
        )

        let listContainer = AppKitDynamicView()
        listContainer.backgroundColorProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.45)
        }
        listContainer.borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.62)
        }
        listContainer.borderWidthValue = 1
        listContainer.wantsLayer = true
        listContainer.layer?.cornerRadius = 10
        listContainer.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(importedRuleSetScrollView)
        NSLayoutConstraint.activate([
            importedRuleSetScrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            importedRuleSetScrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -8),
            importedRuleSetScrollView.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 8),
            importedRuleSetScrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -8),
            listContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
        ])

        let stack = makeAppKitVerticalStack(
            views: [
                titleLabel,
                helperLabel,
                listContainer,
            ],
            alignment: .leading,
            spacing: 6
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        listContainer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeToggleRow(
        title: String,
        descriptionLabel: NSTextField?,
        toggle: NSView
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let labelStack = makeAppKitVerticalStack(
            views: [],
            alignment: .leading,
            spacing: 4
        )
        labelStack.addArrangedSubview(titleLabel)
        if let descriptionLabel {
            descriptionLabel.lineBreakMode = .byTruncatingTail
            descriptionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            labelStack.addArrangedSubview(descriptionLabel)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = makeAppKitHorizontalRow(
            views: [labelStack, spacer, toggle],
            alignment: .centerY,
            spacing: 12
        )
        row.translatesAutoresizingMaskIntoConstraints = false
        labelStack.setContentCompressionResistancePriority(.required, for: .horizontal)

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

    private func makeRuleListRow(
        title: String,
        description: String,
        inputField: NSTextField,
        addButton: ActionButton,
        removeButton: ActionButton,
        tableView: NSTableView,
        tableScrollView: NSScrollView
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let descriptionLabel = makeDescriptionLabel(description)
        let inputRow = makeAppKitHorizontalRow(
            views: [inputField, addButton],
            alignment: .centerY,
            spacing: 8
        )
        let removeRow = makeAppKitHorizontalRow(
            views: [NSView(), removeButton],
            alignment: .centerY,
            spacing: 8
        )

        let listContainer = AppKitDynamicView()
        listContainer.backgroundColorProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.45)
        }
        listContainer.borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.62)
        }
        listContainer.borderWidthValue = 1
        listContainer.wantsLayer = true
        listContainer.layer?.cornerRadius = 10
        listContainer.translatesAutoresizingMaskIntoConstraints = false

        listContainer.addSubview(tableScrollView)
        NSLayoutConstraint.activate([
            tableScrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            tableScrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -8),
            tableScrollView.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 8),
            tableScrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -8),
            listContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
        ])

        let stack = makeAppKitVerticalStack(
            views: [titleLabel, descriptionLabel, inputRow, listContainer, removeRow],
            alignment: .leading,
            spacing: 8
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        addButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
        removeButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
        listContainer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        tableView.reloadData()

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func reload() {
        let enabled = appState.calendarIntegrationEnabled
        let canEditRules = canEditCalendarTitleRules
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        [weekStartsMondaySwitch, calendarIntegrationSwitch].forEach {
            $0.accentColor = accentColor
        }
        weekStartsMondaySwitch.state = appState.weekStartsOnMonday ? .on : .off
        calendarIntegrationSwitch.state = enabled ? .on : .off
        calendarIntegrationSwitch.isEnabled = true
        strictLockNotice.isHidden = !appState.isStrictActive
        resyncButton.isEnabled = enabled
        applyAppKitSecondaryButtonStyle(
            resyncButton,
            title: "Resync Imported Schedules",
            color: accentColor
        )
        reloadImportedRuleSetButtons(
            accentColor: accentColor,
            isEnabled: !appState.isStrictActive && enabled
        )
        applyAppKitListActionButtonStyle(addFocusRuleButton, title: "Add", color: accentColor)
        applyAppKitListActionButtonStyle(addBreakRuleButton, title: "Add", color: accentColor)
        applyAppKitListActionButtonStyle(
            removeFocusRuleButton,
            title: "Remove Selected",
            color: accentColor
        )
        applyAppKitListActionButtonStyle(
            removeBreakRuleButton,
            title: "Remove Selected",
            color: accentColor
        )
        integrationNotice.isHidden = enabled || appState.isStrictActive
        focusRuleField.isEnabled = canEditRules
        breakRuleField.isEnabled = canEditRules
        addFocusRuleButton.isEnabled = canEditRules
        addBreakRuleButton.isEnabled = canEditRules
        focusRulesTableView.isEnabled = canEditRules
        breakRulesTableView.isEnabled = canEditRules
        focusRulesTableView.reloadData()
        breakRulesTableView.reloadData()
        removeFocusRuleButton.isEnabled = canEditRules && focusRulesTableView.numberOfSelectedRows > 0
        removeBreakRuleButton.isEnabled = canEditRules && breakRulesTableView.numberOfSelectedRows > 0
    }

    private func reloadImportedRuleSetButtons(accentColor: NSColor, isEnabled: Bool) {
        let selectedRuleSetId = appState.calendarImportedScheduleRuleSetId
        importedRuleSetScrollView.stackView.arrangedSubviews.forEach { subview in
            importedRuleSetScrollView.stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        importedRuleSetButtons.removeAll()
        let activeButton = makeAppKitSelectableRowButton(
            title: "Use Active Allowed List",
            isSelected: selectedRuleSetId == nil,
            accentColor: accentColor
        ) { [weak self] in
            self?.setImportedScheduleRuleSet(nil)
        }
        activeButton.isEnabled = isEnabled
        importedRuleSetScrollView.stackView.addArrangedSubview(activeButton)
        activeButton.widthAnchor.constraint(equalTo: importedRuleSetScrollView.stackView.widthAnchor).isActive = true
        importedActiveRuleSetButton = activeButton

        for set in appState.ruleSets {
            let button = makeAppKitSelectableRowButton(
                title: set.name,
                isSelected: selectedRuleSetId == set.id,
                accentColor: accentColor
            ) { [weak self] in
                self?.setImportedScheduleRuleSet(set.id)
            }
            button.isEnabled = isEnabled
            importedRuleSetButtons[set.id] = button
            importedRuleSetScrollView.stackView.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: importedRuleSetScrollView.stackView.widthAnchor).isActive = true
        }
    }

    @objc
    private func toggleWeekStartsMonday() {
        appState.weekStartsOnMonday = weekStartsMondaySwitch.state == .on
    }

    @objc
    private func toggleCalendarIntegration() {
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Calendar Integration",
                action: "change the calendar integration setting",
                appState: appState
            ) else {
                calendarIntegrationSwitch.state = appState.calendarIntegrationEnabled ? .on : .off
                return
            }
        }
        appState.calendarIntegrationEnabled = calendarIntegrationSwitch.state == .on
    }

    private func setImportedScheduleRuleSet(_ ruleSetId: UUID?) {
        guard appState.calendarImportedScheduleRuleSetId != ruleSetId else { return }
        appState.calendarImportedScheduleRuleSetId = ruleSetId
    }

    @objc
    private func resyncImportedSchedules() {
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Resync Schedules",
                action: "resync imported schedules",
                appState: appState
            ) else { return }
        }
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
    private func handleFocusSelectionChange() {
        removeFocusRuleButton.isEnabled =
            canEditCalendarTitleRules && focusRulesTableView.numberOfSelectedRows > 0
    }

    @objc
    private func handleBreakSelectionChange() {
        removeBreakRuleButton.isEnabled =
            canEditCalendarTitleRules && breakRulesTableView.numberOfSelectedRows > 0
    }

    @objc
    private func addFocusRuleFromField(_ sender: NSTextField) {
        addRule(from: sender, into: \.calendarImportFocusTitleRules)
    }

    @objc
    private func addBreakRuleFromField(_ sender: NSTextField) {
        addRule(from: sender, into: \.calendarImportBreakTitleRules)
    }

    @objc
    private func addFocusRule() {
        addRule(from: focusRuleField, into: \.calendarImportFocusTitleRules)
    }

    @objc
    private func addBreakRule() {
        addRule(from: breakRuleField, into: \.calendarImportBreakTitleRules)
    }

    private func addRule(
        from field: NSTextField,
        into keyPath: ReferenceWritableKeyPath<AppState, [String]>
    ) {
        guard canEditCalendarTitleRules else { return }
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Add Calendar Rule",
                action: "add this calendar title rule",
                appState: appState
            ) else { return }
        }
        let parsed = Self.parseRules(field.stringValue)
        guard !parsed.isEmpty else { return }
        var rules = appState[keyPath: keyPath]
        for rule in parsed {
            let exists = rules.contains { $0.caseInsensitiveCompare(rule) == .orderedSame }
            if !exists {
                rules.append(rule)
            }
        }
        appState[keyPath: keyPath] = rules
        field.stringValue = ""
        reload()
    }

    @objc
    private func removeSelectedFocusRule() {
        guard canEditCalendarTitleRules else { return }
        let rows = selectedRows(in: focusRulesTableView)
        guard !rows.isEmpty else { return }
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Remove Calendar Rule",
                action: "remove this calendar title rule",
                appState: appState
            ) else { return }
        }
        appState.calendarImportFocusTitleRules = removeRules(
            at: rows,
            from: appState.calendarImportFocusTitleRules
        )
        reload()
    }

    @objc
    private func removeSelectedBreakRule() {
        guard canEditCalendarTitleRules else { return }
        let rows = selectedRows(in: breakRulesTableView)
        guard !rows.isEmpty else { return }
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Remove Calendar Rule",
                action: "remove this calendar title rule",
                appState: appState
            ) else { return }
        }
        appState.calendarImportBreakTitleRules = removeRules(
            at: rows,
            from: appState.calendarImportBreakTitleRules
        )
        reload()
    }

    private func selectedRows(in tableView: NSTableView) -> [Int] {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty else { return [] }
        return indexes.filter { $0 >= 0 }
    }

    private func removeRules(at indexes: [Int], from rules: [String]) -> [String] {
        let indexSet = Set(indexes)
        return rules.enumerated().filter { !indexSet.contains($0.offset) }.map(\.element)
    }

    private static func parseRules(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    private var canEditCalendarTitleRules: Bool {
        appState.calendarIntegrationEnabled
    }
}

extension CalendarSectionViewController {
    static func resetCalendarPermissionAlertHooksForTesting() {
        calendarPrivacySettingsURLString =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        _platformWorkspaceURLOpener = nil
        _isRunningInTestProcess = nil
        _nativeWorkspaceURLOpener = nil
        _workspaceURLOpener = nil
        _scheduleAfter = nil
        _makeCalendarPermissionAlert = nil
        _runCalendarPermissionAlert = nil
        _openCalendarPrivacySettings = nil
        calendarPermissionFallbackDelay = 0.6
    }

    func setWeekStartsMondayForTesting(_ enabled: Bool) {
        weekStartsMondaySwitch.state = enabled ? .on : .off
        toggleWeekStartsMonday()
        reload()
    }

    func setCalendarIntegrationForTesting(_ enabled: Bool) {
        calendarIntegrationSwitch.state = enabled ? .on : .off
        toggleCalendarIntegration()
        reload()
    }

    func setImportedScheduleRuleSetSelectionIndexForTesting(_ index: Int) {
        if index <= 0 {
            setImportedScheduleRuleSet(nil)
        } else {
            let ruleSetIndex = min(max(index - 1, 0), max(appState.ruleSets.count - 1, 0))
            setImportedScheduleRuleSet(appState.ruleSets[safe: ruleSetIndex]?.id)
        }
        reload()
    }

    func resyncImportedSchedulesForTesting() {
        resyncImportedSchedules()
    }

    var calendarControlsLockedForTesting: Bool { !calendarIntegrationSwitch.isEnabled }

    func invokeCalendarPermissionAlertForTesting() {
        presentCalendarPermissionAlert()
    }
}
