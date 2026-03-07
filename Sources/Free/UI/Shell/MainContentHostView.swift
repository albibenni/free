import AppKit

final class MainContentHostView: NSView {
    weak var parentViewController: NSViewController?
    private(set) var currentViewController: NSViewController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ viewController: NSViewController) {
        guard currentViewController !== viewController,
              let parentViewController
        else { return }

        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        parentViewController.addChild(viewController)
        let childView = viewController.view
        childView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(childView)
        NSLayoutConstraint.activate([
            childView.leadingAnchor.constraint(equalTo: leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: trailingAnchor),
            childView.topAnchor.constraint(equalTo: topAnchor),
            childView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        currentViewController = viewController
    }
}
