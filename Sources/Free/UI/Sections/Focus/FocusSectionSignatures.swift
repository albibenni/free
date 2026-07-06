import Foundation

@MainActor
struct FocusPomodoroWidgetSignature: Equatable {
    struct RuleSetSnapshot: Equatable {
        let id: UUID
        let name: String
    }

    struct ContentSignature: Equatable {
        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let isBlocking: Bool
        let isStrictActive: Bool
        let pomodoroStatus: PomodoroStatus
        let pomodoroFocusDuration: Double
        let pomodoroBreakDuration: Double
        let pomodoroRemaining: TimeInterval
        let isPomodoroLocked: Bool
        let ruleSets: [RuleSetSnapshot]
    }

    let appearanceMode: AppearanceMode
    let accentColorIndex: Int
    let isBlocking: Bool
    let isStrictActive: Bool
    let pomodoroStatus: PomodoroStatus
    let pomodoroFocusDuration: Double
    let pomodoroBreakDuration: Double
    let pomodoroRemaining: TimeInterval
    let isPomodoroLocked: Bool
    let activeRuleSetId: UUID?
    let currentPrimaryRuleSetId: UUID?
    let ruleSets: [RuleSetSnapshot]

    var contentSignature: ContentSignature {
        ContentSignature(
            appearanceMode: appearanceMode,
            accentColorIndex: accentColorIndex,
            isBlocking: isBlocking,
            isStrictActive: isStrictActive,
            pomodoroStatus: pomodoroStatus,
            pomodoroFocusDuration: pomodoroFocusDuration,
            pomodoroBreakDuration: pomodoroBreakDuration,
            pomodoroRemaining: pomodoroRemaining,
            isPomodoroLocked: isPomodoroLocked,
            ruleSets: ruleSets
        )
    }

    init(appState: AppState) {
        appearanceMode = appState.appearanceMode
        accentColorIndex = appState.accentColorIndex
        isBlocking = appState.isBlocking
        isStrictActive = appState.isStrictActive
        pomodoroStatus = appState.pomodoroStatus
        pomodoroFocusDuration = appState.pomodoroFocusDuration
        pomodoroBreakDuration = appState.pomodoroBreakDuration
        pomodoroRemaining = appState.pomodoroRemaining
        isPomodoroLocked = appState.isPomodoroLocked
        activeRuleSetId = appState.activeRuleSetId
        currentPrimaryRuleSetId = appState.currentPrimaryRuleSetId
        ruleSets = appState.ruleSets.map { RuleSetSnapshot(id: $0.id, name: $0.name) }
    }
}

@MainActor
struct FocusSchedulesWidgetSignature: Equatable {
    let appearanceMode: AppearanceMode
    let accentColorIndex: Int
    let todaySchedules: [Schedule]

    init(appState: AppState) {
        appearanceMode = appState.appearanceMode
        accentColorIndex = appState.accentColorIndex
        todaySchedules = appState.todaySchedules
    }
}

@MainActor
struct FocusAllowedWebsitesWidgetSignature: Equatable {
    let appearanceMode: AppearanceMode
    let accentColorIndex: Int
    let activeRuleSetId: UUID?
    let isStrictActive: Bool
    let ruleSets: [RuleSet]

    init(appState: AppState) {
        appearanceMode = appState.appearanceMode
        accentColorIndex = appState.accentColorIndex
        activeRuleSetId = appState.activeRuleSetId
        isStrictActive = appState.isStrictActive
        ruleSets = appState.ruleSets
    }
}
