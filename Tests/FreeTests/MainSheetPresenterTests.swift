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

@Suite(.serialized)
@MainActor
struct MainSheetPresenterTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "MainSheetPresenterTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    @Test("MainSheetPresenter rules sheet handles guard, create, reuse, dismiss, and onClose")
    func rulesSheetBranches() async throws {
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
}
