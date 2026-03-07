import AppKit
import Combine

final class RulesSheetViewController: NSViewController {
    private let appState: AppState
    private var selectedSetId: UUID?
    private var isSidebarVisible = true
    private var isSuggestionsExpanded = false

    private let sidebarContainer = AppKitDynamicView()
    private let sidebarHeader = NSStackView()
    private let sidebarScrollView = VerticalStackScrollContainer(contentInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
    private let addRuleSetButton = NSButton()
    private let mainContainer = AppKitDynamicView()
    private let mainHeader = NSStackView()
    private let mainTitleLabel = NSTextField(labelWithString: "")
    private let toggleSidebarButton = NSButton()
    private let contentScrollView = VerticalStackScrollContainer()
    private let noSelectionLabel = NSTextField(labelWithString: "Select a list to edit")
    private let rulesHeaderLabel = NSTextField(labelWithString: "Allowed in this list")
    private let rulesEmptyLabel = NSTextField(labelWithString: "No rules yet.")
    private let rulesRowsStack = NSStackView()
    private let suggestionsDivider = makeAppKitDividerView(color: .separatorColor)
    private let suggestionsButton = NSButton(
        title: "Open Tabs Suggestions",
        target: nil,
        action: nil
    )
    private let suggestionsEmptyLabel = NSTextField(labelWithString: "")
    private let suggestionsRowsStack = NSStackView()
    private let addRuleField = NSTextField(string: "")
    private let addRuleButton = ActionButton(title: "Add")
    private let doneButton = ActionButton(title: "Done")
    private let onDismiss: (() -> Void)?
    private var renderSignature: RulesSheetRenderSignature?
    private var reloadGeneration = 0
    private var sidebarRowsById: [UUID: RulesSheetSidebarRowView] = [:]
    private var ruleRowsByRule: [String: RulesSheetRuleRowView] = [:]
    private var suggestionRowsByUrl: [String: RulesSheetSuggestionRowView] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, onDismiss: (() -> Void)? = nil) {
        self.appState = appState
        self.onDismiss = onDismiss
        selectedSetId = appState.currentPrimaryRuleSetId
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 900, height: 700)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.backgroundColorProvider = { NSColor.windowBackgroundColor }
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        let divider = makeAppKitDividerView(color: .separatorColor)
        divider.translatesAutoresizingMaskIntoConstraints = false

        [sidebarContainer, divider, mainContainer].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 200),

            divider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: view.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            mainContainer.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContainer.topAnchor.constraint(equalTo: view.topAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureSidebar()
        configureMainContent()
        updateSidebarVisibility()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppKitAppStateObservation.bind(
            appState: appState,
            cancellables: &cancellables
        ) { [weak self] in
            self?.handleObservedAppStateChange()
        }

        appState.refreshCurrentOpenUrls()
        reloadContent()
    }

    private func handleObservedAppStateChange() {
        let nextSignature = RulesSheetRenderSignature(
            appState: appState,
            isSuggestionsExpanded: isSuggestionsExpanded,
            currentSelectedSetId: selectedSetId
        )
        guard renderSignature != nextSignature else { return }
        reloadContent()
    }

    private func configureSidebar() {
        let title = NSTextField(labelWithString: "ALLOWED LISTS")
        title.font = .systemFont(ofSize: 11, weight: .bold)
        title.textColor = .secondaryLabelColor

        addRuleSetButton.target = self
        addRuleSetButton.action = #selector(addRuleSet)
        addRuleSetButton.translatesAutoresizingMaskIntoConstraints = false
        addRuleSetButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        addRuleSetButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        sidebarHeader.orientation = .horizontal
        sidebarHeader.alignment = .centerY
        sidebarHeader.spacing = 8
        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false
        sidebarHeader.addArrangedSubview(title)
        sidebarHeader.addArrangedSubview(NSView())
        sidebarHeader.addArrangedSubview(addRuleSetButton)
        sidebarContainer.addSubview(sidebarHeader)

        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarScrollView)

        NSLayoutConstraint.activate([
            sidebarHeader.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 16),
            sidebarHeader.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -16),
            sidebarHeader.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 12),

            sidebarScrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScrollView.topAnchor.constraint(equalTo: sidebarHeader.bottomAnchor, constant: 8),
            sidebarScrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])
    }

    private func configureMainContent() {
        mainHeader.orientation = .horizontal
        mainHeader.alignment = .centerY
        mainHeader.spacing = 8
        mainHeader.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(
            toggleSidebarButton,
            symbolName: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible)
        )
        toggleSidebarButton.target = self
        toggleSidebarButton.action = #selector(toggleSidebar)
        mainTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        addRuleField.placeholderString = "Add URL to allow..."
        addRuleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addRuleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addRuleField.translatesAutoresizingMaskIntoConstraints = false
        addRuleField.heightAnchor.constraint(equalToConstant: 28).isActive = true
        addRuleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        addRuleField.widthAnchor.constraint(lessThanOrEqualToConstant: 380).isActive = true

        mainHeader.addArrangedSubview(toggleSidebarButton)
        mainHeader.addArrangedSubview(mainTitleLabel)
        mainHeader.addArrangedSubview(NSView())
        mainHeader.addArrangedSubview(addRuleField)
        addRuleButton.translatesAutoresizingMaskIntoConstraints = false
        addRuleButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        addRuleButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        addRuleButton.target = self
        addRuleButton.action = #selector(addRule)
        mainHeader.addArrangedSubview(addRuleButton)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
        doneButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        doneButton.target = self
        doneButton.action = #selector(handleDone)
        doneButton.isHidden = onDismiss == nil
        mainHeader.addArrangedSubview(doneButton)

        let divider = makeAppKitDividerView(color: .separatorColor)
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false

        [mainHeader, divider, contentScrollView].forEach { mainContainer.addSubview($0) }

        NSLayoutConstraint.activate([
            mainHeader.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 12),
            mainHeader.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -12),
            mainHeader.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            mainHeader.heightAnchor.constraint(equalToConstant: 44),

            divider.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: mainHeader.bottomAnchor),

            contentScrollView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
        ])

        configureContentStructure()
    }

    private func configureContentStructure() {
        noSelectionLabel.textColor = .secondaryLabelColor

        rulesHeaderLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        rulesHeaderLabel.textColor = .secondaryLabelColor

        rulesEmptyLabel.textColor = .secondaryLabelColor

        rulesRowsStack.orientation = .vertical
        rulesRowsStack.alignment = .leading
        rulesRowsStack.spacing = 8

        suggestionsButton.isBordered = false
        suggestionsButton.alignment = .left
        suggestionsButton.contentTintColor = .labelColor
        suggestionsButton.target = self
        suggestionsButton.action = #selector(toggleSuggestions)

        suggestionsEmptyLabel.font = .systemFont(ofSize: 12)
        suggestionsEmptyLabel.textColor = .secondaryLabelColor

        suggestionsRowsStack.orientation = .vertical
        suggestionsRowsStack.alignment = .leading
        suggestionsRowsStack.spacing = 8

        contentScrollView.stackView.addArrangedSubview(noSelectionLabel)
        contentScrollView.stackView.addArrangedSubview(rulesHeaderLabel)
        contentScrollView.stackView.addArrangedSubview(rulesEmptyLabel)
        contentScrollView.stackView.addArrangedSubview(rulesRowsStack)
        contentScrollView.stackView.addArrangedSubview(suggestionsDivider)
        contentScrollView.stackView.addArrangedSubview(suggestionsButton)
        contentScrollView.stackView.addArrangedSubview(suggestionsEmptyLabel)
        contentScrollView.stackView.addArrangedSubview(suggestionsRowsStack)

        noSelectionLabel.isHidden = true
        suggestionsEmptyLabel.isHidden = true
        suggestionsRowsStack.isHidden = true
    }

    private func configureIconButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbolName: symbolName,
            color: .secondaryLabelColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.05),
            cornerRadius: 12
        )
    }

    private var selectedSet: RuleSet? {
        RulesSheetActionsCoordinator.selectedRuleSet(
            id: selectedSetId,
            ruleSets: appState.ruleSets
        )
    }

    private func reloadContent() {
        withAppKitSignpost("RulesSheetReloadContent") {
            renderSignature = RulesSheetRenderSignature(
                appState: appState,
                isSuggestionsExpanded: isSuggestionsExpanded,
                currentSelectedSetId: selectedSetId
            )
            reloadGeneration += 1
            applyActionButtonStyling()

            selectedSetId = RulesSheetActionsCoordinator.fallbackSelectedSetId(
                currentSelectedId: selectedSetId,
                currentPrimaryRuleSetId: appState.currentPrimaryRuleSetId,
                ruleSets: appState.ruleSets
            )

            reloadSidebar()
            reloadRuleContent()
        }
    }

    private func applyActionButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        configureAppKitIconButton(
            addRuleSetButton,
            symbol: AppKitUISymbols.addList,
            color: accentColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.06),
            cornerRadius: 11
        )
        addRuleButton.image = nil
        addRuleButton.title = "Add"
        addRuleButton.isBordered = false
        addRuleButton.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
        addRuleButton.setGradientBackground(
            colors: [
                accentColor.withAlphaComponent(0.14),
                accentColor.withAlphaComponent(0.08),
            ],
            borderColor: accentColor.withAlphaComponent(0.28)
        )
        addRuleButton.attributedTitle = NSAttributedString(
            string: "Add",
            attributes: [
                .font: AppKitUIConstants.Typography.regular,
                .foregroundColor: accentColor,
            ]
        )
        addRuleButton.contentTintColor = accentColor

        doneButton.image = nil
        doneButton.title = "Done"
        doneButton.isBordered = false
        doneButton.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
        doneButton.setGradientBackground(
            colors: [
                NSColor.labelColor.withAlphaComponent(0.10),
                NSColor.labelColor.withAlphaComponent(0.05),
            ],
            borderColor: NSColor.separatorColor.withAlphaComponent(0.35)
        )
        doneButton.attributedTitle = NSAttributedString(
            string: "Done",
            attributes: [
                .font: AppKitUIConstants.Typography.regular,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        doneButton.contentTintColor = .labelColor
    }

    private func reloadSidebar() {
        let canDelete = RulesSectionSupport.shouldShowDeleteSetButton(
            ruleSetCount: appState.ruleSets.count,
            isBlocking: appState.isBlocking
        )
        let rows = appState.ruleSets

        if canReuseSidebarRows(rows: rows) {
            for ruleSet in rows {
                sidebarRowsById[ruleSet.id]?.configure(
                    title: ruleSet.name,
                    ruleSetId: ruleSet.id,
                    isSelected: selectedSetId == ruleSet.id,
                    canDelete: canDelete,
                    onSelect: #selector(selectRuleSet(_:)),
                    onDelete: #selector(deleteRuleSet(_:)),
                    target: self
                )
            }
        } else {
            removeAllArrangedSubviews(from: sidebarScrollView.stackView)
            sidebarRowsById.removeAll()
            for ruleSet in rows {
                let row = RulesSheetLayoutBuilder.makeSidebarRow(
                    ruleSet: ruleSet,
                    isSelected: selectedSetId == ruleSet.id,
                    canDelete: canDelete,
                    onSelect: #selector(selectRuleSet(_:)),
                    onDelete: #selector(deleteRuleSet(_:)),
                    target: self
                )
                sidebarScrollView.stackView.addArrangedSubview(row)
                sidebarRowsById[ruleSet.id] = row
            }
        }
        sidebarScrollView.needsLayout = true
    }

    private func canReuseSidebarRows(rows: [RuleSet]) -> Bool {
        guard rows.count == sidebarRowsById.count else { return false }
        guard rows.allSatisfy({ sidebarRowsById[$0.id] != nil }) else { return false }
        let expectedOrder = rows.map(\.id)
        let currentOrder = sidebarScrollView.stackView.arrangedSubviews.compactMap { view in
            (view as? RulesSheetSidebarRowView)?.ruleSetId
        }
        return expectedOrder == currentOrder
    }

    private func reloadRuleContent() {
        withAppKitSignpost("RulesSheetReloadRuleContent") {
            mainTitleLabel.stringValue = selectedSet?.name ?? ""
            toggleSidebarButton.image = appKitSymbolImage(
                named: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible),
                pointSize: 11,
                weight: .semibold,
                color: .secondaryLabelColor
            )

            guard let selectedSet else {
                noSelectionLabel.isHidden = false
                rulesHeaderLabel.isHidden = true
                rulesEmptyLabel.isHidden = true
                rulesRowsStack.isHidden = true
                suggestionsDivider.isHidden = true
                suggestionsButton.isHidden = true
                suggestionsEmptyLabel.isHidden = true
                suggestionsRowsStack.isHidden = true
                return
            }

            noSelectionLabel.isHidden = true
            rulesHeaderLabel.isHidden = false
            suggestionsDivider.isHidden = false
            suggestionsButton.isHidden = false

            let rules = selectedSet.urls
            ruleRowsByRule = RulesSheetLayoutBuilder.updateOrRebuildRuleRows(
                in: rulesRowsStack,
                rules: rules,
                existingRows: ruleRowsByRule,
                onDelete: #selector(deleteRule(_:)),
                target: self
            )
            rulesEmptyLabel.isHidden = !rules.isEmpty
            rulesRowsStack.isHidden = rules.isEmpty

            if isSuggestionsExpanded {
                let filtered = RulesSectionSupport.filterSuggestions(
                    appState.currentOpenUrls,
                    existing: selectedSet
                )
                let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
                if filtered.isEmpty {
                    suggestionsEmptyLabel.stringValue = RulesSectionSupport.suggestionsEmptyText(
                        currentOpenUrls: appState.currentOpenUrls
                    )
                    suggestionsEmptyLabel.isHidden = false
                    suggestionsRowsStack.isHidden = true
                } else {
                    suggestionRowsByUrl = RulesSheetLayoutBuilder.updateOrRebuildSuggestionRows(
                        in: suggestionsRowsStack,
                        suggestions: filtered,
                        accentColor: accentColor,
                        existingRows: suggestionRowsByUrl,
                        onAdd: #selector(addSuggestion(_:)),
                        target: self
                    )
                    suggestionsEmptyLabel.isHidden = true
                    suggestionsRowsStack.isHidden = false
                }
            } else {
                suggestionsEmptyLabel.isHidden = true
                suggestionsRowsStack.isHidden = true
            }

            contentScrollView.needsLayout = true
        }
    }

    private func updateSidebarVisibility() {
        sidebarContainer.isHidden = !isSidebarVisible
    }

    @objc
    private func toggleSidebar() {
        isSidebarVisible.toggle()
        updateSidebarVisibility()
        reloadRuleContent()
    }

    @objc
    private func addRuleSet() {
        guard let name = RulesSheetAlertPresenter.promptForNewRuleSetName() else { return }
        let newSet = appState.createRuleSet(name: name, makeActive: false)
        selectedSetId = newSet.id
        reloadContent()
    }

    @objc
    private func selectRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        let nextSelectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterRowTap(
            tappedId: id,
            isBlocking: appState.isBlocking,
            currentSelectedId: selectedSetId
        )
        guard nextSelectedSetId != selectedSetId else { return }
        selectedSetId = nextSelectedSetId
        reloadSidebar()
        reloadRuleContent()
    }

    @objc
    private func deleteRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        appState.deleteSet(id: id)
        selectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterDelete(
            deletedId: id,
            currentSelectedId: selectedSetId,
            remainingRuleSets: appState.ruleSets
        )
        reloadContent()
    }

    @objc
    private func deleteRule(_ sender: NSButton) {
        guard let rule = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.removeRule(rule, from: setId)
    }

    @objc
    private func addRule() {
        guard let setId = selectedSet?.id else { return }
        appState.addRule(addRuleField.stringValue, to: setId)
        addRuleField.stringValue = ""
    }

    @objc
    private func toggleSuggestions() {
        isSuggestionsExpanded = RulesSheetActionsCoordinator.toggledSuggestions(
            isSuggestionsExpanded
        )
        if isSuggestionsExpanded {
            appState.refreshCurrentOpenUrls()
        }
        reloadRuleContent()
    }

    @objc
    private func addSuggestion(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.addSpecificRule(url, to: setId)
    }

    @objc
    private func handleDone() {
        onDismiss?()
    }
}

extension RulesSheetViewController {
    var selectedSetIdForTesting: UUID? { selectedSetId }
    var isSidebarVisibleForTesting: Bool { isSidebarVisible }
    var isSuggestionsExpandedForTesting: Bool { isSuggestionsExpanded }
    var reloadGenerationForTesting: Int { reloadGeneration }

    func createSetForTesting(name: String) {
        let newSet = appState.createRuleSet(name: name, makeActive: false)
        selectedSetId = newSet.id
        reloadContent()
    }

    func selectRuleSetForTesting(_ ruleSet: RuleSet) {
        let nextSelectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterRowTap(
            tappedId: ruleSet.id,
            isBlocking: appState.isBlocking,
            currentSelectedId: selectedSetId
        )
        guard nextSelectedSetId != selectedSetId else { return }
        selectedSetId = nextSelectedSetId
        reloadSidebar()
        reloadRuleContent()
    }

    func deleteRuleSetForTesting(_ ruleSet: RuleSet) {
        appState.deleteSet(id: ruleSet.id)
        selectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterDelete(
            deletedId: ruleSet.id,
            currentSelectedId: selectedSetId,
            remainingRuleSets: appState.ruleSets
        )
        reloadContent()
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func toggleSuggestionsForTesting() {
        toggleSuggestions()
    }

    func setSuggestionsExpandedForTesting(_ expanded: Bool) {
        isSuggestionsExpanded = expanded
        reloadRuleContent()
    }

    func refreshSuggestionsForTesting() {
        appState.refreshCurrentOpenUrls()
        reloadRuleContent()
    }

    func addSuggestionForTesting(url: String, setId: UUID) {
        appState.addSpecificRule(url, to: setId)
        reloadRuleContent()
    }

    func addRuleForTesting(_ rule: String, setId: UUID) {
        selectedSetId = setId
        addRuleField.stringValue = rule
        addRule()
    }

    func filteredSuggestionsForTesting(for selectedSet: RuleSet) -> [String] {
        RulesSectionSupport.filterSuggestions(appState.currentOpenUrls, existing: selectedSet)
    }

    func sidebarRowObjectIdentifierForTesting(_ id: UUID) -> ObjectIdentifier? {
        sidebarRowsById[id].map(ObjectIdentifier.init)
    }

    func ruleRowObjectIdentifierForTesting(_ rule: String) -> ObjectIdentifier? {
        ruleRowsByRule[rule].map(ObjectIdentifier.init)
    }

    func suggestionRowObjectIdentifierForTesting(_ url: String) -> ObjectIdentifier? {
        suggestionRowsByUrl[url].map(ObjectIdentifier.init)
    }
}
