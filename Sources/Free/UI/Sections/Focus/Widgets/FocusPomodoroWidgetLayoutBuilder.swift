import AppKit
import Foundation

@MainActor
enum FocusPomodoroWidgetLayoutBuilder {
    static func makePomodoroHeader() -> NSView {
        let chevronView = NSImageView()
        chevronView.image = appKitSymbolImage(
            spec: AppKitUISymbols.toggleSidebarChevron,
            color: .secondaryLabelColor
        )
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chevronView.heightAnchor.constraint(equalToConstant: 12).isActive = true

        return makeAppKitHeaderRow(
            title: "Pomodoro Mode",
            symbolName: AppKitUISymbols.Name.pomodoro,
            color: .systemRed,
            trailingView: chevronView
        )
    }

    static func makeDialAdjustmentButton(
        symbol: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> ActionButton {
        makeAppKitSymbolControlButton(
            symbol: symbol,
            isEnabled: isEnabled,
            pointSize: 24,
            dimension: 24,
            color: .secondaryLabelColor,
            action: action
        )
    }

    static func makeActiveRuleSetBadge(name: String) -> NSView {
        let container = AppKitFlippedView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        container.layer?.cornerRadius = 999

        let iconView = NSImageView()
        iconView.image = appKitSymbolImage(
            spec: AppKitUISymbols.activeRuleSet,
            color: .secondaryLabelColor
        )

        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabelColor

        let row = makeAppKitHorizontalRow(
            views: [iconView, label],
            alignment: .centerY,
            spacing: 6
        )
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        return container
    }

    static func makeRuleSetRowButton(
        set: RuleSet,
        isSelected: Bool,
        accentColor: NSColor,
        action: @escaping () -> Void
    ) -> AppKitSelectableRowButton {
        makeAppKitSelectableRowButton(
            title: set.name,
            isSelected: isSelected,
            accentColor: accentColor,
            action: action
        )
    }
}
