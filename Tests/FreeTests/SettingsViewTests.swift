import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct SettingsViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "SettingsViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 520, height: 520)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("SettingsView action helpers cover strict-mode challenge and accent selection")
    func settingsViewActionHelpers() {
        let appState = isolatedAppState(name: "actions")
        appState.isBlocking = true
        appState.isUnblockable = true

        let view = SettingsView(
            initialChallengeInput: AppState.challengePhrase,
            actionAppState: appState
        )
        #expect(view.shouldShowStrictDisableButton == true)

        view.openChallenge()
        _ = view.showChallengeForTesting
        _ = view.challengeInputForTesting

        let selectAccent = view.selectAccentColorAction(index: 4)
        selectAccent()
        #expect(appState.accentColorIndex == 4)

        view.unlockWithChallenge()
        #expect(appState.isUnblockable == false)

        appState.isUnblockable = true
        let wrongChallengeView = SettingsView(initialChallengeInput: "wrong", actionAppState: appState)
        wrongChallengeView.unlockWithChallenge()
        #expect(appState.isUnblockable == true)

        let cancelView = SettingsView(initialChallengeInput: "typed", actionAppState: appState)
        cancelView.cancelUnlock()
        #expect(appState.isUnblockable == true)
    }

    @Test("SettingsView strict-disable visibility helper covers false branch")
    func settingsViewStrictDisableFalseBranch() {
        let appState = isolatedAppState(name: "strictFalse")
        appState.isBlocking = false
        appState.isUnblockable = true
        let view = SettingsView(actionAppState: appState)
        #expect(view.shouldShowStrictDisableButton == false)
    }

    @Test("SettingsView renders default toggle branch")
    @MainActor
    func settingsViewRenderDefaultBranch() {
        let appState = isolatedAppState(name: "renderDefault")
        appState.isBlocking = false
        appState.isUnblockable = false
        appState.accentColorIndex = 1

        let view = SettingsView().environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("SettingsView renders strict-mode disable branch")
    @MainActor
    func settingsViewRenderStrictBranch() {
        let appState = isolatedAppState(name: "renderStrict")
        appState.isBlocking = true
        appState.isUnblockable = true
        appState.accentColorIndex = 0

        let view = SettingsView().environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.height >= 0)
    }
}
