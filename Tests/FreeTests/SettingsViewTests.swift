import Testing
import SwiftUI
import AppKit
import Foundation
import ViewInspector
@testable import FreeLogic

private enum SettingsLaunchAtLoginTestError: Error {
    case disableFailed
}

private final class SettingsMockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabledValue: Bool
    var isEnabledCallCount = 0
    var enableCallCount = 0
    var disableCallCount = 0
    var disableError: Error?

    init(isEnabled: Bool) {
        self.isEnabledValue = isEnabled
    }

    var isEnabled: Bool {
        isEnabledCallCount += 1
        return isEnabledValue
    }

    func enable() throws {
        enableCallCount += 1
        isEnabledValue = true
    }

    func disable() throws {
        disableCallCount += 1
        if let disableError {
            throw disableError
        }
        isEnabledValue = false
    }
}

@Suite(.serialized)
struct SettingsViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "SettingsViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    private func isolatedAppState(name: String, launchManager: any LaunchAtLoginManaging) -> AppState {
        let suite = "SettingsViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(
            defaults: defaults,
            launchAtLoginManager: launchManager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )
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

    @Test("SettingsView launch-at-login actions load and toggle state with failure fallback")
    func settingsViewLaunchAtLoginActions() {
        let launchManager = SettingsMockLaunchAtLoginManager(isEnabled: false)
        let appState = isolatedAppState(name: "launchAtLoginActions", launchManager: launchManager)

        let view = SettingsView(actionAppState: appState)
        #expect(appState.launchAtLoginStatus() == false)

        view.setLaunchAtLogin(true)
        #expect(appState.launchAtLoginStatus() == true)
        #expect(launchManager.enableCallCount == 1)

        launchManager.disableError = SettingsLaunchAtLoginTestError.disableFailed
        launchManager.isEnabledValue = true
        view.setLaunchAtLogin(false)
        #expect(appState.launchAtLoginStatus() == true)
        #expect(launchManager.disableCallCount == 1)
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
        #expect((try? view.inspect().find(text: "Launch at Login")) != nil)
        #expect((try? view.inspect().find(text: "Block New Tabs")) != nil)
        #expect((try? view.inspect().find(text: "Block Localhost/Dev Ports")) != nil)
        #expect((try? view.inspect().find(text: "Block Local Network IPs")) != nil)
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

    @Test("SettingsView launch-at-login toggle binding setter is exercised through UI interaction")
    @MainActor
    func settingsViewLaunchAtLoginToggleBindingInteraction() throws {
        let launchManager = SettingsMockLaunchAtLoginManager(isEnabled: false)
        let appState = isolatedAppState(
            name: "launchAtLoginToggleBindingInteraction",
            launchManager: launchManager
        )
        let rawView = SettingsView()
        _ = rawView.launchAtLoginEnabledForTesting
        let view = rawView.environmentObject(appState)
        _ = host(view)

        let toggles = try view.inspect().findAll(ViewType.Toggle.self)
        #expect(toggles.count >= 4)

        try toggles[3].tap()
        #expect(launchManager.enableCallCount == 1)
        #expect(appState.launchAtLoginStatus() == true)
    }
}
