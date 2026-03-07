import AppKit
import Foundation

enum RulesSheetAlertPresenter {
    static func promptForNewRuleSetName() -> String? {
        let alert = NSAlert()
        alert.messageText = "New Allowed List"

        let input = NSTextField(string: "")
        input.placeholderString = "List Name"
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return input.stringValue
    }
}
