import Foundation

struct RulesSheetRenderSignature: Equatable {
    let appearanceMode: AppearanceMode
    let accentColorIndex: Int
    let ruleSets: [RuleSet]
    let currentPrimaryRuleSetId: UUID?
    let isBlocking: Bool
    let currentOpenUrls: [String]

    init(appState: AppState, isSuggestionsExpanded: Bool) {
        appearanceMode = appState.appearanceMode
        accentColorIndex = appState.accentColorIndex
        ruleSets = appState.ruleSets
        currentPrimaryRuleSetId = appState.currentPrimaryRuleSetId
        isBlocking = appState.isBlocking
        currentOpenUrls = isSuggestionsExpanded ? appState.currentOpenUrls : []
    }
}
