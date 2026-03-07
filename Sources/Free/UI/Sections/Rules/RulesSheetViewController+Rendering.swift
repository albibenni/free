import AppKit

extension RulesSheetViewController {
    var selectedSet: RuleSet? {
        RulesSheetActionsCoordinator.selectedRuleSet(
            id: selectedSetId,
            ruleSets: appState.ruleSets
        )
    }

    func reloadContent() {
        withAppKitSignpost("RulesSheetReloadContent") {
            reloadGeneration += 1
            applyActionButtonStyling()

            selectedSetId = RulesSheetActionsCoordinator.fallbackSelectedSetId(
                currentSelectedId: selectedSetId,
                currentPrimaryRuleSetId: appState.currentPrimaryRuleSetId,
                ruleSets: appState.ruleSets
            )

            reloadSidebar()
            reloadRuleContent()
        }
    }

    func applyActionButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        configureAppKitIconButton(
            addRuleSetButton,
            symbol: AppKitUISymbols.addList,
            color: accentColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.06),
            cornerRadius: 11
        )
        applyAppKitSecondaryButtonStyle(addRuleButton, title: "Add", color: accentColor)
        applyAppKitNeutralButtonStyle(doneButton, title: "Done")
    }

    func reloadSidebar() {
        let canDelete = RulesSectionSupport.shouldShowDeleteSetButton(
            ruleSetCount: appState.ruleSets.count,
            isBlocking: appState.isBlocking
        )
        let rows = appState.ruleSets

        if canReuseSidebarRows(rows: rows) {
            for ruleSet in rows {
                sidebarRowsById[ruleSet.id]?.configure(
                    title: ruleSet.name,
                    ruleSetId: ruleSet.id,
                    isSelected: selectedSetId == ruleSet.id,
                    canDelete: canDelete,
                    onSelect: #selector(selectRuleSet(_:)),
                    onDelete: #selector(deleteRuleSet(_:)),
                    target: self
                )
            }
        } else {
            removeAllArrangedSubviews(from: sidebarScrollView.stackView)
            sidebarRowsById.removeAll()
            for ruleSet in rows {
                let row = RulesSheetLayoutBuilder.makeSidebarRow(
                    ruleSet: ruleSet,
                    isSelected: selectedSetId == ruleSet.id,
                    canDelete: canDelete,
                    onSelect: #selector(selectRuleSet(_:)),
                    onDelete: #selector(deleteRuleSet(_:)),
                    target: self
                )
                sidebarScrollView.stackView.addArrangedSubview(row)
                sidebarRowsById[ruleSet.id] = row
            }
        }
        sidebarScrollView.needsLayout = true
    }

    func canReuseSidebarRows(rows: [RuleSet]) -> Bool {
        guard rows.count == sidebarRowsById.count else { return false }
        guard rows.allSatisfy({ sidebarRowsById[$0.id] != nil }) else { return false }
        let expectedOrder = rows.map(\.id)
        let currentOrder = sidebarScrollView.stackView.arrangedSubviews.compactMap { view in
            (view as? RulesSheetSidebarRowView)?.ruleSetId
        }
        return expectedOrder == currentOrder
    }

    func reloadRuleContent() {
        withAppKitSignpost("RulesSheetReloadRuleContent") {
            mainTitleLabel.stringValue = selectedSet?.name ?? ""
            toggleSidebarButton.image = appKitSymbolImage(
                named: RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: isSidebarVisible),
                pointSize: 11,
                weight: .semibold,
                color: .secondaryLabelColor
            )

            guard let selectedSet else {
                noSelectionLabel.isHidden = false
                rulesHeaderLabel.isHidden = true
                rulesEmptyLabel.isHidden = true
                rulesRowsStack.isHidden = true
                suggestionsDivider.isHidden = true
                suggestionsButton.isHidden = true
                suggestionsEmptyLabel.isHidden = true
                suggestionsRowsStack.isHidden = true
                return
            }

            noSelectionLabel.isHidden = true
            rulesHeaderLabel.isHidden = false
            suggestionsDivider.isHidden = false
            suggestionsButton.isHidden = false

            let rules = selectedSet.urls
            ruleRowsByRule = RulesSheetLayoutBuilder.updateOrRebuildRuleRows(
                in: rulesRowsStack,
                rules: rules,
                existingRows: ruleRowsByRule,
                onDelete: #selector(deleteRule(_:)),
                target: self
            )
            rulesEmptyLabel.isHidden = !rules.isEmpty
            rulesRowsStack.isHidden = rules.isEmpty

            if isSuggestionsExpanded {
                let filtered = RulesSectionSupport.filterSuggestions(
                    appState.currentOpenUrls,
                    existing: selectedSet
                )
                let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
                if filtered.isEmpty {
                    suggestionsEmptyLabel.stringValue = RulesSectionSupport.suggestionsEmptyText(
                        currentOpenUrls: appState.currentOpenUrls
                    )
                    suggestionsEmptyLabel.isHidden = false
                    suggestionsRowsStack.isHidden = true
                } else {
                    suggestionRowsByUrl = RulesSheetLayoutBuilder.updateOrRebuildSuggestionRows(
                        in: suggestionsRowsStack,
                        suggestions: filtered,
                        accentColor: accentColor,
                        existingRows: suggestionRowsByUrl,
                        onAdd: #selector(addSuggestion(_:)),
                        target: self
                    )
                    suggestionsEmptyLabel.isHidden = true
                    suggestionsRowsStack.isHidden = false
                }
            } else {
                suggestionsEmptyLabel.isHidden = true
                suggestionsRowsStack.isHidden = true
            }

            contentScrollView.needsLayout = true
        }
    }

    func updateSidebarVisibility() {
        sidebarContainer.isHidden = !isSidebarVisible
    }
}
