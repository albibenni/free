import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    @objc
    func handleImportOpenTabs() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let selectedSet = appState.ruleSets.first(where: { $0.id == setId }) else { return }

        appState.refreshCurrentOpenUrls()
        let candidates = RulesSectionSupport.importableWebsiteCandidates(
            from: appState.currentOpenUrls,
            existing: selectedSet
        )

        guard !candidates.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Import Open Tabs"
            alert.informativeText = RulesSectionSupport.suggestionsEmptyText(
                currentOpenUrls: appState.currentOpenUrls
            )
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        importCandidateRules = candidates.map(\.rule)
        importCandidateCheckboxes = candidates.map { candidate in
            let checkbox = NSButton(checkboxWithTitle: candidate.rule, target: nil, action: nil)
            checkbox.title = candidate.isAlreadyAllowed
                ? "\(candidate.rule) (already allowed)"
                : candidate.rule
            checkbox.state = candidate.isAlreadyAllowed ? .off : .on
            checkbox.isEnabled = !candidate.isAlreadyAllowed
            checkbox.font = .systemFont(ofSize: 12, weight: .regular)
            checkbox.alignment = .left
            return checkbox
        }

        let selectAllCheckbox = NSButton(
            checkboxWithTitle: "Select all",
            target: self,
            action: #selector(toggleImportSelection(_:))
        )
        selectAllCheckbox.state = .on
        selectAllCheckbox.font = .systemFont(ofSize: 12, weight: .semibold)

        let containerSize = NSSize(width: 420, height: 260)
        let container = NSView(frame: NSRect(origin: .zero, size: containerSize))

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
        let documentHeight = max(CGFloat(importCandidateCheckboxes.count) * rowHeight + 8, scrollFrame.height)
        let documentWidth = scrollFrame.width - 14
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: documentWidth, height: documentHeight))

        for (index, checkbox) in importCandidateCheckboxes.enumerated() {
            let y = documentHeight - CGFloat(index + 1) * rowHeight
            checkbox.frame = NSRect(x: 0, y: y, width: documentWidth, height: 20)
            documentView.addSubview(checkbox)
        }
        scrollView.documentView = documentView

        let alert = NSAlert()
        alert.messageText = "Import Open Tabs"
        alert.informativeText = "Detected \(candidates.count) websites for \"\(selectedSet.name)\"."
        alert.accessoryView = container
        alert.addButton(withTitle: "Add Selected")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            for (index, checkbox) in importCandidateCheckboxes.enumerated()
                where checkbox.isEnabled && checkbox.state == .on
            {
                appState.addSpecificRule(importCandidateRules[index], to: setId)
            }
            reloadRulesOnly()
        }

        importCandidateCheckboxes = []
        importCandidateRules = []
    }

    @objc
    func toggleImportSelection(_ sender: NSButton) {
        let selectAll = sender.state == .on
        for checkbox in importCandidateCheckboxes {
            guard checkbox.isEnabled else { continue }
            checkbox.state = selectAll ? .on : .off
        }
    }
}
