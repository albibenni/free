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

    private func selectableRowButtons(in view: NSView) -> [AppKitSelectableRowButton] {
        var all: [AppKitSelectableRowButton] = []
        if let button = view as? AppKitSelectableRowButton {
            all.append(button)
        }
        for subview in view.subviews {
            all.append(contentsOf: selectableRowButtons(in: subview))
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
        #expect(buttons(in: inactiveHosted).first { $0.title == "Cust" }?.isEnabled == false)

        let strictState = isolatedAppState(name: "strictQuickBreak")
        strictState.isBlocking = true
        strictState.isUnblockable = true
        let strictHosted = host(FocusPomodoroWidgetView(appState: strictState))

        #expect(buttons(in: strictHosted).first { $0.title == "5m" }?.isEnabled == false)
        #expect(buttons(in: strictHosted).first { $0.title == "Cust" }?.isEnabled == false)
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
        let personalButton = selectableRowButtons(in: hosted).first { $0.displayedTitleForTesting == "Personal" }

        #expect(texts.contains("SELECT LIST"))
        #expect(personalButton?.isEnabled == true)
        personalButton?.performClick(nil)
        #expect(appState.activeRuleSetId == personal.id)

        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = true

        let strictHosted = host(FocusPomodoroWidgetView(appState: appState))
        let strictPersonalButton = selectableRowButtons(in: strictHosted).first { $0.displayedTitleForTesting == "Personal" }
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

    @Test("FocusPomodoroWidgetView ignores preset clicks while session is active")
    @MainActor
    func pomodoroWidgetPresetsDisabledWhileActive() {
        let appState = isolatedAppState(name: "presetsDisabledWhileActive")
        appState.pomodoroFocusDuration = 25
        appState.pomodoroBreakDuration = 5
        appState.startPomodoro()

        let activeHosted = host(FocusPomodoroWidgetView(appState: appState))
        let presetButton = buttons(in: activeHosted).first { $0.title == "45/15" }

        #expect(presetButton != nil)
        #expect(presetButton?.isEnabled == false)

        presetButton?.performClick(nil)
        #expect(appState.pomodoroFocusDuration == 25)
        #expect(appState.pomodoroBreakDuration == 5)
    }

    @Test("FocusPomodoroWidgetView refresh handles mode transitions and active updates")
    @MainActor
    func pomodoroWidgetRefreshTransitions() {
        let appState = isolatedAppState(name: "refreshTransitions")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id

        let widget = FocusPomodoroWidgetView(appState: appState)
        let hosted = host(widget)
        #expect(widget.refreshGeneration > 0)
        #expect(visibleText(in: hosted).contains("Start Focus Session"))

        appState.startPomodoro()
        appState.pomodoroRemaining = 60 * 20
        widget.refreshForStateChange()
        #expect(visibleText(in: hosted).contains("FOCUSING"))
        #expect(subviews(ofType: PomodoroProgressDialView.self, in: hosted).count == 1)

        appState.pomodoroStatus = .breakTime
        appState.pomodoroRemaining = 60 * 3
        widget.refreshForStateChange()
        #expect(visibleText(in: hosted).contains("BREAKING"))

        let beforeRebuildGeneration = widget.refreshGeneration
        appState.ruleSets.append(sampleRuleSet(name: "Third", url: "https://third.example"))
        widget.refreshForStateChange()
        #expect(widget.refreshGeneration > beforeRebuildGeneration)
    }

    @Test("FocusPomodoroWidgetView dial adjustment symbols change durations")
    @MainActor
    func pomodoroWidgetDialAdjustmentButtons() {
        let appState = isolatedAppState(name: "dialAdjustButtons")
        appState.pomodoroStatus = .none
        appState.pomodoroFocusDuration = 25
        appState.pomodoroBreakDuration = 10

        let hosted = host(FocusPomodoroWidgetView(appState: appState), size: CGSize(width: 900, height: 900))
        let symbolButtons = subviews(ofType: AppKitSymbolControlButton.self, in: hosted)
        #expect(symbolButtons.count >= 4)

        let focusBefore = appState.pomodoroFocusDuration
        let breakBefore = appState.pomodoroBreakDuration
        let plusButton = symbolButtons.first(where: { $0.symbolNameForTesting.contains("plus") })
        #expect(plusButton != nil)
        plusButton?.performClick(nil)

        #expect(appState.pomodoroFocusDuration != focusBefore || appState.pomodoroBreakDuration != breakBefore)
        #expect(appState.pomodoroFocusDuration >= 5)
        #expect(appState.pomodoroBreakDuration >= 5)
    }

    @Test("Pomodoro dial views cover draw and mouse interaction paths")
    @MainActor
    func pomodoroDialViewsInteractionCoverage() throws {
        var committedMinutes: [Double] = []
        var beginCount = 0
        var endCount = 0

        let durationDial = PomodoroDurationDialView(
            title: "FOCUS",
            durationMinutes: 25,
            maxMinutes: 120,
            iconName: AppKitUISymbols.Name.focus,
            color: .systemGreen,
            onInteractionDidBegin: { beginCount += 1 },
            onInteractionDidEnd: { endCount += 1 },
            onCommit: { committedMinutes.append($0) }
        )
        durationDial.frame = NSRect(x: 0, y: 0, width: 240, height: 240)
        durationDial.layoutSubtreeIfNeeded()
        #expect(durationDial.intrinsicContentSize == NSSize(width: 240, height: 240))

        let durationImage = NSImage(size: durationDial.bounds.size)
        durationImage.lockFocus()
        durationDial.draw(durationDial.bounds)
        durationImage.unlockFocus()
        durationDial.resetCursorRects()

        let dragWithoutDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 180, y: 120),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        durationDial.mouseDragged(with: dragWithoutDown)
        #expect(committedMinutes.isEmpty)

        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 220, y: 120),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let drag = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: NSPoint(x: 120, y: 220),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )
        let up = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 120, y: 220),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 3,
                clickCount: 1,
                pressure: 1
            )
        )
        durationDial.mouseDown(with: down)
        durationDial.mouseDragged(with: drag)
        durationDial.mouseUp(with: up)

        #expect(beginCount == 1)
        #expect(endCount == 1)
        #expect(committedMinutes.count == 1)

        durationDial.applyLocationForTesting(CGPoint(x: 200, y: 120), commit: false)
        let countAfterNoCommit = committedMinutes.count
        durationDial.applyLocationForTesting(CGPoint(x: 200, y: 120), commit: true)
        #expect(committedMinutes.count == countAfterNoCommit + 1)

        durationDial.setDurationMinutes(35)
        #expect(durationDial.durationMinutesForTesting == 35)

        let progressDial = PomodoroProgressDialView(
            progress: 1.6,
            iconName: AppKitUISymbols.Name.breakCup,
            color: .systemOrange,
            centerText: "12:00"
        )
        progressDial.frame = NSRect(x: 0, y: 0, width: 240, height: 240)
        progressDial.layoutSubtreeIfNeeded()
        #expect(progressDial.intrinsicContentSize == NSSize(width: 240, height: 240))

        let progressImage = NSImage(size: progressDial.bounds.size)
        progressImage.lockFocus()
        progressDial.draw(progressDial.bounds)
        progressImage.unlockFocus()

        progressDial.update(
            progress: -0.5,
            iconName: AppKitUISymbols.Name.focus,
            color: .systemBlue,
            centerText: "00:30"
        )
        progressImage.lockFocus()
        progressDial.draw(progressDial.bounds)
        progressImage.unlockFocus()

        progressDial.frame = .zero
        progressDial.draw(.zero)
    }

    @Test("FocusPomodoroWidgetView custom break and strict stop prompts use simulation hooks")
    @MainActor
    func pomodoroWidgetPromptSimulations() {
        let breakState = isolatedAppState(name: "promptCustomBreak")
        breakState.isBlocking = true
        breakState.isUnblockable = false

        let breakWidget = FocusPomodoroWidgetView(appState: breakState)
        breakWidget.customBreakPromptSimulation = { (.alertFirstButtonReturn, "7") }
        let breakHosted = host(breakWidget)
        let customButton = buttons(in: breakHosted).first { $0.title == "Cust" }
        #expect(customButton != nil)
        customButton?.performClick(nil)
        #expect(breakState.isPaused)
        #expect(breakState.pauseRemaining == 7 * 60)

        let lockedState = isolatedAppState(name: "promptStrictStop")
        lockedState.startPomodoro()
        lockedState.isBlocking = true
        lockedState.isUnblockable = true
        lockedState.pomodoroStartedAt = Date().addingTimeInterval(-20)
        let stopWidget = FocusPomodoroWidgetView(appState: lockedState)
        stopWidget.stopChallengePromptSimulation = {
            (.alertFirstButtonReturn, "wrong phrase")
        }
        let stopHosted = host(stopWidget)
        let stopButton = buttons(in: stopHosted).first { $0.title == "Stop" }
        #expect(stopButton != nil)
        stopButton?.performClick(nil)
        #expect(lockedState.pomodoroStatus != .none)

        stopWidget.stopChallengePromptSimulation = {
            (.alertFirstButtonReturn, AppState.challengePhrase)
        }
        stopButton?.performClick(nil)
        #expect(lockedState.pomodoroStatus == .none)

        let cancelBreakState = isolatedAppState(name: "promptCancelBreak")
        cancelBreakState.isBlocking = true
        cancelBreakState.isUnblockable = false
        let cancelBreakWidget = FocusPomodoroWidgetView(appState: cancelBreakState)
        cancelBreakWidget.customBreakPromptSimulation = { (.alertSecondButtonReturn, "") }
        let cancelBreakHosted = host(cancelBreakWidget)
        buttons(in: cancelBreakHosted).first { $0.title == "Cust" }?.performClick(nil)
        #expect(cancelBreakState.isPaused == false)
    }

    @Test("FocusPomodoroWidgetView refresh rebuilds active badge when rule-set visibility changes")
    @MainActor
    func pomodoroWidgetActiveBadgeRebuildBranches() {
        let appState = isolatedAppState(name: "activeBadgeRebuildBranches")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        appState.ruleSets = [work]
        appState.activeRuleSetId = work.id
        appState.startPomodoro()

        let widget = FocusPomodoroWidgetView(appState: appState)
        let hosted = host(widget)
        #expect(visibleText(in: hosted).contains("Work"))

        appState.ruleSets = []
        widget.refreshForStateChange()
        #expect(!visibleText(in: hosted).contains("Work"))

        appState.ruleSets = [work]
        appState.activeRuleSetId = work.id
        widget.refreshForStateChange()
        #expect(visibleText(in: hosted).contains("Work"))
    }

}
