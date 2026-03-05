import AppKit

final class FocusAllowedWebsitesWidgetView: AppKitCardView {
    init(appState: AppState, shellState: FreeShellState) {
        super.init(frame: .zero)

        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        contentStack.addArrangedSubview(
            makeAppKitHeaderRow(
                title: "Allowed Websites",
                symbolName: AppKitUISymbols.Name.globe,
                color: .systemBlue
            )
        )

        if appState.ruleSets.isEmpty {
            contentStack.addArrangedSubview(makeAppKitBodyLabel("No allow lists yet."))
        } else {
            contentStack.addArrangedSubview(makeAppKitSectionLabel("SELECT LIST"))

            let scrollView = VerticalStackScrollContainer(
                contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            )
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.heightAnchor.constraint(equalToConstant: 220).isActive = true

            for set in appState.ruleSets {
                let button = makeRuleSetButton(
                    set: set,
                    isSelected: appState.activeRuleSetId == set.id,
                    accentColor: accentColor
                ) {
                    appState.selectActiveRuleSet(set.id)
                }
                button.isEnabled = !appState.isStrictActive
                scrollView.stackView.addArrangedSubview(button)
                button.widthAnchor.constraint(equalTo: scrollView.stackView.widthAnchor).isActive = true
            }

            contentStack.addArrangedSubview(scrollView)
        }

        contentStack.addArrangedSubview(makeAppKitDividerView())

        let button = makeAppKitPrimaryButton(title: "Manage & Edit Lists", color: accentColor)
        button.onAction = { shellState.showRules = true }
        contentStack.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRuleSetButton(
        set: RuleSet,
        isSelected: Bool,
        accentColor: NSColor,
        action: @escaping () -> Void
    ) -> ActionButton {
        makeAppKitSelectableRowButton(
            title: set.name,
            isSelected: isSelected,
            accentColor: accentColor,
            action: action
        )
    }
}
