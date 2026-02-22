import AppKit
import Foundation
import SwiftUI
import Testing
import ViewInspector

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
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 520, height: 520))
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

    @Test("AllowedWebsitesWidget collapsed summary renders active list")
    @MainActor
    func allowedWebsitesCollapsedSummary() throws {
        let appState = isolatedAppState(name: "collapsedSummary")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = personal.id

        var showRules = false
        let binding = Binding(get: { showRules }, set: { showRules = $0 })

        let sut = AllowedWebsitesWidget(showRules: binding)
            .environmentObject(appState)

        let hosted = host(sut)
        #expect(hosted.fittingSize.width >= 0)
        #expect((try? sut.inspect().find(text: "Allowed Websites")) != nil)
        #expect((try? sut.inspect().find(text: "Personal")) != nil)
        try sut.inspect().findAll(ViewType.Button.self).first?.tap()
    }

    @Test("AllowedWebsitesWidget expanded list supports selection and manage action")
    @MainActor
    func allowedWebsitesExpandedSelectionAndManage() throws {
        let appState = isolatedAppState(name: "expandedSelection")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.isBlocking = false

        var showRules = false
        let binding = Binding(get: { showRules }, set: { showRules = $0 })
        let sut = AllowedWebsitesWidget(showRules: binding, initialIsExpanded: true)
            .environmentObject(appState)

        #expect((try? sut.inspect().find(text: "SELECT LIST")) != nil)
        #expect((try? sut.inspect().find(text: "Manage & Edit Lists")) != nil)

        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 4)

        try buttons[2].tap()
        #expect(appState.activeRuleSetId == personal.id)

        try buttons.last?.tap()
        #expect(showRules == true)
    }

    @Test("AllowedWebsitesWidget allows list switching while blocking when strict mode is off")
    @MainActor
    func allowedWebsitesExpandedBlockingAllowsSwitchWhenNotStrict() throws {
        let appState = isolatedAppState(name: "blockingAllowsSwitchWhenNotStrict")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = false

        var showRules = false
        let binding = Binding(get: { showRules }, set: { showRules = $0 })
        let sut = AllowedWebsitesWidget(showRules: binding, initialIsExpanded: true)
            .environmentObject(appState)
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 4)

        try buttons[2].tap()
        #expect(appState.activeRuleSetId == personal.id)
    }

    @Test("AllowedWebsitesWidget blocks list switching during strict mode")
    @MainActor
    func allowedWebsitesExpandedStrictBlockingPreventsSwitch() throws {
        let appState = isolatedAppState(name: "strictBlockingGuard")
        let work = sampleRuleSet(name: "Work", url: "https://work.example")
        let personal = sampleRuleSet(name: "Personal", url: "https://personal.example")
        appState.ruleSets = [work, personal]
        appState.activeRuleSetId = work.id
        appState.isBlocking = true
        appState.isUnblockable = true

        var showRules = false
        let binding = Binding(get: { showRules }, set: { showRules = $0 })
        let sut = AllowedWebsitesWidget(showRules: binding, initialIsExpanded: true)
            .environmentObject(appState)
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 4)

        _ = try? buttons[2].tap()
        #expect(appState.activeRuleSetId == work.id)
    }
}
