import AppKit

final class MainSidebarView: AppKitDynamicView {
    private let sidebarStack = NSStackView()
    private let headerRow = NSStackView()
    private let menuLabel = NSTextField(labelWithString: "Menu")
    private let sidebarToggleButton = NSButton()
    private let sidebarDivider = AppKitDynamicView()
    private let sectionButtonsStack = NSStackView()
    private let settingsDivider = AppKitDynamicView()
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var sectionButtons: [MainContentSection: NSButton] = [:]
    private var sectionEnabled: [MainContentSection: Bool] = [:]

    var onToggleSidebar: (() -> Void)?
    var onSelectSection: ((MainContentSection) -> Void)?

    private(set) var isSidebarVisible = false
    private(set) var selectedSection: MainContentSection = .focus
    private(set) var accentColorIndex = 0

    init(
        selectedSection: MainContentSection,
        isSidebarVisible: Bool,
        accentColorIndex: Int
    ) {
        self.selectedSection = selectedSection
        self.isSidebarVisible = isSidebarVisible
        self.accentColorIndex = accentColorIndex
        super.init(frame: .zero)
        backgroundColorProvider = { NSColor.windowBackgroundColor }
        translatesAutoresizingMaskIntoConstraints = false
        configureLayout()
        setSidebarVisible(isSidebarVisible)
        updateSelection(selectedSection: selectedSection, accentColorIndex: accentColorIndex)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSidebarVisible(_ isVisible: Bool) {
        isSidebarVisible = isVisible
        menuLabel.isHidden = !isVisible
        sectionButtonsStack.isHidden = !isVisible
        sidebarDivider.isHidden = !isVisible
        settingsDivider.isHidden = !isVisible
        sectionButtons[.settings]?.isHidden = !isVisible
        sidebarWidthConstraint?.constant = isVisible ? 180 : 56
        let symbolName = isVisible ? AppKitUISymbols.Name.sidebarLeft : AppKitUISymbols.Name.sidebarRight
        sidebarToggleButton.image = appKitSymbolImage(
            spec: AppKitUISymbolSpec(
                name: symbolName,
                pointSize: AppKitUISymbols.sidebarToggle.pointSize,
                weight: AppKitUISymbols.sidebarToggle.weight
            ),
            color: .secondaryLabelColor
        )
    }

    func updateSelection(selectedSection: MainContentSection, accentColorIndex: Int) {
        self.selectedSection = selectedSection
        self.accentColorIndex = accentColorIndex
        for (section, button) in sectionButtons {
            applySidebarButtonStyle(
                button,
                section: section,
                isSelected: selectedSection == section,
                accentColorIndex: accentColorIndex
            )
        }
    }

    func setSectionEnabled(_ section: MainContentSection, isEnabled: Bool) {
        sectionEnabled[section] = isEnabled
        guard let button = sectionButtons[section] else { return }
        applySidebarButtonStyle(
            button,
            section: section,
            isSelected: selectedSection == section,
            accentColorIndex: accentColorIndex
        )
    }

    func selectedBackgroundColor(for section: MainContentSection) -> NSColor? {
        sectionButtons[section]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:))
    }

    func leadingInset(for section: MainContentSection) -> CGFloat? {
        (sectionButtons[section] as? LeadingInsetActionButton)?.leadingInset
    }

    private func configureLayout() {
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 12
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebarStack)

        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        configureIconButton(sidebarToggleButton)
        sidebarToggleButton.target = self
        sidebarToggleButton.action = #selector(handleToggleSidebar)
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

        for section in [.focus, .schedules, .calendar, .pomodoro, .allowedWebsites] as [MainContentSection] {
            let button = sidebarButton(for: section)
            sectionButtons[section] = button
            sectionEnabled[section] = true
            sectionButtonsStack.addArrangedSubview(button)
        }

        settingsDivider.backgroundColorProvider = { NSColor.separatorColor }
        settingsDivider.translatesAutoresizingMaskIntoConstraints = false
        settingsDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        settingsDivider.widthAnchor.constraint(equalToConstant: 156).isActive = true

        let settingsButton = sidebarButton(for: .settings)
        sectionButtons[.settings] = settingsButton
        sectionEnabled[.settings] = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        [headerRow, sidebarDivider, sectionButtonsStack, spacer, settingsDivider, settingsButton]
            .forEach { sidebarStack.addArrangedSubview($0) }

        sidebarWidthConstraint = widthAnchor.constraint(equalToConstant: 56)
        sidebarWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            sidebarStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            sidebarStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            sidebarStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            sidebarStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    private func configureIconButton(_ button: NSButton) {
        button.identifier = NSUserInterfaceItemIdentifier("sidebar.toggle")
        configureAppKitIconButton(
            button,
            symbol: AppKitUISymbols.sidebarToggle,
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
        return button
    }

    private func applySidebarButtonStyle(
        _ button: NSButton,
        section: MainContentSection,
        isSelected: Bool,
        accentColorIndex: Int
    ) {
        let accentColor = FocusColor.nsColor(for: accentColorIndex)
        let isEnabled = sectionEnabled[section] ?? true
        let isActivelySelected = isEnabled && isSelected
        let gradientColors =
            isActivelySelected
            ? appKitAccentGradientColors(
                for: accentColor,
                topAlpha: 0.18,
                bottomAlpha: 0.12
            )
            : [.clear, .clear]
        let titleColor =
            isActivelySelected
            ? appKitAccentForegroundColor(for: accentColor)
            : (isEnabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor)
        let iconColor =
            isActivelySelected
            ? appKitAccentForegroundColor(for: accentColor)
            : (isEnabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor)
        let fontWeight: NSFont.Weight = isActivelySelected ? .semibold : .medium

        if let actionButton = button as? ActionButton {
            actionButton.setGradientBackground(
                colors: gradientColors,
                borderColor: nil,
                borderWidth: 0
            )
            button.layer?.backgroundColor = gradientColors.first?.cgColor
        } else {
            button.layer?.backgroundColor = (isActivelySelected ? gradientColors.first : .clear)?.cgColor
        }
        button.isEnabled = isEnabled
        button.image = appKitSymbolImage(
            spec: AppKitUISymbolSpec(
                name: section.icon,
                pointSize: AppKitUISymbols.sidebarSection.pointSize,
                weight: fontWeight
            ),
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

    private func section(for identifier: NSUserInterfaceItemIdentifier?) -> MainContentSection? {
        MainContentSection.allCases.first { section in
            identifier?.rawValue == section.rawValue
        }
    }

    @objc
    private func handleToggleSidebar() {
        onToggleSidebar?()
    }

    @objc
    private func handleSidebarButton(_ sender: NSButton) {
        guard sender.isEnabled else { return }
        guard let section = section(for: sender.identifier) else { return }
        onSelectSection?(section)
    }
}

extension MainSidebarView {
    func invokeSidebarButtonForTesting(identifierRawValue: String, isEnabled: Bool = true) {
        let button = NSButton()
        button.identifier = NSUserInterfaceItemIdentifier(identifierRawValue)
        button.isEnabled = isEnabled
        handleSidebarButton(button)
    }

    func removeSectionButtonForTesting(_ section: MainContentSection) {
        sectionButtons.removeValue(forKey: section)
    }

    func clearSectionEnabledForTesting(_ section: MainContentSection) {
        sectionEnabled.removeValue(forKey: section)
    }
}
