import AppKit
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import FreeLogic

@Suite(.serialized)
struct PomodoroWidgetTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "PomodoroWidgetTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 760, height: 760))
        -> NSHostingView<V>
    {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func sampleRuleSet(name: String, url: String) -> RuleSet {
        RuleSet(name: name, urls: [url])
    }

    @Test("PomodoroWidget toggles expanded state and renders setup content")
    @MainActor
    func pomodoroWidgetExpandToSetup() throws {
        let appState = isolatedAppState(name: "expandSetup")
        appState.pomodoroStatus = .none

        var showChallenge = false
        var challengeInput = ""
        let sut = PomodoroWidget(
            showPomodoroChallenge: Binding(get: { showChallenge }, set: { showChallenge = $0 }),
            pomodoroChallengeInput: Binding(
                get: { challengeInput }, set: { challengeInput = $0 }),
            initialIsExpanded: true
        )
        .environmentObject(appState)

        let hosted = host(sut)
        #expect(hosted.fittingSize.width >= 0)
        #expect((try? sut.inspect().find(text: "Pomodoro Mode")) != nil)
        #expect((try? sut.inspect().find(text: "Start Focus Session")) != nil)
        #expect((try? sut.inspect().find(text: "PRESETS")) != nil)
        #expect((try? sut.inspect().find(text: "QUICK BREAK")) != nil)
        try sut.inspect().findAll(ViewType.Button.self).first?.tap()
    }

    @Test("PomodoroWidget renders active-mode content even when collapsed")
    @MainActor
    func pomodoroWidgetCollapsedButActive() throws {
        let appState = isolatedAppState(name: "collapsedActive")
        appState.pomodoroStatus = .focus
        appState.pomodoroRemaining = 1200

        var showChallenge = false
        var challengeInput = ""
        let sut = PomodoroWidget(
            showPomodoroChallenge: Binding(get: { showChallenge }, set: { showChallenge = $0 }),
            pomodoroChallengeInput: Binding(
                get: { challengeInput }, set: { challengeInput = $0 })
        )
        .environmentObject(appState)

        _ = host(sut)
        #expect((try? sut.inspect().find(text: "FOCUSING")) != nil)
        #expect((try? sut.inspect().find(text: "Skip")) != nil)
        #expect((try? sut.inspect().find(text: "Stop")) != nil)
    }

    @Test("PomodoroSidebar covers preset selection, quick-break pause, and custom toggle")
    @MainActor
    func pomodoroSidebarActions() throws {
        let appState = isolatedAppState(name: "sidebarActions")
        appState.isBlocking = true
        appState.isUnblockable = false
        appState.pomodoroFocusDuration = 25
        appState.pomodoroBreakDuration = 5

        var showCustomTimer = false
        let sut = PomodoroSidebar(
            showCustomTimer: Binding(
                get: { showCustomTimer }, set: { showCustomTimer = $0 })
        )
        .environmentObject(appState)

        _ = host(sut, size: CGSize(width: 300, height: 420))
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 8)

        try buttons[1].tap()
        #expect(appState.pomodoroFocusDuration == 45)
        #expect(appState.pomodoroBreakDuration == 15)

        try buttons[4].tap()
        #expect(appState.isPaused == true)
        #expect(appState.pauseRemaining > 0)

        try buttons[7].tap()
        #expect(showCustomTimer == true)
    }

    @Test("PomodoroSidebar quick-break controls are disabled in strict or inactive blocking states")
    @MainActor
    func pomodoroSidebarDisabledQuickBreaks() throws {
        let appState = isolatedAppState(name: "sidebarDisabled")
        appState.isBlocking = false
        appState.isUnblockable = false

        var showCustomTimer = false
        let sut = PomodoroSidebar(
            showCustomTimer: Binding(
                get: { showCustomTimer }, set: { showCustomTimer = $0 })
        )
        .environmentObject(appState)

        _ = host(sut, size: CGSize(width: 300, height: 420))
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        _ = try? buttons[4].tap()
        #expect(appState.isPaused == false)

        appState.isBlocking = true
        appState.isUnblockable = true
        let strictSut = PomodoroSidebar(
            showCustomTimer: Binding(
                get: { showCustomTimer }, set: { showCustomTimer = $0 })
        )
        .environmentObject(appState)
        _ = host(strictSut, size: CGSize(width: 300, height: 420))
        let strictButtons = try strictSut.inspect().findAll(ViewType.Button.self)
        _ = try? strictButtons[7].tap()
        #expect(showCustomTimer == false)
    }

    @Test("PomodoroRuleSetPicker shares active list selection and enforces strict-mode lock")
    @MainActor
    func pomodoroRuleSetPickerSelectionAndStrictLock() throws {
        let appState = isolatedAppState(name: "ruleSetPickerSelectionAndStrictLock")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = nil

        #expect(
            PomodoroRuleSetPicker.selectedRuleSetId(
                activeRuleSetId: appState.activeRuleSetId,
                ruleSets: appState.ruleSets
            ) == work.id
        )
        #expect(
            PomodoroRuleSetPicker.updatedActiveRuleSetId(
                currentActiveRuleSetId: work.id,
                selectedRuleSetId: personal.id,
                canSwitchRuleSetSelection: true
            ) == personal.id
        )
        #expect(
            PomodoroRuleSetPicker.updatedActiveRuleSetId(
                currentActiveRuleSetId: work.id,
                selectedRuleSetId: personal.id,
                canSwitchRuleSetSelection: false
            ) == work.id
        )

        let picker = PomodoroRuleSetPicker().environmentObject(appState)
        _ = host(picker, size: CGSize(width: 520, height: 320))
        #expect((try? picker.inspect().find(text: "SELECT LIST")) != nil)
        let personalButton = try picker.inspect().find(button: "Personal")
        try personalButton.tap()
        #expect(appState.activeRuleSetId == personal.id)

        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = true

        let strictPicker = PomodoroRuleSetPicker().environmentObject(appState)
        _ = host(strictPicker, size: CGSize(width: 520, height: 320))
        _ = try? strictPicker.inspect().find(button: "Personal").tap()
        #expect(appState.activeRuleSetId == work.id)
    }

    @Test("PomodoroRuleSetPicker hides list when no rule sets exist")
    @MainActor
    func pomodoroRuleSetPickerEmptyState() {
        let appState = isolatedAppState(name: "ruleSetPickerEmptyState")
        appState.ruleSets = []
        appState.activeRuleSetId = nil

        #expect(
            PomodoroRuleSetPicker.selectedRuleSetId(
                activeRuleSetId: appState.activeRuleSetId,
                ruleSets: appState.ruleSets
            ) == nil
        )

        let picker = PomodoroRuleSetPicker().environmentObject(appState)
        _ = host(picker, size: CGSize(width: 520, height: 320))
        #expect((try? picker.inspect().find(text: "SELECT LIST")) == nil)
    }

    @Test("Pomodoro list selection is reflected in Allowed Websites widget selection")
    @MainActor
    func pomodoroSelectionSharedWithAllowedWebsitesWidget() throws {
        let appState = isolatedAppState(name: "selectionSharedAcrossWidgets")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id

        let picker = PomodoroRuleSetPicker().environmentObject(appState)
        _ = host(picker, size: CGSize(width: 520, height: 320))
        try picker.inspect().find(button: "Personal").tap()
        #expect(appState.activeRuleSetId == personal.id)

        var showRules = false
        let allowedWidget = AllowedWebsitesWidget(
            showRules: Binding(get: { showRules }, set: { showRules = $0 })
        )
        .environmentObject(appState)
        _ = host(allowedWidget, size: CGSize(width: 520, height: 320))
        #expect((try? allowedWidget.inspect().find(text: "Personal")) != nil)
    }

    @Test("PomodoroSetupView +/- controls enforce min and max limits")
    @MainActor
    func pomodoroSetupViewDurationButtons() throws {
        let appState = isolatedAppState(name: "setupView")
        appState.pomodoroFocusDuration = 120
        appState.pomodoroBreakDuration = 5

        let sut = PomodoroSetupView().environmentObject(appState)
        _ = host(sut, size: CGSize(width: 720, height: 520))

        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 4)

        try buttons[1].tap()
        #expect(appState.pomodoroFocusDuration == 120)

        try buttons[0].tap()
        #expect(appState.pomodoroFocusDuration == 115)

        try buttons[2].tap()
        #expect(appState.pomodoroBreakDuration == 5)

        try buttons[3].tap()
        #expect(appState.pomodoroBreakDuration == 10)
    }

    @Test("PomodoroActiveView covers focus and break rendering branches")
    @MainActor
    func pomodoroActiveViewBranches() throws {
        let appState = isolatedAppState(name: "activeBranches")
        let set = sampleRuleSet(name: "Work", url: "https://work.example")
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        appState.pomodoroStatus = .focus
        appState.pomodoroRemaining = 600
        let focusView = PomodoroActiveView().environmentObject(appState)
        _ = host(focusView, size: CGSize(width: 520, height: 520))
        #expect((try? focusView.inspect().find(text: "FOCUSING")) != nil)
        #expect((try? focusView.inspect().find(text: "Work")) != nil)

        appState.pomodoroStatus = .breakTime
        appState.pomodoroRemaining = 300
        let breakView = PomodoroActiveView().environmentObject(appState)
        _ = host(breakView, size: CGSize(width: 520, height: 520))
        #expect((try? breakView.inspect().find(text: "BREAKING")) != nil)
        #expect((try? breakView.inspect().find(text: "Work")) == nil)
    }

    @Test("PomodoroActiveView keeps showing the session list after global selection changes")
    @MainActor
    func pomodoroActiveViewUsesSessionRuleSet() throws {
        let appState = isolatedAppState(name: "activeViewUsesSessionRuleSet")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id

        appState.startPomodoro()
        appState.activeRuleSetId = personal.id

        let view = PomodoroActiveView().environmentObject(appState)
        _ = host(view, size: CGSize(width: 520, height: 520))
        #expect((try? view.inspect().find(text: "Work")) != nil)
        #expect((try? view.inspect().find(text: "Personal")) == nil)
    }

    @Test("PomodoroActionButtons cover start, skip/stop, and locked challenge paths")
    @MainActor
    func pomodoroActionButtonsBranches() throws {
        let appState = isolatedAppState(name: "actionButtons")
        var showChallenge = false
        let binding = Binding(get: { showChallenge }, set: { showChallenge = $0 })

        appState.pomodoroStatus = .none
        let startButtons = PomodoroActionButtons(showPomodoroChallenge: binding)
            .environmentObject(appState)
        _ = host(startButtons, size: CGSize(width: 520, height: 140))
        try startButtons.inspect().findAll(ViewType.Button.self).first?.tap()
        #expect(appState.pomodoroStatus == .focus)

        appState.isUnblockable = false
        appState.pomodoroStartedAt = Date().addingTimeInterval(-20)
        let runningButtons = PomodoroActionButtons(showPomodoroChallenge: binding)
            .environmentObject(appState)
        _ = host(runningButtons, size: CGSize(width: 520, height: 140))
        let running = try runningButtons.inspect().findAll(ViewType.Button.self)
        #expect(running.count >= 2)

        try running[0].tap()
        #expect(appState.pomodoroStatus == .breakTime)

        appState.pomodoroStatus = .focus
        appState.pomodoroStartedAt = Date()
        try running[1].tap()
        #expect(appState.pomodoroStatus == .none)

        appState.pomodoroStatus = .focus
        appState.isUnblockable = true
        appState.pomodoroStartedAt = Date().addingTimeInterval(-20)
        let lockedButtons = PomodoroActionButtons(showPomodoroChallenge: binding)
            .environmentObject(appState)
        _ = host(lockedButtons, size: CGSize(width: 520, height: 140))
        let locked = try lockedButtons.inspect().findAll(ViewType.Button.self)
        _ = try? locked[0].tap()
        try locked[1].tap()
        #expect(showChallenge == true)
    }

    @Test("PomodoroWidget helper actions cover custom-break and challenge reset paths")
    func pomodoroWidgetHelperActions() {
        let appState = isolatedAppState(name: "widgetHelpers")
        appState.isBlocking = true

        var showChallenge = false
        var challengeInput = "not-valid"
        let sut = PomodoroWidget(
            showPomodoroChallenge: Binding(get: { showChallenge }, set: { showChallenge = $0 }),
            pomodoroChallengeInput: Binding(
                get: { challengeInput }, set: { challengeInput = $0 }),
            actionAppState: appState,
            initialCustomMinutesString: "12"
        )
        sut.startCustomBreakFromInput()
        #expect(appState.isPaused == true)
        #expect(appState.pauseRemaining > 0)

        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-20)

        challengeInput = AppState.challengePhrase
        sut.stopPomodoroFromChallengeInput()
        #expect(challengeInput.isEmpty)
        #expect(appState.pomodoroStatus == .none)

        challengeInput = "still here"
        sut.cancelChallengeInput()
        #expect(challengeInput.isEmpty)
    }

    @Test("PomodoroWidget alert actions are tappable through ViewInspector")
    @MainActor
    func pomodoroWidgetInitialAlerts() throws {
        let appState = isolatedAppState(name: "initialAlerts")
        appState.isBlocking = true

        var customStartVisible = false
        var customStartInput = ""
        let customStartWidget = PomodoroWidget(
            showPomodoroChallenge: Binding(
                get: { customStartVisible }, set: { customStartVisible = $0 }),
            pomodoroChallengeInput: Binding(
                get: { customStartInput }, set: { customStartInput = $0 }),
            actionAppState: appState,
            initialIsExpanded: true,
            initialShowCustomTimer: true,
            initialCustomMinutesString: "8"
        )
        .environmentObject(appState)
        _ = host(customStartWidget, size: CGSize(width: 760, height: 760))
        let customStartAlert = try customStartWidget.inspect().find(ViewType.Alert.self)
        try customStartAlert.actions().button(1).tap()
        #expect(appState.isPaused == true)

        var customCancelVisible = false
        var customCancelInput = ""
        let customCancelWidget = PomodoroWidget(
            showPomodoroChallenge: Binding(
                get: { customCancelVisible }, set: { customCancelVisible = $0 }),
            pomodoroChallengeInput: Binding(
                get: { customCancelInput }, set: { customCancelInput = $0 }),
            actionAppState: appState,
            initialIsExpanded: true,
            initialShowCustomTimer: true,
            initialCustomMinutesString: "12"
        )
        .environmentObject(appState)
        _ = host(customCancelWidget, size: CGSize(width: 760, height: 760))
        let customCancelAlert = try customCancelWidget.inspect().find(ViewType.Alert.self)
        try customCancelAlert.actions().button(2).tap()

        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-20)

        var emergencyStopVisible = true
        var emergencyStopInput = AppState.challengePhrase
        let emergencyStopWidget = PomodoroWidget(
            showPomodoroChallenge: Binding(
                get: { emergencyStopVisible }, set: { emergencyStopVisible = $0 }),
            pomodoroChallengeInput: Binding(
                get: { emergencyStopInput }, set: { emergencyStopInput = $0 }),
            actionAppState: appState,
            initialIsExpanded: true
        )
        .environmentObject(appState)
        _ = host(emergencyStopWidget, size: CGSize(width: 760, height: 760))
        let emergencyStopAlert = try emergencyStopWidget.inspect().find(ViewType.Alert.self)
        try emergencyStopAlert.actions().button(1).tap()
        #expect(appState.pomodoroStatus == .none)

        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-20)
        var emergencyCancelVisible = true
        var emergencyCancelInput = "keep-value"
        let emergencyCancelWidget = PomodoroWidget(
            showPomodoroChallenge: Binding(
                get: { emergencyCancelVisible }, set: { emergencyCancelVisible = $0 }),
            pomodoroChallengeInput: Binding(
                get: { emergencyCancelInput }, set: { emergencyCancelInput = $0 }),
            actionAppState: appState,
            initialIsExpanded: true
        )
        .environmentObject(appState)
        _ = host(emergencyCancelWidget, size: CGSize(width: 760, height: 760))
        let emergencyCancelAlert = try emergencyCancelWidget.inspect().find(ViewType.Alert.self)
        try emergencyCancelAlert.actions().button(2).tap()
        #expect(emergencyCancelInput.isEmpty)
    }
}
