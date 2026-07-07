import AppKit

@MainActor
func removeArrangedSubviews(from stackView: NSStackView) {
    let arrangedSubviews = stackView.arrangedSubviews
    arrangedSubviews.forEach { subview in
        stackView.removeArrangedSubview(subview)
        subview.removeFromSuperview()
    }
}

final class EditorSectionView: AppKitFlippedView {
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
