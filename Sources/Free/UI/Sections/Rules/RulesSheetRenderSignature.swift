import Foundation

struct RulesSheetRenderSignature: Equatable {
    struct RuleSetSummary: Equatable {
        let id: UUID
        let name: String
    }

    let appearanceMode: AppearanceMode
    let accentColorIndex: Int
    let ruleSetSummaries: [RuleSetSummary]
    let selectedSetId: UUID?
    let selectedSetUrls: [String]
    let isBlocking: Bool
    let currentOpenUrls: [String]

    init(
        appState: AppState,
        isSuggestionsExpanded: Bool,
        currentSelectedSetId: UUID?
    ) {
        appearanceMode = appState.appearanceMode
        accentColorIndex = appState.accentColorIndex
        ruleSetSummaries = appState.ruleSets.map { RuleSetSummary(id: $0.id, name: $0.name) }
        let resolvedSelectedSetId = RulesSheetActionsCoordinator.fallbackSelectedSetId(
            currentSelectedId: currentSelectedSetId,
            currentPrimaryRuleSetId: appState.currentPrimaryRuleSetId,
            ruleSets: appState.ruleSets
        )
        selectedSetId = resolvedSelectedSetId
        selectedSetUrls = appState.ruleSets.first(where: { $0.id == resolvedSelectedSetId })?.urls ?? []
        isBlocking = appState.isBlocking
        currentOpenUrls = isSuggestionsExpanded ? appState.currentOpenUrls : []
    }
}
