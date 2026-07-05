import AppKit
import Foundation

@MainActor
enum AllowedWebsitesRuleSetAlertPresenter {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse
    typealias EnvironmentProvider = () -> [String: String]
    typealias ClassLookup = (String) -> AnyClass?

    private static var makeAlertOverride: AlertFactory?
    private static var runModalOverride: AlertRunner?
    private static var runNativeModalOverride: AlertRunner?
    private static var environmentProviderOverride: EnvironmentProvider?
    private static var classLookupOverride: ClassLookup?

    static var makeAlert: AlertFactory {
        get { makeAlertOverride ?? defaultMakeAlert }
        set { makeAlertOverride = newValue }
    }
    static var runModal: AlertRunner {
        get { runModalOverride ?? defaultRunModal }
        set { runModalOverride = newValue }
    }
    static var runNativeModal: AlertRunner {
        get { runNativeModalOverride ?? defaultRunNativeModal }
        set { runNativeModalOverride = newValue }
    }
    static var environmentProvider: EnvironmentProvider {
        get { environmentProviderOverride ?? defaultEnvironmentProvider }
        set { environmentProviderOverride = newValue }
    }
    static var classLookup: ClassLookup {
        get { classLookupOverride ?? defaultClassLookup }
        set { classLookupOverride = newValue }
    }

    static func resetForTesting() {
        makeAlertOverride = nil
        runModalOverride = nil
        runNativeModalOverride = nil
        environmentProviderOverride = nil
        classLookupOverride = nil
    }

    private static func defaultMakeAlert() -> NSAlert {
        NSAlert()
    }

    private static func defaultRunNativeModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        alert.runModal()
    }

    private static func defaultEnvironmentProvider() -> [String: String] {
        ProcessInfo.processInfo.environment
    }

    private static func defaultClassLookup(_ name: String) -> AnyClass? {
        NSClassFromString(name)
    }

    private static func defaultRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if isRunningInTestProcess() {
            return .alertSecondButtonReturn
        }
        return runNativeModal(alert)
    }

    private static func isRunningInTestProcess() -> Bool {
        let environment = environmentProvider()
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES"] != nil { return true }
        if environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil {
            return true
        }
        return classLookup("XCTestCase") != nil
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

    static func confirmDeleteRuleSet(named name: String) -> Bool {
        let alert = makeAlert()
        alert.messageText = "Delete \"\(name)\"?"
        alert.informativeText = "This removes the list and all its allowed websites."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return runModal(alert) == .alertFirstButtonReturn
    }
}
