import Foundation
import Testing

@testable import FreeLogic

struct AppStateReadModelCoordinatorTests {
    @Test("timeString formats minutes and seconds with zero padding")
    func timeStringFormatting() {
        #expect(AppStateReadModelCoordinator.timeString(time: 0) == "00:00")
        #expect(AppStateReadModelCoordinator.timeString(time: 65) == "01:05")
        #expect(AppStateReadModelCoordinator.timeString(time: 3599) == "59:59")
    }

    @Test("rule projections delegate to RuleSetService semantics")
    func ruleProjections() {
        let first = RuleSet(name: "One", urls: ["one.com"])
        let second = RuleSet(name: "Two", urls: ["two.com"])

        let context = AppStateReadModelCoordinator.RuleContext(
            ruleSets: [first, second],
            schedules: [],
            activeRuleSetId: second.id,
            pomodoroRuleSetId: nil,
            isPomodoroFocus: false,
            isBlocking: true,
            wasStartedBySchedule: false
        )

        #expect(AppStateReadModelCoordinator.currentPrimaryRuleSetId(context: context) == second.id)
        #expect(AppStateReadModelCoordinator.currentPrimaryRuleSetName(context: context) == "Two")
        #expect(AppStateReadModelCoordinator.allowedRules(context: context) == ["two.com"])
    }
}
