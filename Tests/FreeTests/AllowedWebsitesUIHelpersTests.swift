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

    @Test("Rule-set list builder reuses existing rows when shape is unchanged")
    func ruleSetListBuilderReuse() {
        let stack = NSStackView()
        stack.orientation = .vertical
        let firstId = UUID()
        let secondId = UUID()
        let initialRows = [
            AllowedWebsitesPresentationCoordinator.RuleSetRow(
                id: firstId,
                title: "First",
                isSelected: false
            ),
            AllowedWebsitesPresentationCoordinator.RuleSetRow(
                id: secondId,
                title: "Second",
                isSelected: true
            ),
        ]

        let initialButtons = AllowedWebsitesRuleSetListBuilder.rebuild(
            in: stack,
            rows: initialRows,
            accentColor: .systemBlue,
            isRowSelectionEnabled: true
        ) { _ in }

        let updatedRows = [
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
        let updatedButtons = AllowedWebsitesRuleSetListBuilder.updateOrRebuild(
            in: stack,
            rows: updatedRows,
            accentColor: .systemRed,
            isRowSelectionEnabled: false,
            existingButtons: initialButtons
        ) { _ in }

        #expect(updatedButtons[firstId] === initialButtons[firstId])
        #expect(updatedButtons[secondId] === initialButtons[secondId])
        #expect(updatedButtons[firstId]?.isSelectedState == true)
        #expect(updatedButtons[secondId]?.isSelectedState == false)
        #expect(updatedButtons[firstId]?.isEnabled == false)
        #expect(updatedButtons[secondId]?.isEnabled == false)
        #expect(updatedButtons[firstId]?.accentColor == .systemRed)
        #expect(updatedButtons[secondId]?.accentColor == .systemRed)
    }

    @Test("Rule-set list builder updateOrRebuild falls back to rebuild on id/title/order mismatches")
    func ruleSetListBuilderUpdateFallbacks() {
        let stack = NSStackView()
        stack.orientation = .vertical
        let firstId = UUID()
        let secondId = UUID()

        let initialRows = [
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: firstId, title: "First", isSelected: false),
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: secondId, title: "Second", isSelected: true),
        ]
        let initialButtons = AllowedWebsitesRuleSetListBuilder.rebuild(
            in: stack,
            rows: initialRows,
            accentColor: .systemBlue,
            isRowSelectionEnabled: true
        ) { _ in }

        // Title mismatch for an existing id should force rebuild.
        let titleChangedRows = [
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: firstId, title: "Renamed", isSelected: true),
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: secondId, title: "Second", isSelected: false),
        ]
        let titleChangedButtons = AllowedWebsitesRuleSetListBuilder.updateOrRebuild(
            in: stack,
            rows: titleChangedRows,
            accentColor: .systemGreen,
            isRowSelectionEnabled: true,
            existingButtons: initialButtons
        ) { _ in }
        #expect(titleChangedButtons[firstId] !== initialButtons[firstId])
        #expect(titleChangedButtons[firstId]?.displayedTitleForTesting == "Renamed")

        // Mismatched existing id set with same count should force rebuild.
        let foreignExisting = [UUID(): titleChangedButtons[firstId]!]
        let rebuiltFromMissingId = AllowedWebsitesRuleSetListBuilder.updateOrRebuild(
            in: stack,
            rows: titleChangedRows,
            accentColor: .systemOrange,
            isRowSelectionEnabled: false,
            existingButtons: foreignExisting
        ) { _ in }
        #expect(rebuiltFromMissingId.count == 2)
        #expect(stack.arrangedSubviews.count == 2)

        // Order mismatch should also force rebuild and reorder arranged subviews.
        let reversedRows = [
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: secondId, title: "Second", isSelected: true),
            AllowedWebsitesPresentationCoordinator.RuleSetRow(id: firstId, title: "Renamed", isSelected: false),
        ]
        let reorderedButtons = AllowedWebsitesRuleSetListBuilder.updateOrRebuild(
            in: stack,
            rows: reversedRows,
            accentColor: .systemPurple,
            isRowSelectionEnabled: true,
            existingButtons: rebuiltFromMissingId
        ) { _ in }
        #expect(reorderedButtons.count == 2)
        let orderedIds = stack.arrangedSubviews.compactMap { UUID(uuidString: $0.identifier?.rawValue ?? "") }
        #expect(orderedIds == [secondId, firstId])
    }
}
