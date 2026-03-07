import AppKit
import Foundation

enum AllowedWebsitesRuleSetAlertPresenter {
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

    static func confirmDeleteRuleSet(named name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete \"\(name)\"?"
        alert.informativeText = "This removes the list and all its allowed websites."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
