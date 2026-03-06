import AppKit
import Foundation

enum AllowedWebsitesControlStateApplier {
    static func apply(
        _ state: AllowedWebsitesPresentationCoordinator.ControlState,
        urlField: NSTextField,
        addButton: NSButton,
        importOpenTabsButton: NSButton,
        removeButton: NSButton,
        createListButton: NSButton,
        deleteListButton: NSButton,
        ruleSetButtons: [UUID: AppKitSelectableRowButton]
    ) {
        urlField.isEnabled = state.canEdit
        addButton.isEnabled = state.canEdit
        importOpenTabsButton.isEnabled = state.canEdit
        removeButton.isEnabled = state.canRemove
        createListButton.isEnabled = state.canCreateList
        deleteListButton.isEnabled = state.canDeleteList
        for button in ruleSetButtons.values {
            button.isEnabled = state.canCreateList
        }
    }
}
