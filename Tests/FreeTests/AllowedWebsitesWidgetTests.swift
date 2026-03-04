import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct AllowedWebsitesWidgetTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "AllowedWebsitesWidgetTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(_ view: NSView, size: CGSize = CGSize(width: 520, height: 520)) -> NSView {
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

    private func sampleRuleSet(name: String, url: String) -> RuleSet {
        RuleSet(name: name, urls: [url])
    }

    @Test("FocusAllowedWebsitesWidget renders rule sets and opens list management")
    @MainActor
    func allowedWebsitesWidgetRenderAndManageAction() {
        let appState = isolatedAppState(name: "renderAndManage")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = personal.id

        let shellState = FreeShellState()
        let hosted = host(FocusAllowedWebsitesWidgetView(appState: appState, shellState: shellState))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Allowed Websites"))
        #expect(texts.contains("SELECT LIST"))
        #expect(texts.contains("Work"))
        #expect(texts.contains("Personal"))
        #expect(texts.contains("Manage & Edit Lists"))

        let manageButton = buttons(in: hosted).first { $0.title == "Manage & Edit Lists" }
        #expect(manageButton != nil)
        manageButton?.performClick(nil)
        #expect(shellState.showRules)
    }

    @Test("FocusAllowedWebsitesWidget updates the active rule set when selection is allowed")
    @MainActor
    func allowedWebsitesWidgetSelectionUpdatesAppState() {
        let appState = isolatedAppState(name: "selectionUpdates")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = false

        let hosted = host(FocusAllowedWebsitesWidgetView(appState: appState, shellState: FreeShellState()))
        let personalButton = buttons(in: hosted).first { $0.title == "Personal" }
        #expect(personalButton?.isEnabled == true)

        personalButton?.performClick(nil)
        #expect(appState.activeRuleSetId == personal.id)
    }

    @Test("FocusAllowedWebsitesWidget disables rule-set switching during strict mode")
    @MainActor
    func allowedWebsitesWidgetStrictModeLocksSelection() {
        let appState = isolatedAppState(name: "strictLock")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = true

        let hosted = host(FocusAllowedWebsitesWidgetView(appState: appState, shellState: FreeShellState()))
        let personalButton = buttons(in: hosted).first { $0.title == "Personal" }

        #expect(personalButton != nil)
        #expect(personalButton?.isEnabled == false)
        #expect(appState.activeRuleSetId == work.id)
    }

    @Test("FocusAllowedWebsitesWidget renders an empty state when no rule sets exist")
    @MainActor
    func allowedWebsitesWidgetEmptyState() {
        let appState = isolatedAppState(name: "emptyState")
        appState.ruleSets = []

        let hosted = host(FocusAllowedWebsitesWidgetView(appState: appState, shellState: FreeShellState()))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Allowed Websites"))
        #expect(texts.contains("No allow lists yet."))
        #expect(texts.contains("Manage & Edit Lists"))
    }
}
