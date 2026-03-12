import Foundation

enum AppStateReadModelCoordinator {
    struct RuleContext {
        let ruleSets: [RuleSet]
        let schedules: [Schedule]
        let activeRuleSetId: UUID?
        let pomodoroRuleSetId: UUID?
        let isPomodoroFocus: Bool
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
        let allowSearchEngineWebsites: Bool
        let allowAIProviderWebsites: Bool
    }

    static func currentPrimaryRuleSetId(context: RuleContext) -> UUID? {
        RuleSetService.currentPrimaryRuleSetId(
            ruleSets: context.ruleSets,
            schedules: context.schedules,
            activeRuleSetId: context.activeRuleSetId,
            pomodoroRuleSetId: context.pomodoroRuleSetId,
            isPomodoroFocus: context.isPomodoroFocus,
            isBlocking: context.isBlocking,
            wasStartedBySchedule: context.wasStartedBySchedule
        )
    }

    static func currentPrimaryRuleSetName(context: RuleContext) -> String {
        RuleSetService.currentPrimaryRuleSetName(
            ruleSets: context.ruleSets,
            schedules: context.schedules,
            currentPrimaryRuleSetId: currentPrimaryRuleSetId(context: context),
            isPomodoroFocus: context.isPomodoroFocus,
            isBlocking: context.isBlocking,
            wasStartedBySchedule: context.wasStartedBySchedule
        )
    }

    static func allowedRules(context: RuleContext) -> [String] {
        RuleSetService.allowedRules(
            ruleSets: context.ruleSets,
            schedules: context.schedules,
            activeRuleSetId: context.activeRuleSetId,
            pomodoroRuleSetId: context.pomodoroRuleSetId,
            isPomodoroFocus: context.isPomodoroFocus,
            isBlocking: context.isBlocking,
            wasStartedBySchedule: context.wasStartedBySchedule,
            allowSearchEngineWebsites: context.allowSearchEngineWebsites,
            allowAIProviderWebsites: context.allowAIProviderWebsites
        )
    }

    static func timeString(time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
