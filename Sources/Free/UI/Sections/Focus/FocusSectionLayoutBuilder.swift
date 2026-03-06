import AppKit
import Foundation

enum FocusSectionLayoutBuilder {
    static func configurePermissionWarning(
        permissionWarningView: AppKitDynamicView,
        permissionTitleLabel: NSTextField,
        grantPermissionButton: NSButton,
        target: AnyObject?,
        grantAction: Selector
    ) {
        permissionWarningView.wantsLayer = true
        permissionWarningView.layer?.backgroundColor = NSColor.systemRed.cgColor
        permissionWarningView.layer?.cornerRadius = 12

        let icon = NSImageView(
            image: NSImage(systemSymbolName: AppKitUISymbols.Name.warning, accessibilityDescription: nil) ?? NSImage()
        )
        icon.contentTintColor = .white

        permissionTitleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        permissionTitleLabel.textColor = .white

        grantPermissionButton.isBordered = false
        grantPermissionButton.wantsLayer = true
        grantPermissionButton.layer?.cornerRadius = 8
        grantPermissionButton.layer?.backgroundColor = NSColor.white.cgColor
        grantPermissionButton.contentTintColor = .black
        grantPermissionButton.font = .systemFont(ofSize: 12, weight: .semibold)
        grantPermissionButton.target = target
        grantPermissionButton.action = grantAction

        let row = makeAppKitHorizontalRow(
            views: [icon, permissionTitleLabel, NSView(), grantPermissionButton],
            alignment: .centerY,
            spacing: 10,
            edgeInsets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        )
        row.translatesAutoresizingMaskIntoConstraints = false

        permissionWarningView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: permissionWarningView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: permissionWarningView.trailingAnchor),
            row.topAnchor.constraint(equalTo: permissionWarningView.topAnchor),
            row.bottomAnchor.constraint(equalTo: permissionWarningView.bottomAnchor),
        ])
    }

    static func configureHeaderCard(
        headerCardView: AppKitDynamicView,
        headerIconView: NSImageView,
        headerTitleLabel: NSTextField,
        headerStatusLabel: NSTextField
    ) {
        headerCardView.backgroundColorProvider = { NSColor.controlBackgroundColor }
        headerCardView.layer?.cornerRadius = 12

        headerIconView.imageScaling = .scaleProportionallyUpOrDown
        headerIconView.symbolConfiguration = .init(pointSize: 30, weight: .regular)

        headerTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        headerStatusLabel.font = .systemFont(ofSize: 13)
        headerStatusLabel.textColor = .secondaryLabelColor

        let labelStack = makeAppKitVerticalStack(
            views: [headerTitleLabel, headerStatusLabel],
            alignment: .leading,
            spacing: 4
        )

        let row = makeAppKitHorizontalRow(
            views: [headerIconView, labelStack, NSView()],
            alignment: .centerY,
            spacing: 12,
            edgeInsets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )
        row.translatesAutoresizingMaskIntoConstraints = false

        headerCardView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: headerCardView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: headerCardView.trailingAnchor),
            row.topAnchor.constraint(equalTo: headerCardView.topAnchor),
            row.bottomAnchor.constraint(equalTo: headerCardView.bottomAnchor),
        ])
    }

    static func configurePauseDashboard(
        pauseDashboardView: AppKitDynamicView,
        pauseTitleLabel: NSTextField,
        pauseTimeLabel: NSTextField,
        pauseEndButton: NSButton,
        target: AnyObject?,
        cancelAction: Selector
    ) {
        pauseDashboardView.backgroundColorProvider = { NSColor.systemOrange.withAlphaComponent(0.1) }
        pauseDashboardView.layer?.cornerRadius = 12
        pauseDashboardView.borderColorProvider = { NSColor.systemOrange.withAlphaComponent(0.3) }
        pauseDashboardView.borderWidthValue = 1

        pauseTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        pauseTitleLabel.textColor = .secondaryLabelColor

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        pauseTimeLabel.textColor = .systemOrange
        pauseTimeLabel.alignment = .center

        pauseEndButton.bezelStyle = .rounded
        pauseEndButton.contentTintColor = .systemGreen
        pauseEndButton.target = target
        pauseEndButton.action = cancelAction

        let stack = makeAppKitVerticalStack(
            views: [pauseTitleLabel, pauseTimeLabel, pauseEndButton],
            alignment: .centerX,
            spacing: 10,
            edgeInsets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        pauseDashboardView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pauseDashboardView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: pauseDashboardView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: pauseDashboardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: pauseDashboardView.bottomAnchor),
        ])
    }

    static func configureOverview(
        overviewCardView: AppKitDynamicView,
        overviewTitleLabel: NSTextField,
        overviewRowsStack: NSStackView
    ) {
        overviewCardView.backgroundColorProvider = { NSColor.controlBackgroundColor }
        overviewCardView.layer?.cornerRadius = 12

        overviewTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        overviewRowsStack.orientation = .vertical
        overviewRowsStack.alignment = .leading
        overviewRowsStack.spacing = 10

        let stack = makeAppKitVerticalStack(
            views: [overviewTitleLabel, overviewRowsStack],
            alignment: .leading,
            spacing: 12,
            edgeInsets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        overviewCardView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: overviewCardView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: overviewCardView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: overviewCardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: overviewCardView.bottomAnchor),
        ])
    }

    static func makeOverviewRow(
        iconName: String,
        title: String,
        value: String,
        accentColorIndex: Int,
        availableWidth: CGFloat
    ) -> NSView {
        let icon = NSImageView(
            image: NSImage(systemSymbolName: iconName, accessibilityDescription: nil) ?? NSImage()
        )
        icon.contentTintColor = FocusColor.nsColor(for: accentColorIndex)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail

        let row = makeAppKitHorizontalRow(
            views: [icon, titleLabel, NSView(), valueLabel],
            alignment: .firstBaseline,
            spacing: 8
        )
        row.widthAnchor.constraint(equalToConstant: max(availableWidth, 1)).isActive = true
        return row
    }
}
