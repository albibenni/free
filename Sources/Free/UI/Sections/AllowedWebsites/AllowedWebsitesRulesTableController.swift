import AppKit

final class AllowedWebsitesRulesTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var numberOfRules: () -> Int = { 0 }
    var ruleAt: (Int) -> String? = { _ in nil }

    func numberOfRows(in tableView: NSTableView) -> Int {
        numberOfRules()
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
        if let rule = ruleAt(row) {
            cellView.textField?.stringValue = rule
        }
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        RuleRowView()
    }
}

private final class RuleRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }

        let fill = NSColor.controlAccentColor.withAlphaComponent(0.48)
        let stroke = NSColor.controlAccentColor.withAlphaComponent(0.95)
        let rect = bounds.insetBy(dx: 2, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        fill.setFill()
        path.fill()

        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
