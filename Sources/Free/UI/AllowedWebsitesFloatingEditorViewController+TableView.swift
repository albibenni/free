import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRules.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AllowedRuleCell")
        let cellView =
            (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView)
            ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier
                let label = NSTextField(labelWithString: "")
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                label.textColor = .labelColor
                label.lineBreakMode = .byTruncatingMiddle
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(label)
                cell.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }()
        if row >= 0, row < visibleRules.count {
            cellView.textField?.stringValue = visibleRules[row]
        }
        return cellView
    }
}
