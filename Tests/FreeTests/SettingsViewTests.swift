import AppKit
import Foundation
import Testing

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
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 520, height: 620)
    ) -> NSView {
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        return controller.view
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

    private func visibleSwitchFrames(in view: NSView, root: NSView) -> [CGRect] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [CGRect] = []
        if let toggle = view as? NSSwitch {
            values.append(toggle.convert(toggle.bounds, to: root))
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleSwitchFrames(in: subview, root: root))
        }
        return values
    }

    @Test("Settings controller action helpers cover strict-mode challenge and accent selection")
    @MainActor
    func settingsControllerActionHelpers() {
        let appState = isolatedAppState(name: "actions")
        appState.isBlocking = true
        appState.isUnblockable = true

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        #expect(controller.shouldShowStrictDisableButtonForTesting)

        controller.selectAccentColorForTesting(index: 4)
        #expect(appState.accentColorIndex == 4)

        controller.disableStrictModeForTesting(phrase: AppState.challengePhrase)
        #expect(appState.isUnblockable == false)

        appState.isUnblockable = true
        controller.disableStrictModeForTesting(phrase: "wrong")
        #expect(appState.isUnblockable == true)
    }

    @Test("Settings controller launch-at-login actions load and toggle state with failure fallback")
    @MainActor
    func settingsControllerLaunchAtLoginActions() {
        let launchManager = SettingsMockLaunchAtLoginManager(isEnabled: false)
        let appState = isolatedAppState(name: "launchAtLoginActions", launchManager: launchManager)

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        #expect(controller.launchAtLoginEnabledForTesting == false)

        controller.setLaunchAtLoginForTesting(true)
        #expect(appState.launchAtLoginStatus() == true)
        #expect(launchManager.enableCallCount == 1)
        #expect(controller.launchAtLoginEnabledForTesting)

        launchManager.disableError = SettingsLaunchAtLoginTestError.disableFailed
        launchManager.isEnabledValue = true
        controller.setLaunchAtLoginForTesting(false)
        #expect(appState.launchAtLoginStatus() == true)
        #expect(launchManager.disableCallCount == 1)
        #expect(controller.launchAtLoginEnabledForTesting)
    }

    @Test("Settings controller strict-disable visibility helper covers false branch")
    @MainActor
    func settingsControllerStrictDisableFalseBranch() {
        let appState = isolatedAppState(name: "strictFalse")
        appState.isBlocking = false
        appState.isUnblockable = true
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        #expect(controller.shouldShowStrictDisableButtonForTesting == false)
    }

    @Test("Settings controller calendar controls lock only during strict active mode")
    @MainActor
    func settingsControllerCalendarControlsLockState() {
        let appState = isolatedAppState(name: "calendarControlsLockState")
        appState.isBlocking = false
        appState.isUnblockable = true
        let notStrict = SettingsSectionViewController(appState: appState)
        _ = host(notStrict)
        #expect(notStrict.calendarControlsLockedForTesting == false)

        appState.isBlocking = true
        let strict = SettingsSectionViewController(appState: appState)
        _ = host(strict)
        #expect(strict.calendarControlsLockedForTesting)
    }

    @Test("Settings controller renders default toggle branch")
    @MainActor
    func settingsControllerRenderDefaultBranch() {
        let appState = isolatedAppState(name: "renderDefault")
        appState.isBlocking = false
        appState.isUnblockable = false
        appState.accentColorIndex = 1

        let controller = SettingsSectionViewController(appState: appState)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)
        let toggleFrames = visibleSwitchFrames(in: hosted, root: hosted)

        #expect(hosted.fittingSize.width >= 0)
        #expect(texts.contains("Launch at Login"))
        #expect(texts.contains("Calendar Imports Block Time"))
        #expect(texts.contains("Resync Imported Schedules"))
        #expect(texts.contains("Block New Tabs"))
        #expect(texts.contains("Block Localhost/Dev Ports"))
        #expect(texts.contains("Block Local Network IPs"))
        #expect(toggleFrames.count == 8)
        if let referenceMaxX = toggleFrames.first?.maxX {
            for frame in toggleFrames {
                #expect(abs(frame.maxX - referenceMaxX) <= 2)
            }
        }
    }

    @Test("Settings controller renders strict-mode disable branch")
    @MainActor
    func settingsControllerRenderStrictBranch() {
        let appState = isolatedAppState(name: "renderStrict")
        appState.isBlocking = true
        appState.isUnblockable = true
        appState.accentColorIndex = 0

        let controller = SettingsSectionViewController(appState: appState)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.shouldShowStrictDisableButtonForTesting)
        #expect(texts.contains("Disable..."))
    }
}
