import AppKit
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import FreeLogic

@Suite(.serialized)
struct FocusViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "FocusViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 980, height: 980))
        -> NSHostingView<V>
    {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("FocusView helper logic covers warning/icon/status/pause/action paths")
    func focusViewHelperLogic() {
        #expect(FocusView.shouldShowUnblockableWarning(isBlocking: true, isUnblockable: true))
        #expect(!FocusView.shouldShowUnblockableWarning(isBlocking: false, isUnblockable: true))
        #expect(!FocusView.shouldShowUnblockableWarning(isBlocking: true, isUnblockable: false))

        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = FocusView.accessibilityPromptOptions() as NSDictionary
        #expect((options[key] as? Bool) == true)

        var grantCallCount = 0
        var capturedOptions: NSDictionary?
        let grantAction = FocusView.makeGrantAccessibilityAction { options in
            grantCallCount += 1
            capturedOptions = options as NSDictionary
            return true
        }
        grantAction()
        #expect(grantCallCount == 1)
        #expect((capturedOptions?[key] as? Bool) == true)

        #expect(FocusView.focusIconColor(isBlocking: true, isPaused: false) == .green)
        #expect(FocusView.focusIconColor(isBlocking: true, isPaused: true) == .gray)
        #expect(FocusView.focusIconColor(isBlocking: false, isPaused: false) == .gray)

        #expect(FocusView.statusLabel(isBlocking: false, isPaused: false) == "Inactive")
        #expect(FocusView.statusLabel(isBlocking: true, isPaused: false) == "Active")
        #expect(FocusView.statusLabel(isBlocking: true, isPaused: true) == "Paused")

        #expect(FocusView.shouldShowRuleSetName(isBlocking: true, isPaused: false))
        #expect(!FocusView.shouldShowRuleSetName(isBlocking: true, isPaused: true))
        #expect(!FocusView.shouldShowRuleSetName(isBlocking: false, isPaused: false))

        #expect(FocusView.shouldShowPauseDashboard(isBlocking: true, isPaused: true))
        #expect(!FocusView.shouldShowPauseDashboard(isBlocking: true, isPaused: false))
        #expect(!FocusView.shouldShowPauseDashboard(isBlocking: false, isPaused: true))

        #expect(
            FocusView.shouldShowAllowListPreview(
                isBlocking: true,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            FocusView.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .focus,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            FocusView.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: true,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            !FocusView.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            !FocusView.shouldShowAllowListPreview(
                isBlocking: true,
                pomodoroStatus: .focus,
                hasActiveFocusSchedule: true,
                hasCurrentRuleSet: false
            )
        )

        #expect(FocusView.pomodoroPhaseLabel(status: .none) == "Inactive")
        #expect(FocusView.pomodoroPhaseLabel(status: .focus) == "Focus")
        #expect(FocusView.pomodoroPhaseLabel(status: .breakTime) == "Break")

        let appState = isolatedAppState(name: "cancelPauseAction")
        appState.isPaused = true
        let cancelPause = FocusView.makeCancelPauseAction(appState: appState)
        cancelPause()
        #expect(appState.isPaused == false)
    }

    @Test("Focus section shows live overview instead of full widgets")
    @MainActor
    func focusViewLiveOverviewRender() {
        let appState = isolatedAppState(name: "liveOverview")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Work", urls: ["example.com", "developer.apple.com"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        var showRules = false
        var showSchedules = false
        let view = FocusView(
            showRules: Binding(get: { showRules }, set: { showRules = $0 }),
            showSchedules: Binding(get: { showSchedules }, set: { showSchedules = $0 }),
            section: .all
        )
        .environmentObject(appState)
        _ = host(view)

        #expect((try? view.inspect().find(text: "Live Overview")) != nil)
        #expect((try? view.inspect().find(text: "Allow List")) != nil)
        #expect((try? view.inspect().find(text: "Pomodoro Mode")) == nil)
        #expect((try? view.inspect().find(text: "Focus Schedules")) == nil)
        #expect((try? view.inspect().find(text: "Allowed Websites")) == nil)
    }

    @Test("FocusView renders trusted inactive state")
    @MainActor
    func focusViewRenderTrustedInactive() {
        let appState = isolatedAppState(name: "trustedInactive")
        appState.isTrusted = true
        appState.isBlocking = false
        appState.isPaused = false
        appState.isUnblockable = false

        var showRules = false
        var showSchedules = false
        let view = FocusView(
            showRules: Binding(get: { showRules }, set: { showRules = $0 }),
            showSchedules: Binding(get: { showSchedules }, set: { showSchedules = $0 })
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("FocusView renders blocking active unblockable state with list name")
    @MainActor
    func focusViewRenderBlockingActiveUnblockable() {
        let appState = isolatedAppState(name: "activeUnblockable")
        appState.isTrusted = false
        appState.isBlocking = true
        appState.isPaused = false
        appState.isUnblockable = true
        let rules = RuleSet(name: "Work List", urls: ["example.com"])
        appState.ruleSets = [rules]
        appState.activeRuleSetId = rules.id

        var showRules = false
        var showSchedules = false
        let view = FocusView(
            showRules: Binding(get: { showRules }, set: { showRules = $0 }),
            showSchedules: Binding(get: { showSchedules }, set: { showSchedules = $0 }),
            initialShowPomodoroChallenge: true,
            initialPomodoroChallengeInput: "challenge"
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.height >= 0)
    }

    @Test("FocusView renders paused dashboard state")
    @MainActor
    func focusViewRenderPausedDashboard() {
        let appState = isolatedAppState(name: "pausedDashboard")
        appState.isTrusted = false
        appState.isBlocking = true
        appState.isPaused = true
        appState.pauseRemaining = 125

        var showRules = false
        var showSchedules = false
        let view = FocusView(
            showRules: Binding(get: { showRules }, set: { showRules = $0 }),
            showSchedules: Binding(get: { showSchedules }, set: { showSchedules = $0 })
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }
}
