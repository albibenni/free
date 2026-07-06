import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateReadModelCoordinatorTests {
    @Test("timeString formats minutes and seconds with zero padding")
    func timeStringFormatting() async throws {
        #expect(AppStateReadModelCoordinator.timeString(time: 0) == "00:00")
        #expect(AppStateReadModelCoordinator.timeString(time: 65) == "01:05")
        #expect(AppStateReadModelCoordinator.timeString(time: 3599) == "59:59")
    }

    @Test("rule projections delegate to RuleSetService semantics")
    func ruleProjections() async throws {
        let first = RuleSet(name: "One", urls: ["one.com"])
        let second = RuleSet(name: "Two", urls: ["two.com"])

        let context = AppStateReadModelCoordinator.RuleContext(
            ruleSets: [first, second],
            schedules: [],
            activeRuleSetId: second.id,
            pomodoroRuleSetId: nil,
            isPomodoroFocus: false,
            isBlocking: true,
            wasStartedBySchedule: false,
            allowSearchEngineWebsites: true,
            allowAIProviderWebsites: true
        )

        #expect(AppStateReadModelCoordinator.currentPrimaryRuleSetId(context: context) == second.id)
        #expect(AppStateReadModelCoordinator.currentPrimaryRuleSetName(context: context) == "Two")
        let allowedRules = Set(AppStateReadModelCoordinator.allowedRules(context: context))
        #expect(allowedRules.contains("two.com"))
        #expect(allowedRules.contains("google.com"))
        #expect(allowedRules.contains("duckduckgo.com"))
        #expect(allowedRules.contains("chatgpt.com"))
        #expect(allowedRules.contains("claude.ai"))
    }
}
