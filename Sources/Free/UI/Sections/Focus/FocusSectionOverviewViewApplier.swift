import AppKit

@MainActor
enum FocusSectionOverviewViewApplier {
    static func apply(
        renderModel: FocusSectionOverviewRenderCoordinator.RenderModel,
        to overviewRowsStack: NSStackView,
        accentColorIndex: Int,
        availableWidth: CGFloat
    ) {
        removeAllArrangedSubviews(from: overviewRowsStack)

        for row in renderModel.rows {
            overviewRowsStack.addArrangedSubview(
                FocusSectionLayoutBuilder.makeOverviewRow(
                    iconName: row.iconName,
                    title: row.title,
                    value: row.value,
                    accentColorIndex: accentColorIndex,
                    availableWidth: availableWidth
                )
            )
        }

        guard let emptyStateText = renderModel.emptyStateText else { return }
        let emptyLabel = NSTextField(labelWithString: emptyStateText)
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        overviewRowsStack.addArrangedSubview(emptyLabel)
    }
}
