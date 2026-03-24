import AppKit

enum StrictModeChallenge {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse

    static var makeAlert: AlertFactory = defaultMakeAlert
    static var runAlert: AlertRunner = defaultRunAlert

    private static func defaultMakeAlert() -> NSAlert { NSAlert() }
    private static func defaultRunAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if AppDelegate.isRunningInTestProcess() {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }

    /// Shows the challenge phrase dialog. Returns true if the correct phrase was entered.
    static func run(
        title: String,
        action: String,
        appState: AppState,
        makeAlert: AlertFactory? = nil,
        runAlert: AlertRunner? = nil
    ) -> Bool {
        let alertFactory = makeAlert ?? Self.makeAlert
        let alertRunner = runAlert ?? Self.runAlert

        let alert = alertFactory()
        alert.messageText = title
        alert.informativeText = ""
        let (accessoryView, input) = makeAccessoryView(action: action, appState: appState)
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")
        let isTesting = AppDelegate.isRunningInTestProcess()
        if !isTesting {
            alert.layout()
            alert.window.makeFirstResponder(input)
        }
        let response = alertRunner(alert)
        guard response == .alertFirstButtonReturn else { return false }
        return input.stringValue == AppState.challengePhrase
    }

    static func makeAccessoryView(action: String, appState: AppState) -> (NSView, NSTextField) {
        let containerWidth: CGFloat = 300
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 120))
        container.translatesAutoresizingMaskIntoConstraints = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let quote = NSTextField(
            wrappingLabelWithString:
                "The moment you give up is the moment you let someone else win. — Kobe Bryant")
        quote.font = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 13, weight: .heavy), toHaveTrait: .italicFontMask)
        quote.textColor = FocusColor.nsColor(for: appState.accentColorIndex)
        quote.alignment = .center
        quote.translatesAutoresizingMaskIntoConstraints = false

        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let phraseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let instructionText = NSMutableAttributedString(
            string: "Type the phrase ", attributes: boldAttrs)
        instructionText.append(
            NSAttributedString(string: "\"\(AppState.challengePhrase)\" ", attributes: phraseAttrs))
        instructionText.append(
            NSAttributedString(string: "to \(action):", attributes: boldAttrs))

        let instruction = NSTextField(wrappingLabelWithString: "")
        instruction.attributedStringValue = instructionText
        instruction.translatesAutoresizingMaskIntoConstraints = false

        let input = NSTextField(string: "")
        input.placeholderString = "Type the phrase..."
        input.translatesAutoresizingMaskIntoConstraints = false
        input.controlSize = .regular

        stack.addArrangedSubview(quote)
        stack.addArrangedSubview(instruction)
        stack.addArrangedSubview(input)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            quote.widthAnchor.constraint(equalTo: container.widthAnchor),
            instruction.widthAnchor.constraint(equalTo: container.widthAnchor),
            input.widthAnchor.constraint(equalTo: container.widthAnchor),
            input.heightAnchor.constraint(equalToConstant: 24),
        ])
        container.layoutSubtreeIfNeeded()
        return (container, input)
    }
}
