import AppKit

private func removeArrangedSubviews(from stackView: NSStackView) {
    let arrangedSubviews = stackView.arrangedSubviews
    arrangedSubviews.forEach { subview in
        stackView.removeArrangedSubview(subview)
        subview.removeFromSuperview()
    }
}

private final class EditorSectionView: AppKitFlippedView {
    let contentStack = NSStackView()

    init(title: String? = nil) {
        super.init(frame: .zero)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let title, !title.isEmpty {
            contentStack.addArrangedSubview(makeAppKitSectionLabel(title))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ScheduleEditorViewController: NSViewController, NSTextFieldDelegate {
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

    private let headerTitleLabel = NSTextField(labelWithString: "")
    private let closeButton = ActionButton()
    private let divider = NSView()
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
        view = AppKitFlippedView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureHeader()

        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
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

        closeButton.isBordered = false
        closeButton.image = appKitSymbolImage(
            named: "xmark.circle.fill",
            pointSize: 18,
            weight: .regular,
            color: .secondaryLabelColor
        )
        closeButton.imagePosition = .imageOnly
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
        removeArrangedSubviews(from: scrollContainer.stackView)

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

        if ScheduleEditorSupport.shouldShowAllowedList(for: sessionType) {
            addSection(makeAllowedListSection())
        }

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

            if isRecurring {
                addSection(makeRecurringDaysSection())
            }
        }

        addSection(makeActionSection())
    }

    private func addSection(_ sectionView: NSView) {
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.stackView.addArrangedSubview(sectionView)
        sectionView.widthAnchor.constraint(equalTo: scrollContainer.stackView.widthAnchor).isActive = true
    }

    private func makeImportedBadge() -> NSView {
        let badge = AppKitCardView()
        badge.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12).cgColor
        badge.layer?.borderWidth = 0

        let icon = NSImageView()
        icon.image = appKitSymbolImage(
            named: "calendar.badge.clock",
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor
        )

        let label = NSTextField(labelWithString: "Imported from Calendar")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [icon, label, NSView()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        badge.contentStack.addArrangedSubview(row)
        return badge
    }

    private func makeSessionTypeSection() -> NSView {
        let section = makeSectionContainer(title: "SESSION TYPE")
        let control = NSSegmentedControl(labels: ["Focus", "Break"], trackingMode: .selectOne, target: self, action: #selector(changeSessionType(_:)))
        control.selectedSegment = sessionType == .focus ? 0 : 1
        section.contentStack.addArrangedSubview(control)
        return section
    }

    private func makeAllowedListSection() -> NSView {
        let section = makeSectionContainer(title: "ALLOWED LIST")
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(changeRuleSet(_:))
        popup.removeAllItems()
        popup.addItem(withTitle: "None")
        popup.lastItem?.representedObject = Optional<UUID>.none

        for set in appState.ruleSets {
            popup.addItem(withTitle: set.name)
            popup.lastItem?.representedObject = UUID?.some(set.id)
        }

        let desiredSelection = ruleSetId
        if let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? UUID) == desiredSelection }) {
            popup.selectItem(at: index)
        } else {
            popup.selectItem(at: 0)
        }

        section.contentStack.addArrangedSubview(popup)
        return section
    }

    private func makeEditScopeSection() -> NSView {
        let section = makeSectionContainer(title: "EDIT SCOPE")
        let onlyDayTitle = "Only \(ScheduleEditorSupport.dayName(for: initialDay ?? 1))"
        let control = NSSegmentedControl(labels: ["All Days", onlyDayTitle], trackingMode: .selectOne, target: self, action: #selector(changeEditScope(_:)))
        control.selectedSegment = modifyAllDays ? 0 : 1
        section.contentStack.addArrangedSubview(control)
        return section
    }

    private func makeTextFieldSection(
        title: String,
        text: String,
        editable: Bool,
        placeholder: String
    ) -> NSView {
        let section = makeSectionContainer(title: title)
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 18, weight: .regular)
        field.delegate = self
        field.isEditable = editable
        field.isEnabled = editable
        field.identifier = NSUserInterfaceItemIdentifier("scheduleNameField")
        section.contentStack.addArrangedSubview(field)
        return section
    }

    private func makeThemeColorSection() -> NSView {
        let section = makeSectionContainer(title: "THEME COLOR")
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        for index in 0..<FocusColor.all.count {
            let button = ActionButton()
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = FocusColor.nsColor(for: index).cgColor
            button.layer?.cornerRadius = 15
            button.layer?.borderWidth = selectedColorIndex == index ? 2 : 0
            button.layer?.borderColor = NSColor.labelColor.cgColor
            button.onAction = { [weak self] in
                self?.selectedColorIndex = index
                self?.reloadForm()
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(button)
        }

        section.contentStack.addArrangedSubview(row)
        return section
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
        let section = AppKitFlippedView()
        let checkbox = NSButton(checkboxWithTitle: "Repeat weekly", target: self, action: #selector(toggleRecurring(_:)))
        checkbox.font = .systemFont(ofSize: 14, weight: .semibold)
        checkbox.state = isRecurring ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(checkbox)
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            checkbox.topAnchor.constraint(equalTo: section.topAnchor),
            checkbox.bottomAnchor.constraint(equalTo: section.bottomAnchor),
        ])
        return section
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
            let isSelected = days.contains(day)
            let button = ActionButton(title: ScheduleEditorSupport.daySymbol(at: day))
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 22
            button.layer?.backgroundColor = (
                isSelected
                    ? accentColor
                    : NSColor.secondaryLabelColor.withAlphaComponent(0.2)
            ).cgColor
            button.attributedTitle = NSAttributedString(
                string: ScheduleEditorSupport.daySymbol(at: day),
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16, weight: .bold),
                    .foregroundColor: isSelected ? NSColor.white : NSColor.labelColor,
                ]
            )
            button.onAction = { [weak self] in
                guard let self else { return }
                self.days = ScheduleEditorSupport.toggledDays(self.days, day: day)
                self.reloadForm()
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
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
        let card = AppKitCardView()
        card.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.03).cgColor

        let label = makeAppKitSectionLabel(title)

        let picker = NSDatePicker()
        picker.datePickerElements = .hourMinute
        picker.datePickerStyle = .textField
        picker.dateValue = date
        picker.target = self
        picker.action = action

        card.contentStack.addArrangedSubview(label)
        card.contentStack.addArrangedSubview(picker)
        return card
    }

    private func saveSchedule() {
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
        guard let existingSchedule else { return }
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
    private func changeSessionType(_ sender: NSSegmentedControl) {
        sessionType = sender.selectedSegment == 0 ? .focus : .unfocus
        reloadForm()
    }

    @objc
    private func changeRuleSet(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            ruleSetId = nil
        } else {
            ruleSetId = appState.ruleSets[safe: sender.indexOfSelectedItem - 1]?.id
        }
    }

    @objc
    private func changeEditScope(_ sender: NSSegmentedControl) {
        modifyAllDays = sender.selectedSegment == 0
        reloadForm()
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
        isRecurring = sender.state == .on
        reloadForm()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension ScheduleEditorViewController {
    var headerTitleForTesting: String { headerTitleLabel.stringValue }
    var importedScheduleForTesting: Bool { importedSchedule }
    var canEditImportedDetailsForTesting: Bool { canEditImportedDetails }

    func dismissForTesting() {
        onRequestClose()
    }

    func saveScheduleForTesting() {
        saveSchedule()
    }

    func deleteScheduleForTesting() {
        deleteSchedule()
    }
}
