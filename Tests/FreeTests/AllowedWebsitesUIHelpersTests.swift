import AppKit
import Foundation
import Testing

@testable import FreeLogic

struct AllowedWebsitesUIHelpersTests {
    @Test("Control-state applier updates allowed-websites controls consistently")
    func controlStateApplier() {
        let urlField = NSTextField(string: "")
        let addButton = NSButton(title: "Add", target: nil, action: nil)
        let importButton = NSButton(title: "Import", target: nil, action: nil)
        let removeButton = NSButton(title: "Remove", target: nil, action: nil)
        let createButton = NSButton(title: "+", target: nil, action: nil)
        let deleteButton = NSButton(title: "-", target: nil, action: nil)
        let rowId = UUID()
        let rowButton = makeAppKitSelectableRowButton(
            title: "Default",
            isSelected: false,
            accentColor: .systemBlue
        ) {}

        let state = AllowedWebsitesPresentationCoordinator.ControlState(
            canEdit: false,
            canRemove: true,
            canCreateList: false,
            canDeleteList: true
        )
        AllowedWebsitesControlStateApplier.apply(
            state,
            urlField: urlField,
            addButton: addButton,
            importOpenTabsButton: importButton,
            removeButton: removeButton,
            createListButton: createButton,
            deleteListButton: deleteButton,
            ruleSetButtons: [rowId: rowButton]
        )

        #expect(!urlField.isEnabled)
        #expect(!addButton.isEnabled)
        #expect(!importButton.isEnabled)
        #expect(removeButton.isEnabled)
        #expect(!createButton.isEnabled)
        #expect(deleteButton.isEnabled)
        #expect(!rowButton.isEnabled)
    }

    @Test("Rule-set list builder rebuilds rows and wires taps")
    func ruleSetListBuilder() {
        let stack = NSStackView()
        stack.orientation = .vertical
        let firstId = UUID()
        let secondId = UUID()
        let rows = [
            AllowedWebsitesPresentationCoordinator.RuleSetRow(
                id: firstId,
                title: "First",
                isSelected: true
            ),
            AllowedWebsitesPresentationCoordinator.RuleSetRow(
                id: secondId,
                title: "Second",
                isSelected: false
            ),
        ]

        var selectedId: UUID?
        let buttons = AllowedWebsitesRuleSetListBuilder.rebuild(
            in: stack,
            rows: rows,
            accentColor: .systemBlue,
            isRowSelectionEnabled: true
        ) { tappedId in
            selectedId = tappedId
        }

        #expect(buttons.count == 2)
        #expect(stack.arrangedSubviews.count == 2)
        #expect(buttons[firstId]?.displayedTitleForTesting == "First")
        #expect(buttons[firstId]?.isSelectedState == true)
        #expect(buttons[secondId]?.displayedTitleForTesting == "Second")
        #expect(buttons[secondId]?.isSelectedState == false)

        buttons[secondId]?.performClick(nil)
        #expect(selectedId == secondId)

        let rebuilt = AllowedWebsitesRuleSetListBuilder.rebuild(
            in: stack,
            rows: [rows[0]],
            accentColor: .systemBlue,
            isRowSelectionEnabled: false
        ) { _ in }
        #expect(stack.arrangedSubviews.count == 1)
        #expect(rebuilt.count == 1)
        #expect(rebuilt[firstId]?.isEnabled == false)
    }
}
