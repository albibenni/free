import AppKit
import Foundation

enum RulesSheetAlertPresenter {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse

    static var makeAlert: AlertFactory = defaultMakeAlert
    static var runModal: AlertRunner = defaultRunModal

    static func resetForTesting() {
        makeAlert = defaultMakeAlert
        runModal = defaultRunModal
    }

    private static func defaultMakeAlert() -> NSAlert {
        NSAlert()
    }

    private static func defaultRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if isRunningInTestProcess() {
            return .alertSecondButtonReturn
        }
        return alert.runModal()
    }

    private static func isRunningInTestProcess() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES"] != nil { return true }
        if environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }

    static func promptForNewRuleSetName() -> String? {
        let alert = makeAlert()
        alert.messageText = "New Allowed List"

        let input = NSTextField(string: "")
        input.placeholderString = "List Name"
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        guard runModal(alert) == .alertFirstButtonReturn else { return nil }
        return input.stringValue
    }
}
