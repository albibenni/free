import AppKit
import Combine

final class RulesSheetViewController: NSViewController {
    private struct RenderSignature: Equatable {
        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let ruleSets: [RuleSet]
        let currentPrimaryRuleSetId: UUID?
        let isBlocking: Bool
        let currentOpenUrls: [String]

        init(appState: AppState, isSuggestionsExpanded: Bool) {
            appearanceMode = appState.appearanceMode
            accentColorIndex = appState.accentColorIndex
            ruleSets = appState.ruleSets
            currentPrimaryRuleSetId = appState.currentPrimaryRuleSetId
            isBlocking = appState.isBlocking
            currentOpenUrls = isSuggestionsExpanded ? appState.currentOpenUrls : []
        }
    }

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
    private let addRuleField = NSTextField(string: "")
    private let addRuleButton = ActionButton(title: "Add")
    private let doneButton = ActionButton(title: "Done")
    private let onDismiss: (() -> Void)?
    private var renderSignature: RenderSignature?
    private var reloadGeneration = 0
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
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleObservedAppStateChange()
            }
            .store(in: &cancellables)

        appState.refreshCurrentOpenUrls()
        reloadContent()
    }

    private func handleObservedAppStateChange() {
        let nextSignature = RenderSignature(
            appState: appState,
            isSuggestionsExpanded: isSuggestionsExpanded
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
        appState.ruleSets.first(where: { $0.id == selectedSetId })
    }

    private func reloadContent() {
        renderSignature = RenderSignature(
            appState: appState,
            isSuggestionsExpanded: isSuggestionsExpanded
        )
        reloadGeneration += 1
        applyActionButtonStyling()

        if selectedSetId == nil || selectedSet == nil {
            selectedSetId = appState.currentPrimaryRuleSetId ?? appState.ruleSets.first?.id
        }

        reloadSidebar()
        reloadRuleContent()
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
        removeAllArrangedSubviews(from: sidebarScrollView.stackView)
        for ruleSet in appState.ruleSets {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            row.wantsLayer = true
            row.layer?.cornerRadius = 6
            row.layer?.backgroundColor =
                selectedSetId == ruleSet.id
                ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
                : NSColor.clear.cgColor

            let button = NSButton(title: ruleSet.name, target: self, action: #selector(selectRuleSet(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
            button.isBordered = false
            button.alignment = .left
            button.font = .systemFont(
                ofSize: 13,
                weight: selectedSetId == ruleSet.id ? .semibold : .regular
            )
            button.contentTintColor =
                selectedSetId == ruleSet.id
                ? .labelColor
                : .secondaryLabelColor
            row.addArrangedSubview(button)
            row.addArrangedSubview(NSView())

            if RulesSectionSupport.shouldShowDeleteSetButton(
                ruleSetCount: appState.ruleSets.count,
                isBlocking: appState.isBlocking
            ) {
                let deleteButton = NSButton()
                deleteButton.isBordered = false
                deleteButton.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
                deleteButton.image = appKitSymbolImage(
                    named: AppKitUISymbols.Name.minus,
                    pointSize: 15,
                    weight: .regular,
                    color: .systemRed
                )
                deleteButton.contentTintColor = .systemRed
                deleteButton.target = self
                deleteButton.action = #selector(deleteRuleSet(_:))
                row.addArrangedSubview(deleteButton)
            }

            sidebarScrollView.stackView.addArrangedSubview(row)
        }
        sidebarScrollView.needsLayout = true
    }

    private func reloadRuleContent() {
        removeAllArrangedSubviews(from: contentScrollView.stackView)
        mainTitleLabel.stringValue = selectedSet?.name ?? ""
        toggleSidebarButton.image = appKitSymbolImage(
            named: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible),
            pointSize: 11,
            weight: .semibold,
            color: .secondaryLabelColor
        )

        guard let selectedSet else {
            let emptyLabel = NSTextField(labelWithString: "Select a list to edit")
            emptyLabel.textColor = .secondaryLabelColor
            contentScrollView.stackView.addArrangedSubview(emptyLabel)
            return
        }

        let rulesHeader = NSTextField(labelWithString: "Allowed in this list")
        rulesHeader.font = .systemFont(ofSize: 12, weight: .semibold)
        rulesHeader.textColor = .secondaryLabelColor
        contentScrollView.stackView.addArrangedSubview(rulesHeader)

        if selectedSet.urls.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No rules yet.")
            emptyLabel.textColor = .secondaryLabelColor
            contentScrollView.stackView.addArrangedSubview(emptyLabel)
        } else {
            for rule in selectedSet.urls {
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 8
                let label = NSTextField(labelWithString: rule)
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                let deleteButton = NSButton()
                deleteButton.isBordered = false
                deleteButton.identifier = NSUserInterfaceItemIdentifier(rule)
                deleteButton.image = appKitSymbolImage(
                    spec: AppKitUISymbols.deleteRule,
                    color: .systemRed
                )
                deleteButton.contentTintColor = .systemRed
                deleteButton.target = self
                deleteButton.action = #selector(deleteRule(_:))
                row.addArrangedSubview(label)
                row.addArrangedSubview(NSView())
                row.addArrangedSubview(deleteButton)
                contentScrollView.stackView.addArrangedSubview(row)
            }
        }

        contentScrollView.stackView.addArrangedSubview(makeAppKitDividerView(color: .separatorColor))

        let suggestionsButton = NSButton(
            title: "Open Tabs Suggestions",
            target: self,
            action: #selector(toggleSuggestions)
        )
        suggestionsButton.isBordered = false
        suggestionsButton.alignment = .left
        suggestionsButton.contentTintColor = .labelColor
        contentScrollView.stackView.addArrangedSubview(suggestionsButton)

        if isSuggestionsExpanded {
            let filtered = RulesSectionSupport.filterSuggestions(
                appState.currentOpenUrls,
                existing: selectedSet
            )
            let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
            if filtered.isEmpty {
                let label = NSTextField(
                    labelWithString: RulesSectionSupport.suggestionsEmptyText(
                        currentOpenUrls: appState.currentOpenUrls
                    )
                )
                label.font = .systemFont(ofSize: 12)
                label.textColor = .secondaryLabelColor
                contentScrollView.stackView.addArrangedSubview(label)
            } else {
                for suggestion in filtered {
                    let row = NSStackView()
                    row.orientation = .horizontal
                    row.alignment = .centerY
                    row.spacing = 8
                    let icon = NSImageView(
                        image: NSImage(systemSymbolName: AppKitUISymbols.Name.plusCircle, accessibilityDescription: nil) ?? NSImage()
                    )
                    icon.contentTintColor = .systemGreen
                    let label = NSTextField(labelWithString: suggestion)
                    label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                    let addButton = makeAppKitSecondaryButton(title: "Add", color: accentColor)
                    addButton.identifier = NSUserInterfaceItemIdentifier(suggestion)
                    addButton.target = self
                    addButton.action = #selector(addSuggestion(_:))
                    addButton.translatesAutoresizingMaskIntoConstraints = false
                    addButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
                    addButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
                    row.addArrangedSubview(icon)
                    row.addArrangedSubview(label)
                    row.addArrangedSubview(NSView())
                    row.addArrangedSubview(addButton)
                    contentScrollView.stackView.addArrangedSubview(row)
                }
            }
        }

        contentScrollView.needsLayout = true
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
        let alert = NSAlert()
        alert.messageText = "New Allowed List"
        let input = NSTextField(string: "")
        input.placeholderString = "List Name"
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let newSet = appState.createRuleSet(name: input.stringValue, makeActive: false)
        selectedSetId = newSet.id
        reloadContent()
    }

    @objc
    private func selectRuleSet(_ sender: NSButton) {
        guard !appState.isBlocking else { return }
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        selectedSetId = id
        reloadContent()
    }

    @objc
    private func deleteRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        appState.deleteSet(id: id)
        if selectedSetId == id {
            selectedSetId = appState.ruleSets.first?.id
        }
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
        isSuggestionsExpanded.toggle()
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
        guard !appState.isBlocking else { return }
        selectedSetId = ruleSet.id
        reloadContent()
    }

    func deleteRuleSetForTesting(_ ruleSet: RuleSet) {
        appState.deleteSet(id: ruleSet.id)
        if selectedSetId == ruleSet.id {
            selectedSetId = appState.ruleSets.first?.id
        }
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
}
