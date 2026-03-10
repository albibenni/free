import AppKit
import Foundation

enum AllowedWebsitesImportAlertPresenter {
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

    private final class SelectAllCoordinator: NSObject {
        private let checkboxes: [NSButton]

        init(checkboxes: [NSButton]) {
            self.checkboxes = checkboxes
        }

        @objc
        func toggleSelection(_ sender: NSButton) {
            let isSelected = sender.state == .on
            for checkbox in checkboxes where checkbox.isEnabled {
                checkbox.state = isSelected ? .on : .off
            }
        }
    }

    static func presentEmptyState(currentOpenUrls: [String]) {
        let alert = makeAlert()
        alert.messageText = "Import Open Tabs"
        alert.informativeText = RulesSectionSupport.suggestionsEmptyText(
            currentOpenUrls: currentOpenUrls
        )
        alert.addButton(withTitle: "OK")
        _ = runModal(alert)
    }

    static func presentCandidateSelection(
        candidates: [AllowedWebsitesImportCoordinator.Candidate],
        selectedSetName: String
    ) -> [String]? {
        let checkboxes = makeCandidateCheckboxes(candidates: candidates)
        let alert = makeAlert()
        alert.messageText = "Import Open Tabs"
        alert.informativeText = "Detected \(candidates.count) websites for \"\(selectedSetName)\"."
        alert.accessoryView = makeAccessoryView(checkboxes: checkboxes)
        alert.addButton(withTitle: "Add Selected")
        alert.addButton(withTitle: "Cancel")

        guard runModal(alert) == .alertFirstButtonReturn else { return nil }
        return AllowedWebsitesImportCoordinator.selectedRulesToImport(
            candidates: candidates,
            checkboxStates: checkboxes.map(\.state)
        )
    }

    private static func makeCandidateCheckboxes(
        candidates: [AllowedWebsitesImportCoordinator.Candidate]
    ) -> [NSButton] {
        candidates.map { candidate in
            let checkbox = NSButton(checkboxWithTitle: candidate.title, target: nil, action: nil)
            checkbox.state = candidate.defaultSelected ? .on : .off
            checkbox.isEnabled = candidate.isSelectable
            checkbox.font = .systemFont(ofSize: 12, weight: .regular)
            checkbox.alignment = .left
            return checkbox
        }
    }

    private static func makeAccessoryView(
        checkboxes: [NSButton]
    ) -> NSView {
        let containerSize = NSSize(width: 420, height: 260)
        let container = NSView(frame: NSRect(origin: .zero, size: containerSize))

        let selectAllCoordinator = SelectAllCoordinator(checkboxes: checkboxes)
        let selectAllCheckbox = NSButton(
            checkboxWithTitle: "Select all",
            target: selectAllCoordinator,
            action: #selector(SelectAllCoordinator.toggleSelection(_:))
        )
        selectAllCheckbox.state = .on
        selectAllCheckbox.font = .systemFont(ofSize: 12, weight: .semibold)
        selectAllCheckbox.frame = NSRect(x: 0, y: 236, width: 120, height: 20)
        container.addSubview(selectAllCheckbox)

        let scrollFrame = NSRect(x: 0, y: 0, width: 420, height: 228)
        let scrollView = NSScrollView(frame: scrollFrame)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        container.addSubview(scrollView)

        let rowHeight: CGFloat = 24
        let documentHeight = max(CGFloat(checkboxes.count) * rowHeight + 8, scrollFrame.height)
        let documentWidth = scrollFrame.width - 14
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: documentWidth, height: documentHeight))

        for (index, checkbox) in checkboxes.enumerated() {
            let y = documentHeight - CGFloat(index + 1) * rowHeight
            checkbox.frame = NSRect(x: 0, y: y, width: documentWidth, height: 20)
            documentView.addSubview(checkbox)
        }
        scrollView.documentView = documentView

        // Keep target alive for the full modal interaction.
        objc_setAssociatedObject(
            selectAllCheckbox,
            Unmanaged.passUnretained(selectAllCheckbox).toOpaque(),
            selectAllCoordinator,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return container
    }
}
