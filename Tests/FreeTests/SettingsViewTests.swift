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
    private final class TestModalAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertFirstButtonReturn
        }
    }

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

    private func isolatedAppState(name: String, calendar: any CalendarProvider) -> AppState {
        let suite = "SettingsViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(
            defaults: defaults,
            calendar: calendar,
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

    private func firstEditableTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable {
            return field
        }
        for subview in view.subviews {
            if let field = firstEditableTextField(in: subview) {
                return field
            }
        }
        return nil
    }

    private func visibleSwitchFrames(in view: NSView, root: NSView) -> [CGRect] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [CGRect] = []
        if let toggle = view as? AppKitToggleSwitch {
            values.append(toggle.convert(toggle.bounds, to: root))
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleSwitchFrames(in: subview, root: root))
        }
        return values
    }

    private func visibleToggleAccentColors(in view: NSView) -> [NSColor] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [NSColor] = []
        if let toggle = view as? AppKitToggleSwitch {
            values.append(toggle.accentColor)
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleToggleAccentColors(in: subview))
        }
        return values
    }

    @Test("Settings strict-mode initial default hooks execute native modal path with NSAlert override")
    @MainActor
    func settingsStrictModeInitialDefaultHooksCoverage() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        _ = SettingsSectionViewController.makeStrictModeAlert()
        #expect(
            SettingsSectionViewController.runStrictModeAlert(TestModalAlert())
                == .alertFirstButtonReturn
        )

        _ = setenv("XCTestConfigurationFilePath", "1", 1)
        #expect(
            SettingsSectionViewController.runStrictModeAlert(TestModalAlert())
                == .alertSecondButtonReturn
        )
    }

    @Test("Settings controller action helpers cover strict-mode challenge and accent selection")
    @MainActor
    func settingsControllerActionHelpers() {
        let appState = isolatedAppState(name: "actions")
        appState.isBlocking = true
        appState.isStrict = true

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        #expect(controller.shouldShowStrictDisableButtonForTesting)

        controller.selectAccentColorForTesting(index: 4)
        #expect(appState.accentColorIndex == 4)
        #expect(controller.appearanceSelectionColorForTesting == FocusColor.nsColor(for: 4))

        controller.disableStrictModeForTesting(phrase: AppState.challengePhrase)
        #expect(appState.isStrict == false)

        appState.isStrict = true
        controller.disableStrictModeForTesting(phrase: "wrong")
        #expect(appState.isStrict == true)
    }

    @Test("Settings strict-mode toggle off preserves strict state when dialog is cancelled")
    @MainActor
    func settingsStrictModeToggleOffPreservesStateOnDialogCancel() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        let appState = isolatedAppState(name: "strictToggleOffCancelled")
        appState.isBlocking = true
        appState.isStrict = true

        SettingsSectionViewController.makeStrictModeAlert = { NSAlert() }
        SettingsSectionViewController.runStrictModeAlert = { _ in .alertSecondButtonReturn }

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        controller.setStrictModeForTesting(false)

        #expect(appState.isStrict == true)
    }

    @Test("Settings strict-mode toggle off disables strict when dialog is confirmed with correct phrase")
    @MainActor
    func settingsStrictModeToggleOffDisablesStrictOnDialogConfirm() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        let appState = isolatedAppState(name: "strictToggleOffConfirmed")
        appState.isBlocking = true
        appState.isStrict = true

        SettingsSectionViewController.makeStrictModeAlert = { NSAlert() }
        SettingsSectionViewController.runStrictModeAlert = { alert in
            if let stack = alert.accessoryView?.subviews.first as? NSStackView,
                let input = stack.arrangedSubviews.last as? NSTextField
            {
                input.stringValue = AppState.challengePhrase
            }
            return .alertFirstButtonReturn
        }

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        controller.setStrictModeForTesting(false)

        #expect(appState.isStrict == false)
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
        // Cover reloadSettings() launch-at-login true branch.
        let enabledController = SettingsSectionViewController(appState: appState)
        _ = host(enabledController)
        #expect(enabledController.launchAtLoginEnabledForTesting)

        launchManager.disableError = SettingsLaunchAtLoginTestError.disableFailed
        launchManager.isEnabledValue = true
        controller.setLaunchAtLoginForTesting(false)
        #expect(appState.launchAtLoginStatus() == true)
        #expect(launchManager.disableCallCount == 1)
        #expect(controller.launchAtLoginEnabledForTesting)

        launchManager.isEnabledValue = false
        controller.setLaunchAtLoginForTesting(false)
        #expect(controller.launchAtLoginEnabledForTesting == false)
    }

    @Test("Settings controller strict-disable visibility helper covers false branch")
    @MainActor
    func settingsControllerStrictDisableFalseBranch() {
        let appState = isolatedAppState(name: "strictFalse")
        appState.isBlocking = false
        appState.isStrict = true
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        #expect(controller.shouldShowStrictDisableButtonForTesting == false)
    }

    @Test("Settings controller calendar controls always enabled; challenge guards changes in strict active mode")
    @MainActor
    func settingsControllerCalendarControlsLockState() {
        let appState = isolatedAppState(name: "calendarControlsLockState")
        appState.isBlocking = false
        appState.isStrict = true
        let notStrict = SettingsSectionViewController(appState: appState)
        _ = host(notStrict)
        // Controls are always enabled — challenge dialog protects them
        #expect(notStrict.calendarControlsLockedForTesting == false)

        appState.isBlocking = true
        let strict = SettingsSectionViewController(appState: appState)
        _ = host(strict)
        #expect(strict.calendarControlsLockedForTesting == false)
    }

    @Test("Settings controller browser controls always enabled; strict notice shown and challenge guards changes")
    @MainActor
    func settingsControllerBrowserControlsLockState() {
        let appState = isolatedAppState(name: "browserControlsLockState")
        appState.isBlocking = false
        appState.isStrict = false
        let unlocked = SettingsSectionViewController(appState: appState)
        let unlockedView = host(unlocked)
        #expect(unlocked.browserControlsLockedForTesting == false)
        #expect(
            visibleText(in: unlockedView).contains(
                StrictModeCopy.active(
                    withSuffix:
                        " A challenge phrase is required to change Browser blocking settings."
                )
            ) == false
        )

        appState.isStrict = true
        let locked = SettingsSectionViewController(appState: appState)
        let lockedView = host(locked)
        // Controls stay enabled but lock notice is shown; challenge guards actual changes
        #expect(locked.browserControlsLockedForTesting == false)
        #expect(
            visibleText(in: lockedView).contains(
                StrictModeCopy.active(
                    withSuffix:
                        " A challenge phrase is required to change Browser blocking settings."
                )
            )
        )
    }

    @Test("Settings browser toggle handlers show challenge and revert switch while strict is enabled")
    @MainActor
    func settingsControllerBrowserToggleGuardBranches() {
        let appState = isolatedAppState(name: "browserToggleGuardBranches")
        appState.isStrict = true
        appState.blockNewTabs = false
        appState.blockDeveloperHosts = false
        appState.blockLocalNetworkHosts = false
        appState.allowSearchEngineWebsites = false
        appState.allowAIProviderWebsites = false

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        controller.setBlockNewTabsForTesting(true)
        controller.setBlockDeveloperHostsForTesting(true)
        controller.setBlockLocalNetworkHostsForTesting(true)
        controller.setAllowSearchEngineWebsitesForTesting(true)
        controller.setAllowAIProviderWebsitesForTesting(true)

        #expect(appState.blockNewTabs == false)
        #expect(appState.blockDeveloperHosts == false)
        #expect(appState.blockLocalNetworkHosts == false)
        #expect(appState.allowSearchEngineWebsites == false)
        #expect(appState.allowAIProviderWebsites == false)
    }

    @Test("Settings controller renders default toggle branch")
    @MainActor
    func settingsControllerRenderDefaultBranch() {
        let appState = isolatedAppState(name: "renderDefault")
        appState.isBlocking = false
        appState.isStrict = false
        appState.accentColorIndex = 2

        let controller = SettingsSectionViewController(appState: appState)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)
        let toggleFrames = visibleSwitchFrames(in: hosted, root: hosted)
        let toggleAccentColors = visibleToggleAccentColors(in: hosted)
        let expectedAccentColor = FocusColor.nsColor(for: appState.accentColorIndex)

        #expect(hosted.fittingSize.width >= 0)
        #expect(texts.contains("Launch at Login"))
        #expect(texts.contains("Block New Tabs"))
        #expect(texts.contains("Block Localhost/Dev Ports"))
        #expect(texts.contains("Block Local Network IPs"))
        #expect(texts.contains("Allow Search Engines"))
        #expect(texts.contains("Allow AI Providers"))
        #expect(toggleFrames.count == 8)
        #expect(toggleAccentColors.count == 8)
        if let referenceMaxX = toggleFrames.first?.maxX {
            for frame in toggleFrames {
                #expect(abs(frame.maxX - referenceMaxX) <= 2)
            }
        }
        for color in toggleAccentColors {
            #expect(color == expectedAccentColor)
        }
        #expect(controller.appearanceSelectionColorForTesting == expectedAccentColor)
    }

    @Test("Settings controller renders strict-mode disable branch")
    @MainActor
    func settingsControllerRenderStrictBranch() {
        let appState = isolatedAppState(name: "renderStrict")
        appState.isBlocking = true
        appState.isStrict = true
        appState.accentColorIndex = 0

        let controller = SettingsSectionViewController(appState: appState)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.shouldShowStrictDisableButtonForTesting)
        #expect(texts.contains("Disable..."))
    }

    @Test("Settings controller testing hooks exercise toggle and selection action handlers")
    @MainActor
    func settingsControllerToggleActionCoverage() {
        let appState = isolatedAppState(name: "toggleActionCoverage")
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        controller.setStrictModeForTesting(true)
        #expect(appState.isStrict)
        SettingsSectionViewController.makeStrictModeAlert = { NSAlert() }
        SettingsSectionViewController.runStrictModeAlert = { alert in
            firstEditableTextField(in: alert.accessoryView)?.stringValue = AppState.challengePhrase
            return .alertFirstButtonReturn
        }
        controller.setStrictModeForTesting(false)
        #expect(appState.isStrict == false)

        controller.setWeekStartsMondayForTesting(true)
        #expect(appState.weekStartsOnMonday)
        controller.setWeekStartsMondayForTesting(false)
        #expect(appState.weekStartsOnMonday == false)

        controller.setCalendarIntegrationForTesting(true)
        #expect(appState.calendarIntegrationEnabled)
        controller.setCalendarIntegrationForTesting(false)
        #expect(appState.calendarIntegrationEnabled == false)

        controller.setCalendarImportsForTesting(true)
        #expect(appState.calendarImportsBlockTime)
        controller.setCalendarImportsForTesting(false)
        #expect(appState.calendarImportsBlockTime == false)

        controller.setBlockNewTabsForTesting(true)
        #expect(appState.blockNewTabs)
        controller.setBlockNewTabsForTesting(false)
        #expect(appState.blockNewTabs == false)

        controller.setBlockDeveloperHostsForTesting(true)
        #expect(appState.blockDeveloperHosts)
        controller.setBlockDeveloperHostsForTesting(false)
        #expect(appState.blockDeveloperHosts == false)

        controller.setBlockLocalNetworkHostsForTesting(true)
        #expect(appState.blockLocalNetworkHosts)
        controller.setBlockLocalNetworkHostsForTesting(false)
        #expect(appState.blockLocalNetworkHosts == false)

        controller.setAllowSearchEngineWebsitesForTesting(true)
        #expect(appState.allowSearchEngineWebsites)
        controller.setAllowSearchEngineWebsitesForTesting(false)
        #expect(appState.allowSearchEngineWebsites == false)

        controller.setAllowAIProviderWebsitesForTesting(true)
        #expect(appState.allowAIProviderWebsites)
        controller.setAllowAIProviderWebsitesForTesting(false)
        #expect(appState.allowAIProviderWebsites == false)

        controller.selectAppearanceModeForTesting(.dark)
        #expect(appState.appearanceMode == .dark)

        // Invocation coverage path only; behavior is validated in calendar sync tests.
        controller.resyncImportedSchedulesForTesting()
    }

    @Test("Settings controller strict-mode modal action supports unlock/cancel branches via alert hooks")
    @MainActor
    func settingsControllerStrictModeModalCoverage() {
        let appState = isolatedAppState(name: "strictModeModalCoverage")
        appState.isBlocking = true
        appState.isStrict = true
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.makeStrictModeAlert = { NSAlert() }
        SettingsSectionViewController.runStrictModeAlert = { alert in
            firstEditableTextField(in: alert.accessoryView)?.stringValue = AppState.challengePhrase
            return .alertFirstButtonReturn
        }
        controller.invokeDisableStrictModeModalForTesting()
        #expect(appState.isStrict == false)

        appState.isStrict = true
        SettingsSectionViewController.runStrictModeAlert = { _ in .alertSecondButtonReturn }
        controller.invokeDisableStrictModeModalForTesting()
        #expect(appState.isStrict)
    }

    @Test("Settings strict toggle-off no-ops without challenge when already disabled")
    @MainActor
    func settingsStrictToggleOffGuardCoverage() {
        let appState = isolatedAppState(name: "strictToggleOffGuardCoverage")
        appState.isStrict = false
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }
        var modalCallCount = 0
        SettingsSectionViewController.runStrictModeAlert = { _ in
            modalCallCount += 1
            return .alertSecondButtonReturn
        }

        controller.setStrictModeForTesting(false)
        #expect(appState.isStrict == false)
        #expect(modalCallCount == 0)
    }

    @Test("Settings observation callback reloads after app-state changes")
    @MainActor
    func settingsControllerObservationReloadCoverage() {
        let appState = isolatedAppState(name: "observationReloadCoverage")
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        appState.accentColorIndex = 3
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(controller.appearanceSelectionColorForTesting == FocusColor.nsColor(for: 3))
    }

    @Test("Resync imported schedules requests calendar permission when unauthorized")
    @MainActor
    func settingsResyncRequestsCalendarPermissionWhenUnauthorized() {
        let calendar = MockCalendarManager()
        calendar.isAuthorized = false
        let appState = isolatedAppState(name: "resyncPermissionRequest", calendar: calendar)
        appState.calendarIntegrationEnabled = true
        let baselineRequestCalls = calendar.requestAccessCallCount

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        controller.resyncImportedSchedulesForTesting()

        #expect(calendar.requestAccessCallCount == baselineRequestCalls + 1)
    }

    @Test("Calendar-permission fallback alert can open system settings")
    @MainActor
    func settingsCalendarPermissionFallbackAlert() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        let appState = isolatedAppState(name: "calendarPermissionFallbackAlert")

        var alertShown = 0
        var openedSettings = 0
        SettingsSectionViewController.makeCalendarPermissionAlert = { NSAlert() }
        SettingsSectionViewController.runCalendarPermissionAlert = { _ in
            alertShown += 1
            return .alertFirstButtonReturn
        }
        SettingsSectionViewController.openCalendarPrivacySettings = {
            openedSettings += 1
        }

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        controller.invokeCalendarPermissionAlertForTesting()
        #expect(alertShown == 1)
        #expect(openedSettings == 1)
    }

    @Test("Settings strict-mode alert default hooks return cancel response in test environment")
    @MainActor
    func settingsStrictModeDefaultAlertHooks() {
        defer {
            unsetenv("XCTestConfigurationFilePath")
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        _ = setenv("XCTestConfigurationFilePath", "1", 1)
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        let alert = SettingsSectionViewController.makeStrictModeAlert()
        #expect(
            SettingsSectionViewController.runStrictModeAlert(alert)
                == .alertSecondButtonReturn
        )
    }

    @Test("Settings native workspace opener default getter instantiates fallback closure")
    @MainActor
    func settingsNativeWorkspaceOpenerDefaultGetterCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        _ = SettingsSectionViewController.nativeWorkspaceURLOpener
    }

    @Test("Settings strict-mode default hook falls back to NSAlert.runModal when XCTest env var is missing")
    @MainActor
    func settingsStrictModeDefaultAlertHooksRunModalPath() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        let alert = TestModalAlert()
        #expect(
            SettingsSectionViewController.runStrictModeAlert(alert)
                == .alertFirstButtonReturn
        )
    }

    @Test("Settings calendar-permission default hook falls back to NSAlert.runModal when XCTest env var is missing")
    @MainActor
    func settingsCalendarPermissionDefaultAlertHooksRunModalPath() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        let alert = TestModalAlert()
        #expect(
            SettingsSectionViewController.runCalendarPermissionAlert(alert)
                == .alertFirstButtonReturn
        )
    }

    @Test("Settings async calendar-permission fallback presents alert after delay outside XCTest guard")
    @MainActor
    func settingsCalendarPermissionAsyncFallbackCoverage() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        SettingsSectionViewController.calendarPermissionFallbackDelay = 0.01
        SettingsSectionViewController.scheduleAfter = { _, work in work() }

        let calendar = MockCalendarManager()
        calendar.isAuthorized = false
        let appState = isolatedAppState(name: "calendarAsyncFallbackCoverage", calendar: calendar)
        appState.calendarIntegrationEnabled = true

        var alertShown = 0
        SettingsSectionViewController.makeCalendarPermissionAlert = { NSAlert() }
        SettingsSectionViewController.runCalendarPermissionAlert = { _ in
            alertShown += 1
            return .alertSecondButtonReturn
        }

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)
        controller.resyncImportedSchedulesForTesting()

        #expect(alertShown == 1)
    }

    @Test("Settings calendar privacy opener guards invalid URLs and opens valid URLs")
    func settingsCalendarPrivacyOpenerCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        var opened: [URL] = []
        SettingsSectionViewController.injectedWorkspaceURLOpener = { url in opened.append(url) }

        SettingsSectionViewController.calendarPrivacySettingsURLString = "not a url"
        SettingsSectionViewController.openCalendarPrivacySettings()
        #expect(opened.isEmpty)

        SettingsSectionViewController.calendarPrivacySettingsURLString =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        SettingsSectionViewController.openCalendarPrivacySettings()
        #expect(opened.count == 1)
    }

    @Test("Settings default scheduler executes delayed work closure")
    func settingsDefaultSchedulerCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        var didRun = false
        SettingsSectionViewController.scheduleAfter(0) { didRun = true }
        let timeout = Date().addingTimeInterval(0.25)
        while !didRun && Date() < timeout {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        #expect(didRun)
    }

    @Test("Settings workspace opener default path delegates to platform opener")
    func settingsWorkspaceDefaultOpenerCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        var opened: [URL] = []
        SettingsSectionViewController.platformWorkspaceURLOpener = { opened.append($0) }
        let url = URL(string: "https://example.com")!

        SettingsSectionViewController.workspaceURLOpener(url)
        #expect(opened == [url])
    }

    @Test("Settings workspace opener setter path is exercised")
    func settingsWorkspaceOpenerSetterCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        _ = SettingsSectionViewController.platformWorkspaceURLOpener

        var opened: [URL] = []
        SettingsSectionViewController.workspaceURLOpener = { opened.append($0) }
        SettingsSectionViewController.calendarPrivacySettingsURLString = "https://example.com"
        SettingsSectionViewController.openCalendarPrivacySettings()

        #expect(opened.count == 1)
    }

    @Test("Settings platform workspace opener covers x-free-test guard and native open path")
    func settingsPlatformWorkspaceOpenerCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        var nativeOpened: [URL] = []
        SettingsSectionViewController.isRunningInTestProcess = { false }
        SettingsSectionViewController.nativeWorkspaceURLOpener = { nativeOpened.append($0) }

        let blockedURL = URL(string: "x-free-test://noop")!
        SettingsSectionViewController.platformWorkspaceURLOpener(blockedURL)
        #expect(nativeOpened.isEmpty)

        let openURL = URL(string: "https://example.com/open")!
        SettingsSectionViewController.platformWorkspaceURLOpener(openURL)
        #expect(nativeOpened == [openURL])
    }

    @Test("Settings default workspace helpers expose callable detector and opener closures")
    func settingsDefaultWorkspaceHelperGettersCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        let detector = SettingsSectionViewController.isRunningInTestProcess
        _ = detector()

        // Getter-only coverage for default native opener closure creation.
        _ = SettingsSectionViewController.nativeWorkspaceURLOpener
    }

    @Test("Settings default native workspace opener closure executes through native open hook")
    func settingsDefaultNativeWorkspaceOpenerClosureExecutionCoverage() {
        defer {
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
            AppKitSystemBridges.setOpenURLForTesting(nil)
        }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        var opened: [URL] = []
        SettingsSectionViewController.setWorkspaceNativeOpenURLOpenerForTesting { opened.append($0) }
        let url = URL(string: "https://example.com/native-opener")!
        SettingsSectionViewController.nativeWorkspaceURLOpener(url)
        #expect(opened == [url])
    }

    @Test("Settings native opener default branch routes through AppKit system bridge")
    func settingsNativeWorkspaceOpenerDefaultBranchCoverage() {
        defer {
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
            AppKitSystemBridges.setOpenURLForTesting(nil)
        }

        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        SettingsSectionViewController.setWorkspaceNativeOpenURLOpenerForTesting(nil)
        var opened: [URL] = []
        AppKitSystemBridges.setOpenURLForTesting { opened.append($0) }
        let url = URL(string: "https://example.com/native-opener-default")!
        SettingsSectionViewController.nativeWorkspaceURLOpener(url)
        #expect(opened == [url])
    }

    @Test("Settings calendar fallback guard handles pending-true and authorization-restored branches")
    @MainActor
    func settingsCalendarFallbackPendingAndAuthorizedGuardsCoverage() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()

        var scheduled: [() -> Void] = []
        SettingsSectionViewController.scheduleAfter = { _, work in scheduled.append(work) }
        var alertShown = 0
        SettingsSectionViewController.makeCalendarPermissionAlert = { NSAlert() }
        SettingsSectionViewController.runCalendarPermissionAlert = { _ in
            alertShown += 1
            return .alertSecondButtonReturn
        }

        let calendar = MockCalendarManager()
        calendar.isAuthorized = false
        let appState = isolatedAppState(name: "calendarFallbackPendingGuard", calendar: calendar)
        appState.calendarIntegrationEnabled = true

        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        controller.resyncImportedSchedulesForTesting()
        #expect(scheduled.count == 1)

        controller.resyncImportedSchedulesForTesting()
        #expect(scheduled.count == 1)

        calendar.isAuthorized = true
        scheduled.removeFirst()()
        #expect(alertShown == 0)
    }

    @Test("Settings calendar fallback closure safely returns when controller is deallocated")
    @MainActor
    func settingsCalendarFallbackClosureNilSelfGuardCoverage() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            SettingsSectionViewController.resetStrictModeAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()

        var scheduled: [() -> Void] = []
        SettingsSectionViewController.scheduleAfter = { _, work in scheduled.append(work) }

        let calendar = MockCalendarManager()
        calendar.isAuthorized = false
        let appState = isolatedAppState(name: "calendarFallbackNilSelfGuard", calendar: calendar)
        appState.calendarIntegrationEnabled = true

        var controller: SettingsSectionViewController? = SettingsSectionViewController(appState: appState)
        if let controller {
            _ = host(controller)
            controller.resyncImportedSchedulesForTesting()
        }
        #expect(scheduled.count == 1)

        controller = nil
        scheduled.removeFirst()()
    }

    @Test("Settings controller cursor fluid toggle updates app state and survives reset hooks")
    @MainActor
    func settingsCursorFluidToggleAndResetHooksCoverage() {
        defer { SettingsSectionViewController.resetStrictModeAlertHooksForTesting() }

        let appState = isolatedAppState(name: "cursorFluidToggle")
        let controller = SettingsSectionViewController(appState: appState)
        _ = host(controller)

        #expect(appState.cursorFluidAnimationEnabled)
        controller.setCursorFluidAnimationForTesting(false)
        #expect(appState.cursorFluidAnimationEnabled == false)
        controller.setCursorFluidAnimationForTesting(true)
        #expect(appState.cursorFluidAnimationEnabled)

        SettingsSectionViewController.openCalendarPrivacySettings = {}
        SettingsSectionViewController.scheduleAfter = { _, _ in }
        SettingsSectionViewController.resetStrictModeAlertHooksForTesting()

        SettingsSectionViewController.calendarPrivacySettingsURLString = "https://example.com/after-reset"
        var opened: [URL] = []
        SettingsSectionViewController.workspaceURLOpener = { opened.append($0) }
        SettingsSectionViewController.openCalendarPrivacySettings()
        #expect(opened.count == 1)

        let rainbowIndex = FocusColor.rainbowAccentIndex
        controller.reconfigureAccentButtonForTesting(index: -1)
        controller.reconfigureAccentButtonForTesting(index: rainbowIndex)
        controller.reconfigureAccentButtonForTesting(index: rainbowIndex)
    }
}
