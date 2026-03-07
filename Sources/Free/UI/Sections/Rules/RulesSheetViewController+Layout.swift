import AppKit

extension RulesSheetViewController {
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

    func configureSidebar() {
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

    func configureMainContent() {
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

    func configureContentStructure() {
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

    func configureIconButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbolName: symbolName,
            color: .secondaryLabelColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.05),
            cornerRadius: 12
        )
    }
}
