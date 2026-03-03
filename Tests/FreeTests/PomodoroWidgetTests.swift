import AppKit
import Foundation
import Testing

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
    private func host(_ view: NSView, size: CGSize = CGSize(width: 760, height: 760)) -> NSView {
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        return view
    }

    private func visibleText(in view: NSView) -> [String] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [String] = []
        if let label = view as? NSTextField, !label.stringValue.isEmpty {
            values.append(label.stringValue)
        }
        if let button = view as? NSButton, !button.title.isEmpty {
            values.append(button.title)
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleText(in: subview))
        }
        return values
    }

    private func buttons(in view: NSView) -> [NSButton] {
        var all: [NSButton] = []
        if let button = view as? NSButton {
            all.append(button)
        }
        for subview in view.subviews {
            all.append(contentsOf: buttons(in: subview))
        }
        return all
    }

    private func subviews<T: NSView>(ofType type: T.Type, in view: NSView) -> [T] {
        var all: [T] = []
        if let match = view as? T {
            all.append(match)
        }
        for subview in view.subviews {
            all.append(contentsOf: subviews(ofType: type, in: subview))
        }
        return all
    }

    private func sampleRuleSet(name: String, url: String) -> RuleSet {
        RuleSet(name: name, urls: [url])
    }

    @Test("FocusPomodoroWidgetView renders setup content when no session is active")
    @MainActor
    func pomodoroWidgetSetupRender() {
        let appState = isolatedAppState(name: "setupRender")
        appState.pomodoroStatus = .none

        let hosted = host(FocusPomodoroWidgetView(appState: appState))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Pomodoro Mode"))
        #expect(texts.contains("PRESETS"))
        #expect(texts.contains("QUICK BREAK"))
        #expect(texts.contains("Start Focus Session"))
    }

    @Test("FocusPomodoroWidgetView applies presets and quick breaks through AppKit buttons")
    @MainActor
    func pomodoroWidgetPresetAndQuickBreakActions() {
        let appState = isolatedAppState(name: "presetAndQuickBreak")
        appState.isBlocking = true
        appState.isUnblockable = false
        appState.pomodoroFocusDuration = 25
        appState.pomodoroBreakDuration = 5

        let hosted = host(FocusPomodoroWidgetView(appState: appState))
        let widgetButtons = buttons(in: hosted)

        let presetButton = widgetButtons.first { $0.title == "45/15" }
        let quickBreakButton = widgetButtons.first { $0.title == "5m" }

        #expect(presetButton != nil)
        #expect(quickBreakButton?.isEnabled == true)

        presetButton?.performClick(nil)
        #expect(appState.pomodoroFocusDuration == 45)
        #expect(appState.pomodoroBreakDuration == 15)

        quickBreakButton?.performClick(nil)
        #expect(appState.isPaused)
        #expect(appState.pauseRemaining > 0)
    }

    @Test("FocusPomodoroWidgetView exposes draggable AppKit dials that update durations")
    @MainActor
    func pomodoroWidgetDraggableDials() {
        let appState = isolatedAppState(name: "draggableDials")
        appState.pomodoroStatus = .none
        appState.pomodoroFocusDuration = 25
        appState.pomodoroBreakDuration = 5

        let hosted = host(FocusPomodoroWidgetView(appState: appState), size: CGSize(width: 900, height: 900))
        let dials = subviews(ofType: PomodoroDurationDialView.self, in: hosted)

        #expect(dials.count == 2)

        guard
            let focusDial = dials.first(where: { $0.titleForTesting == "FOCUS" }),
            let breakDial = dials.first(where: { $0.titleForTesting == "BREAK" })
        else {
            Issue.record("Expected both focus and break dials to be present")
            return
        }

        focusDial.applyLocationForTesting(
            CGPoint(x: focusDial.bounds.maxX - 18, y: focusDial.bounds.midY)
        )
        breakDial.applyLocationForTesting(
            CGPoint(x: breakDial.bounds.maxX - 18, y: breakDial.bounds.midY)
        )

        #expect(appState.pomodoroFocusDuration == 30)
        #expect(appState.pomodoroBreakDuration == 15)
        #expect(focusDial.durationMinutesForTesting == 30)
        #expect(breakDial.durationMinutesForTesting == 15)
    }

    @Test("FocusPomodoroWidgetView disables quick-break controls when blocking is inactive or strict")
    @MainActor
    func pomodoroWidgetQuickBreakDisabledStates() {
        let inactiveState = isolatedAppState(name: "inactiveQuickBreak")
        inactiveState.isBlocking = false
        inactiveState.isUnblockable = false
        let inactiveHosted = host(FocusPomodoroWidgetView(appState: inactiveState))

        #expect(buttons(in: inactiveHosted).first { $0.title == "5m" }?.isEnabled == false)
        #expect(buttons(in: inactiveHosted).first { $0.title == "Custom" }?.isEnabled == false)

        let strictState = isolatedAppState(name: "strictQuickBreak")
        strictState.isBlocking = true
        strictState.isUnblockable = true
        let strictHosted = host(FocusPomodoroWidgetView(appState: strictState))

        #expect(buttons(in: strictHosted).first { $0.title == "5m" }?.isEnabled == false)
        #expect(buttons(in: strictHosted).first { $0.title == "Custom" }?.isEnabled == false)
    }

    @Test("FocusPomodoroWidgetView selects rule sets and locks them during strict mode")
    @MainActor
    func pomodoroWidgetRuleSetSelectionAndStrictLock() {
        let appState = isolatedAppState(name: "ruleSetSelectionAndLock")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id

        let hosted = host(FocusPomodoroWidgetView(appState: appState))
        let texts = visibleText(in: hosted)
        let personalButton = buttons(in: hosted).first { $0.title == "Personal" }

        #expect(texts.contains("SELECT LIST"))
        #expect(personalButton?.isEnabled == true)
        personalButton?.performClick(nil)
        #expect(appState.activeRuleSetId == personal.id)

        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = true

        let strictHosted = host(FocusPomodoroWidgetView(appState: appState))
        let strictPersonalButton = buttons(in: strictHosted).first { $0.title == "Personal" }
        #expect(strictPersonalButton?.isEnabled == false)
        #expect(appState.activeRuleSetId == work.id)
    }

    @Test("FocusPomodoroWidgetView keeps showing the session rule set after selection changes")
    @MainActor
    func pomodoroWidgetUsesSessionRuleSet() {
        let appState = isolatedAppState(name: "usesSessionRuleSet")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.startPomodoro()
        appState.activeRuleSetId = personal.id

        let hosted = host(FocusPomodoroWidgetView(appState: appState))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("FOCUSING"))
        #expect(appState.currentPrimaryRuleSetId == work.id)
        #expect(texts.filter { $0 == "Work" }.count > texts.filter { $0 == "Personal" }.count)
    }

    @Test("FocusPomodoroWidgetView start, skip, and stop actions update AppState")
    @MainActor
    func pomodoroWidgetStartSkipStopFlow() {
        let appState = isolatedAppState(name: "startSkipStopFlow")

        let idleHosted = host(FocusPomodoroWidgetView(appState: appState))
        let startButton = buttons(in: idleHosted).first { $0.title == "Start Focus Session" }
        #expect(startButton != nil)

        startButton?.performClick(nil)
        #expect(appState.pomodoroStatus == .focus)

        let activeHosted = host(FocusPomodoroWidgetView(appState: appState))
        let activeTexts = visibleText(in: activeHosted)
        #expect(subviews(ofType: PomodoroProgressDialView.self, in: activeHosted).count == 1)
        #expect(activeTexts.contains("FOCUSING"))
        #expect(activeTexts.contains("Skip"))
        #expect(activeTexts.contains("Stop"))

        let skipButton = buttons(in: activeHosted).first { $0.title == "Skip" }
        skipButton?.performClick(nil)
        #expect(appState.pomodoroStatus == .breakTime)

        appState.pomodoroStatus = .focus
        let runningHosted = host(FocusPomodoroWidgetView(appState: appState))
        let stopButton = buttons(in: runningHosted).first { $0.title == "Stop" }
        stopButton?.performClick(nil)
        #expect(appState.pomodoroStatus == .none)
    }
}
