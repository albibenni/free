import AppKit
import Foundation
import Testing

@testable import FreeLogic

private final class RulesSheetPresenterSpy: RulesSheetPresenting {
    private(set) var presentCalls: [(window: NSWindow, selectedRuleSetId: UUID?)] = []
    private(set) var dismissCount = 0

    func present(for parentWindow: NSWindow, selectedRuleSetId: UUID?) {
        presentCalls.append((parentWindow, selectedRuleSetId))
    }

    func dismiss() {
        dismissCount += 1
    }
}

private final class SchedulesSheetPresenterSpy: SchedulesSheetPresenting {
    private(set) var presentWindows: [NSWindow] = []
    private(set) var dismissCount = 0
    let window: NSWindow?

    init(window: NSWindow? = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )) {
        self.window = window
    }

    func present(for parentWindow: NSWindow) {
        presentWindows.append(parentWindow)
    }

    func dismiss() {
        dismissCount += 1
    }
}

@Suite(.serialized)
struct MainSheetPresenterTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "MainSheetPresenterTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    @Test("MainSheetPresenter rules sheet handles guard, create, reuse, dismiss, and onClose")
    func rulesSheetBranches() {
        let appState = isolatedAppState(name: "rulesSheetBranches")
        let selectedId = UUID()
        appState.activeRuleSetId = selectedId

        var rulesCloseHandler: (() -> Void)?
        var createdCount = 0
        var latestSpy: RulesSheetPresenterSpy?
        var rulesDismissedCount = 0

        let presenter = MainSheetPresenter(
            appState: appState,
            onRulesDismissed: { rulesDismissedCount += 1 },
            onSchedulesDismissed: {},
            makeRulesSheetController: { onClose in
                createdCount += 1
                rulesCloseHandler = onClose
                let spy = RulesSheetPresenterSpy()
                latestSpy = spy
                return spy
            }
        )

        presenter.presentRules(from: nil)
        #expect(createdCount == 0)

        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        presenter.presentRules(from: parent)
        #expect(createdCount == 1)
        #expect(latestSpy?.presentCalls.count == 1)
        #expect(latestSpy?.presentCalls.first?.selectedRuleSetId == selectedId)

        presenter.presentRules(from: parent)
        #expect(createdCount == 1)
        #expect(latestSpy?.presentCalls.count == 2)

        presenter.dismissRules()
        #expect(latestSpy?.dismissCount == 1)

        presenter.dismissRules()
        #expect(latestSpy?.dismissCount == 1)

        presenter.presentRules(from: parent)
        #expect(createdCount == 2)

        rulesCloseHandler?()
        #expect(rulesDismissedCount == 1)
    }

    @MainActor
    @Test("MainSheetPresenter schedules sheet handles guard, attached-sheet replacement, reuse, dismiss, and onClose")
    func schedulesSheetBranches() {
        let appState = isolatedAppState(name: "schedulesSheetBranches")

        var schedulesCloseHandler: (() -> Void)?
        var createdCount = 0
        var latestSpy: SchedulesSheetPresenterSpy?
        var schedulesDismissedCount = 0

        let presenter = MainSheetPresenter(
            appState: appState,
            onRulesDismissed: {},
            onSchedulesDismissed: { schedulesDismissedCount += 1 },
            makeSchedulesSheetController: { onClose in
                createdCount += 1
                schedulesCloseHandler = onClose
                let spy = SchedulesSheetPresenterSpy()
                latestSpy = spy
                return spy
            }
        )

        presenter.presentSchedules(from: nil)
        #expect(createdCount == 0)

        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let foreignSheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        parent.beginSheet(foreignSheet)
        #expect(parent.attachedSheet === foreignSheet)

        presenter.presentSchedules(from: parent)
        #expect(createdCount == 1)
        #expect(latestSpy?.presentWindows.count == 1)
        #expect(parent.attachedSheet == nil)

        presenter.presentSchedules(from: parent)
        #expect(createdCount == 1)
        #expect(latestSpy?.presentWindows.count == 2)

        presenter.dismissSchedules()
        #expect(latestSpy?.dismissCount == 1)

        presenter.dismissSchedules()
        #expect(latestSpy?.dismissCount == 1)

        presenter.presentSchedules(from: parent)
        #expect(createdCount == 2)

        schedulesCloseHandler?()
        #expect(schedulesDismissedCount == 1)
    }
}
