import AppKit
import Foundation

enum AllowedWebsitesImportAlertPresenter {
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
        let alert = NSAlert()
        alert.messageText = "Import Open Tabs"
        alert.informativeText = RulesSectionSupport.suggestionsEmptyText(
            currentOpenUrls: currentOpenUrls
        )
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func presentCandidateSelection(
        candidates: [AllowedWebsitesImportCoordinator.Candidate],
        selectedSetName: String
    ) -> [String]? {
        let checkboxes = makeCandidateCheckboxes(candidates: candidates)
        let alert = NSAlert()
        alert.messageText = "Import Open Tabs"
        alert.informativeText = "Detected \(candidates.count) websites for \"\(selectedSetName)\"."
        alert.accessoryView = makeAccessoryView(checkboxes: checkboxes)
        alert.addButton(withTitle: "Add Selected")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
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
