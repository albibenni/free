import AppKit
import Combine

final class CalendarSectionViewController: NSViewController {
    private struct ObservationSignature: Equatable {
        let calendarIntegrationEnabled: Bool
        let calendarImportFocusTitleRules: [String]
        let calendarImportBreakTitleRules: [String]
    }

    private let appState: AppState
    private let scrollContainer = VerticalStackScrollContainer()
    private var cancellables: Set<AnyCancellable> = []

    private let integrationNotice = NSTextField(
        wrappingLabelWithString: "Enable Calendar Integration in Settings to use calendar title rules."
    )
    private let focusRulesField = NSTextField(string: "")
    private let breakRulesField = NSTextField(string: "")

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

        let titleLabel = NSTextField(labelWithString: "Calendar")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        scrollContainer.stackView.addArrangedSubview(titleLabel)

        let sectionTitle = NSTextField(labelWithString: "Import Rules")
        sectionTitle.font = .systemFont(ofSize: 18, weight: .semibold)
        scrollContainer.stackView.addArrangedSubview(sectionTitle)

        let section = makeCardSection()
        section.addArrangedSubview(integrationNotice)
        section.addArrangedSubview(
            makeTextFieldRow(
                title: "Focus Title Rules",
                description: "Comma-separated title keywords imported as Focus sessions.",
                textField: focusRulesField
            )
        )
        section.addArrangedSubview(
            makeTextFieldRow(
                title: "Break Title Rules",
                description: "Comma-separated title keywords imported as Break sessions.",
                textField: breakRulesField
            )
        )
        addFullWidthSection(section)

        configureRuleField(
            focusRulesField,
            placeholder: "e.g. Deep Work, Focus Block",
            action: #selector(updateFocusRules(_:))
        )
        configureRuleField(
            breakRulesField,
            placeholder: "e.g. Lunch, Break, Coffee",
            action: #selector(updateBreakRules(_:))
        )

        integrationNotice.font = .systemFont(ofSize: 12, weight: .medium)
        integrationNotice.textColor = .secondaryLabelColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let appState = self.appState
        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.settingsPublisher(appState: appState),
            signature: {
                ObservationSignature(
                    calendarIntegrationEnabled: appState.calendarIntegrationEnabled,
                    calendarImportFocusTitleRules: appState.calendarImportFocusTitleRules,
                    calendarImportBreakTitleRules: appState.calendarImportBreakTitleRules
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
        textField.target = self
        textField.action = action
        if let cell = textField.cell as? NSTextFieldCell {
            cell.sendsActionOnEndEditing = true
        }
        textField.controlSize = .regular
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeTextFieldRow(
        title: String,
        description: String,
        textField: NSTextField
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let descriptionLabel = makeDescriptionLabel(description)
        let stack = makeAppKitVerticalStack(
            views: [titleLabel, descriptionLabel, textField],
            alignment: .leading,
            spacing: 4
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func reload() {
        let enabled = appState.calendarIntegrationEnabled
        integrationNotice.isHidden = enabled
        focusRulesField.isEnabled = enabled
        breakRulesField.isEnabled = enabled
        if focusRulesField.currentEditor() == nil {
            focusRulesField.stringValue = appState.calendarImportFocusTitleRules.joined(separator: ", ")
        }
        if breakRulesField.currentEditor() == nil {
            breakRulesField.stringValue = appState.calendarImportBreakTitleRules.joined(separator: ", ")
        }
    }

    @objc
    private func updateFocusRules(_ sender: NSTextField) {
        appState.calendarImportFocusTitleRules = Self.parseRules(sender.stringValue)
    }

    @objc
    private func updateBreakRules(_ sender: NSTextField) {
        appState.calendarImportBreakTitleRules = Self.parseRules(sender.stringValue)
    }

    private static func parseRules(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}
