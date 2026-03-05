import AppKit

final class FreeSheetContainerViewController: NSViewController {
    private let titleText: String
    private let hostedController: NSViewController
    private let onDone: () -> Void

    private let titleLabel = NSTextField(labelWithString: "")
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let divider = AppKitDynamicView()
    private let contentContainer = NSView()

    init(title: String, contentController: NSViewController, onDone: @escaping () -> Void) {
        titleText = title
        hostedController = contentController
        self.onDone = onDone
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

        titleLabel.stringValue = titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        doneButton.target = self
        doneButton.action = #selector(handleDone)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.widthAnchor.constraint(equalToConstant: 76).isActive = true
        doneButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        doneButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        doneButton.setContentHuggingPriority(.required, for: .horizontal)
        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .regular

        divider.backgroundColorProvider = { NSColor.separatorColor }

        [titleLabel, doneButton, divider, contentContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        addChild(hostedController)
        let hostedView = hostedController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(hostedView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            contentContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostedView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    @objc
    private func handleDone() {
        onDone()
    }
}
