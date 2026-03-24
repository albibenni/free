import AppKit

final class ScheduleEditorViewController: NSViewController, NSTextFieldDelegate {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse

    private static var _makeDeleteConfirmationAlert: AlertFactory?
    private static var _runDeleteConfirmationAlert: AlertRunner?
    private static var _isRunningInTestProcess: (() -> Bool)?
    static var makeDeleteConfirmationAlert: AlertFactory {
        get { _makeDeleteConfirmationAlert ?? defaultMakeDeleteConfirmationAlert }
        set { _makeDeleteConfirmationAlert = newValue }
    }
    static var runDeleteConfirmationAlert: AlertRunner {
        get { _runDeleteConfirmationAlert ?? defaultRunDeleteConfirmationAlert }
        set { _runDeleteConfirmationAlert = newValue }
    }

    private static func defaultMakeDeleteConfirmationAlert() -> NSAlert { NSAlert() }
    private static func defaultRunDeleteConfirmationAlert(
        _ alert: NSAlert
    ) -> NSApplication.ModalResponse {
        if isRunningUnderXCTest {
            return .alertFirstButtonReturn
        }
        return alert.runModal()
    }
    private static var isRunningUnderXCTest: Bool {
        (_isRunningInTestProcess ?? { AppDelegate.isRunningInTestProcess() })()
    }

    private let appState: AppState
    private let context: ScheduleEditorContext
    private let onRequestClose: () -> Void

    private var name: String
    private var days: Set<Int>
    private var startTime: Date
    private var endTime: Date
    private var selectedColorIndex: Int
    private var sessionType: ScheduleType
    private var ruleSetId: UUID?
    private var modifyAllDays = true
    private var isRecurring = false
    private var sessionTypeControl: AppKitSelectionButtonGroup<ScheduleType>?
    private var repeatCheckbox: NSButton?
    private var recurringDaysSection: NSView?
    private var recurringDayButtons: [Int: ActionButton] = [:]
    private var saveButton: ActionButton?
    private var reloadGeneration = 0

    private let headerTitleLabel = NSTextField(labelWithString: "")
    private let closeButton = ActionButton()
    private let divider = AppKitDynamicView()
    private let scrollContainer = VerticalStackScrollContainer(
        contentInsets: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    )

    init(
        appState: AppState,
        context: ScheduleEditorContext,
        onRequestClose: @escaping () -> Void
    ) {
        self.appState = appState
        self.context = context
        self.onRequestClose = onRequestClose

        let configuration = ScheduleEditorSupport.configuration(
            initialDay: context.day,
            initialStartTime: context.startTime,
            initialEndTime: context.endTime,
            existingSchedule: context.schedule
        )
        self.name = configuration.name
        self.days = configuration.days
        self.startTime = configuration.startTime
        self.endTime = configuration.endTime
        self.selectedColorIndex = configuration.colorIndex
        self.sessionType = configuration.type
        self.ruleSetId = configuration.ruleSetId
        self.isRecurring = context.schedule.map { $0.date == nil } ?? configuration.isRecurring
        self.modifyAllDays = true

        super.init(nibName: nil, bundle: nil)

        if ScheduleEditorSupport.shouldApplyNewScheduleDefaults(existingSchedule: context.schedule) {
            selectedColorIndex = appState.schedules.count % FocusColor.all.count
            ruleSetId = appState.ruleSets.first?.id
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitFlippedView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        configureHeader()

        divider.backgroundColorProvider = { NSColor.separatorColor }
        divider.translatesAutoresizingMaskIntoConstraints = false

        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollContainer)
        view.addSubview(divider)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            scrollContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        reloadForm()
    }

    private var existingSchedule: Schedule? { context.schedule }
    private var initialDay: Int? { context.day }
    private var importedSchedule: Bool {
        ScheduleEditorSupport.isImportedSchedule(existingSchedule)
    }
    private var canEditImportedDetails: Bool {
        ScheduleEditorSupport.canEditImportedScheduleDetails(existingSchedule: existingSchedule)
    }
    private var accentColor: NSColor { FocusColor.nsColor(for: appState.accentColorIndex) }
    private var primaryButtonColor: NSColor {
        ScheduleEditorSupport.primaryButtonColor(
            sessionType: sessionType,
            accentColorIndex: appState.accentColorIndex
        )
    }

    private func configureHeader() {
        headerTitleLabel.stringValue = existingSchedule == nil ? "New Schedule" : "Edit Schedule"
        headerTitleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerTitleLabel)

        configureAppKitIconButton(
            closeButton,
            symbol: AppKitUISymbols.closeEditor,
            color: .secondaryLabelColor
        )
        closeButton.onAction = onRequestClose
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headerTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerTitleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),

            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            closeButton.centerYAnchor.constraint(equalTo: headerTitleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func reloadForm() {
        reloadGeneration += 1
        removeArrangedSubviews(from: scrollContainer.stackView)
        recurringDaysSection = nil
        recurringDayButtons = [:]
        saveButton = nil
        repeatCheckbox = nil

        if importedSchedule {
            addSection(makeImportedBadge())
            addSection(
                makeTextFieldSection(
                    title: "SCHEDULE NAME",
                    text: name,
                    editable: false,
                    placeholder: ScheduleEditorSupport.scheduleNamePlaceholder(for: sessionType)
                )
            )
        }

        addSection(makeSessionTypeSection())

        addSection(makeAllowedListSection())

        if canEditImportedDetails {
            if ScheduleEditorSupport.shouldShowEditScope(
                existingSchedule: existingSchedule,
                initialDay: initialDay
            ) {
                addSection(makeEditScopeSection())
            }

            addSection(
                makeTextFieldSection(
                    title: "SCHEDULE NAME",
                    text: name,
                    editable: true,
                    placeholder: ScheduleEditorSupport.scheduleNamePlaceholder(for: sessionType)
                )
            )
        }

        addSection(makeThemeColorSection())

        if canEditImportedDetails {
            addSection(makeTimeSection())
            addSection(makeRepeatSection())
            let recurringDaysSection = makeRecurringDaysSection()
            self.recurringDaysSection = recurringDaysSection
            addSection(recurringDaysSection)
        }

        addSection(makeActionSection())
        updateRecurringUI()
    }

    private func addSection(_ sectionView: NSView) {
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.stackView.addArrangedSubview(sectionView)
        sectionView.widthAnchor.constraint(equalTo: scrollContainer.stackView.widthAnchor).isActive = true
    }

    private func makeImportedBadge() -> NSView {
        ScheduleEditorLayoutBuilder.makeImportedBadge()
    }

    private func makeSessionTypeSection() -> NSView {
        let section = makeSectionContainer(title: "SESSION TYPE")
        let control = AppKitSelectionButtonGroup(
            options: [
                AppKitSelectionButtonOption(title: "Focus", value: ScheduleType.focus),
                AppKitSelectionButtonOption(title: "Break", value: ScheduleType.unfocus),
            ],
            selectedValue: sessionType,
            accentColor: accentColor
        )
        control.onSelection = { [weak self] type in
            self?.sessionType = type
            self?.reloadForm()
        }
        sessionTypeControl = control
        section.contentStack.addArrangedSubview(control)
        return section
    }

    private func makeAllowedListSection() -> NSView {
        let section = makeSectionContainer(title: "ALLOWED LIST")
        let popup = NSPopUpButton()
        let menu = NSMenu(title: "AllowedListMenu")
        popup.menu = menu
        if ScheduleEditorSupport.shouldShowAllowedList(for: sessionType) {
            popup.target = self
            popup.action = #selector(changeRuleSet(_:))
            popup.isEnabled = true

            menu.addItem(NSMenuItem(title: "None", action: nil, keyEquivalent: ""))

            for set in appState.ruleSets {
                let item = NSMenuItem(title: set.name, action: nil, keyEquivalent: "")
                item.representedObject = set.id
                menu.addItem(item)
            }

            let desiredSelection = ruleSetId
            if let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? UUID) == desiredSelection }) {
                popup.selectItem(at: index)
            } else {
                popup.selectItem(at: 0)
            }
        } else {
            popup.addItem(withTitle: "Not used for breaks")
            popup.selectItem(at: 0)
            popup.isEnabled = false
        }

        section.contentStack.addArrangedSubview(popup)
        return section
    }

    private func makeEditScopeSection() -> NSView {
        let section = makeSectionContainer(title: "EDIT SCOPE")
        let onlyDayTitle = "Only \(ScheduleEditorSupport.dayName(for: initialDay!))"
        let control = AppKitSelectionButtonGroup(
            options: [
                AppKitSelectionButtonOption(title: "All Days", value: true),
                AppKitSelectionButtonOption(title: onlyDayTitle, value: false),
            ],
            selectedValue: modifyAllDays,
            accentColor: accentColor
        )
        control.onSelection = { [weak self] modifyAllDays in
            self?.modifyAllDays = modifyAllDays
            self?.reloadForm()
        }
        section.contentStack.addArrangedSubview(control)
        return section
    }

    private func makeTextFieldSection(
        title: String,
        text: String,
        editable: Bool,
        placeholder: String
    ) -> NSView {
        ScheduleEditorLayoutBuilder.makeTextFieldSection(
            title: title,
            text: text,
            editable: editable,
            placeholder: placeholder,
            delegate: self
        )
    }

    private func makeThemeColorSection() -> NSView {
        ScheduleEditorLayoutBuilder.makeThemeColorSection(
            selectedColorIndex: selectedColorIndex
        ) { [weak self] index in
            self?.selectedColorIndex = index
            self?.reloadForm()
        }
    }

    private func makeTimeSection() -> NSView {
        let section = makeSectionContainer(title: "")
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 24
        row.distribution = .fillEqually

        row.addArrangedSubview(makeTimePickerCard(title: "START TIME", date: startTime, action: #selector(changeStartTime(_:))))
        row.addArrangedSubview(makeTimePickerCard(title: "END TIME", date: endTime, action: #selector(changeEndTime(_:))))

        section.contentStack.addArrangedSubview(row)
        return section
    }

    private func makeRepeatSection() -> NSView {
        let repeatSection = ScheduleEditorLayoutBuilder.makeRepeatSection(
            isRecurring: isRecurring,
            target: self,
            action: #selector(toggleRecurring(_:))
        )
        repeatCheckbox = repeatSection.checkbox
        return repeatSection.container
    }

    private func makeRecurringDaysSection() -> NSView {
        let section = makeSectionContainer(title: "DAYS OF THE WEEK")

        if ScheduleEditorSupport.shouldShowSingleDayBadge(
            existingSchedule: existingSchedule,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        ), let day = initialDay {
            let badge = makeAppKitSecondaryButton(
                title: ScheduleEditorSupport.dayName(for: day),
                color: accentColor
            )
            badge.isEnabled = false
            section.contentStack.addArrangedSubview(badge)
            return section
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        for day in ScheduleEditorSupport.weekDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday) {
            let button = ScheduleEditorLayoutBuilder.makeRecurringDayButton(
                symbol: ScheduleEditorSupport.daySymbol(at: day)
            ) { [weak self] in
                self?.toggleRecurringDay(day)
            }
            recurringDayButtons[day] = button
            row.addArrangedSubview(button)
        }

        section.contentStack.addArrangedSubview(row)
        return section
    }

    private func makeActionSection() -> NSView {
        let section = AppKitFlippedView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(stack)

        let saveButton = makeAppKitPrimaryButton(
            title: ScheduleEditorSupport.saveButtonTitle(
                existingSchedule: existingSchedule,
                sessionType: sessionType
            ),
            color: primaryButtonColor
        )
        saveButton.isEnabled = !ScheduleEditorSupport.isSaveDisabled(
            days: days,
            modifyAllDays: modifyAllDays,
            isRecurring: isRecurring
        )
        self.saveButton = saveButton
        saveButton.onAction = { [weak self] in
            self?.saveSchedule()
        }
        stack.addArrangedSubview(saveButton)
        saveButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        if ScheduleEditorSupport.canDeleteSchedule(existingSchedule: existingSchedule) {
            let deleteButton = ActionButton(title: "Delete Schedule")
            deleteButton.isBordered = false
            deleteButton.alignment = .center
            deleteButton.attributedTitle = NSAttributedString(
                string: "Delete Schedule",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: NSColor.systemRed,
                ]
            )
            deleteButton.onAction = { [weak self] in
                self?.deleteSchedule()
            }
            stack.addArrangedSubview(deleteButton)
            deleteButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            stack.topAnchor.constraint(equalTo: section.topAnchor),
            stack.bottomAnchor.constraint(equalTo: section.bottomAnchor),
        ])
        return section
    }

    private func makeSectionContainer(title: String) -> EditorSectionView {
        EditorSectionView(title: title)
    }

    private func makeTimePickerCard(title: String, date: Date, action: Selector) -> NSView {
        ScheduleEditorLayoutBuilder.makeTimePickerCard(
            title: title,
            date: date,
            target: self,
            action: action
        )
    }

    private func saveSchedule() {
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Save Schedule",
                action: "save this schedule",
                appState: appState
            ) else { return }
        }
        let payload = ScheduleEditorSupport.savePayload(
            days: days,
            isRecurring: isRecurring,
            initialDay: initialDay,
            weekOffset: context.weekOffset,
            weekStartsOnMonday: appState.weekStartsOnMonday
        )
        appState.saveSchedule(
            name: name,
            days: payload.days,
            date: payload.date,
            start: startTime,
            end: endTime,
            color: selectedColorIndex,
            type: sessionType,
            ruleSet: ruleSetId,
            existingId: existingSchedule?.id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
        onRequestClose()
    }

    private func deleteSchedule() {
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Delete Schedule",
                action: "delete this schedule",
                appState: appState
            ) else { return }
        }
        guard let existingSchedule else { return }
        if ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
            existingSchedule: existingSchedule,
            modifyAllDays: modifyAllDays
        ) {
            if Self.isRunningUnderXCTest,
                Self._makeDeleteConfirmationAlert == nil,
                Self._runDeleteConfirmationAlert == nil
            {
                // Avoid constructing NSAlert off-main in non-UI tests.
            } else {
            let alert = Self.makeDeleteConfirmationAlert()
            alert.alertStyle = .warning
            alert.messageText = "Delete Multi-Day Schedule?"
            alert.informativeText =
                "This schedule repeats across multiple days. Deleting it will remove all days."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            guard Self.runDeleteConfirmationAlert(alert) == .alertFirstButtonReturn else { return }
            }
        }
        appState.deleteSchedule(
            id: existingSchedule.id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
        onRequestClose()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field.identifier?.rawValue == "scheduleNameField" {
            name = field.stringValue
        }
    }

    @objc
    private func changeRuleSet(_ sender: NSPopUpButton) {
        ruleSetId = ScheduleEditorActionsCoordinator.ruleSetIdForSelectedPopupIndex(
            sender.indexOfSelectedItem,
            ruleSets: appState.ruleSets
        )
    }

    @objc
    private func changeStartTime(_ sender: NSDatePicker) {
        startTime = sender.dateValue
    }

    @objc
    private func changeEndTime(_ sender: NSDatePicker) {
        endTime = sender.dateValue
    }

    @objc
    private func toggleRecurring(_ sender: NSButton) {
        isRecurring = ScheduleEditorActionsCoordinator.toggledRecurring(
            checkboxState: sender.state
        )
        updateRecurringUI()
    }

    private func updateRecurringUI() {
        ScheduleEditorRecurringUICoordinator.applyRecurringUI(
            repeatCheckbox: repeatCheckbox,
            recurringDaysSection: recurringDaysSection,
            recurringDayButtons: recurringDayButtons,
            days: days,
            isRecurring: isRecurring,
            accentColor: accentColor
        )
        saveButton?.isEnabled = !ScheduleEditorSupport.isSaveDisabled(
            days: days,
            modifyAllDays: modifyAllDays,
            isRecurring: isRecurring
        )
        if appState.isStrict {
            saveButton?.isEnabled = false
        }
        scrollContainer.needsLayout = true
    }

    private func toggleSaveStateForCurrentRules() {
        saveButton?.isEnabled = !appState.isStrict && !ScheduleEditorSupport.isSaveDisabled(
            days: days,
            modifyAllDays: modifyAllDays,
            isRecurring: isRecurring
        )
    }

    private func toggleRecurringDay(_ day: Int) {
        guard isRecurring else { return }
        days = ScheduleEditorSupport.toggledDays(days, day: day)
        applyRecurringDayButtonStyles()
        toggleSaveStateForCurrentRules()
    }

    private func applyRecurringDayButtonStyles() {
        ScheduleEditorRecurringUICoordinator.applyRecurringUI(
            repeatCheckbox: nil,
            recurringDaysSection: nil,
            recurringDayButtons: recurringDayButtons,
            days: days,
            isRecurring: isRecurring,
            accentColor: accentColor
        )
    }
}

extension ScheduleEditorViewController {
    var headerTitleForTesting: String { headerTitleLabel.stringValue }
    var importedScheduleForTesting: Bool { importedSchedule }
    var canEditImportedDetailsForTesting: Bool { canEditImportedDetails }
    var sessionTypeSelectionColorForTesting: NSColor? { sessionTypeControl?.selectedButtonTintColor }
    var formReloadGenerationForTesting: Int { reloadGeneration }
    var isRecurringDaysSectionHiddenForTesting: Bool? { recurringDaysSection?.isHidden }
    var areRecurringDayButtonsEnabledForTesting: Bool? {
        recurringDayButtons.values.first?.isEnabled
    }

    func dismissForTesting() {
        onRequestClose()
    }

    func saveScheduleForTesting() {
        saveSchedule()
    }

    func deleteScheduleForTesting() {
        deleteSchedule()
    }

    func setRecurringForTesting(_ isRecurring: Bool) {
        self.isRecurring = isRecurring
        updateRecurringUI()
    }

    func setNameForTesting(_ value: String) {
        let field = NSTextField(string: value)
        field.identifier = NSUserInterfaceItemIdentifier("scheduleNameField")
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
    }

    func selectRuleSetIndexForTesting(_ index: Int) {
        let popup = NSPopUpButton()
        let menu = NSMenu(title: "AllowedListMenu.Test")
        popup.menu = menu
        menu.addItem(NSMenuItem(title: "None", action: nil, keyEquivalent: ""))
        for set in appState.ruleSets {
            let item = NSMenuItem(title: set.name, action: nil, keyEquivalent: "")
            item.representedObject = set.id
            menu.addItem(item)
        }
        popup.selectItem(at: max(0, min(index, popup.numberOfItems - 1)))
        changeRuleSet(popup)
    }

    func changeStartTimeForTesting(_ date: Date) {
        let picker = NSDatePicker()
        picker.dateValue = date
        changeStartTime(picker)
    }

    func changeEndTimeForTesting(_ date: Date) {
        let picker = NSDatePicker()
        picker.dateValue = date
        changeEndTime(picker)
    }

    func toggleRecurringForTesting(_ enabled: Bool) {
        let checkbox = NSButton(checkboxWithTitle: "Repeat", target: nil, action: nil)
        checkbox.state = enabled ? .on : .off
        toggleRecurring(checkbox)
    }

    func toggleRecurringDayForTesting(_ day: Int) {
        toggleRecurringDay(day)
    }

    func controlTextDidChangeForTesting(object: Any?) {
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: object))
    }

    var nameForTesting: String { name }
    var daysForTesting: Set<Int> { days }
    var startTimeForTesting: Date { startTime }
    var endTimeForTesting: Date { endTime }
    var ruleSetIdForTesting: UUID? { ruleSetId }

    static func resetDeleteConfirmationHooksForTesting() {
        _makeDeleteConfirmationAlert = nil
        _runDeleteConfirmationAlert = nil
        _isRunningInTestProcess = nil
    }

    static func setRunningInTestProcessHookForTesting(_ hook: (() -> Bool)?) {
        _isRunningInTestProcess = hook
    }
}
