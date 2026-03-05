import AppKit
import Foundation
import Testing

@testable import FreeLogic

struct UIComponentTests {
    private func rgbaComponents(_ cgColor: CGColor?) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        guard let cgColor,
              let color = NSColor(cgColor: cgColor)?.usingColorSpace(.deviceRGB)
        else {
            return nil
        }

        return (
            color.redComponent,
            color.greenComponent,
            color.blueComponent,
            color.alphaComponent
        )
    }

    private func findButton(
        with identifier: NSUserInterfaceItemIdentifier,
        in view: NSView
    ) -> NSButton? {
        if let button = view as? NSButton, button.identifier == identifier {
            return button
        }
        for subview in view.subviews {
            if let button = findButton(with: identifier, in: subview) {
                return button
            }
        }
        return nil
    }


    @Test("AddScheduleView configuration logic")
    func addScheduleViewLogic() {
        let calendar = Calendar.current
        let now = Date()

        let config1 = ScheduleEditorSupport.configuration(
            initialDay: 3, initialStartTime: nil, initialEndTime: nil, existingSchedule: nil)
        #expect(config1.days == [3])
        #expect(config1.name == "")

        let start = calendar.date(from: DateComponents(hour: 14, minute: 0))!
        let config2 = ScheduleEditorSupport.configuration(
            initialDay: nil, initialStartTime: start, initialEndTime: nil, existingSchedule: nil)
        #expect(config2.startTime == start)
        let endHour = calendar.component(.hour, from: config2.endTime)
        #expect(endHour == 15)

        let existing = Schedule(
            name: "Existing", days: [1], startTime: now, endTime: now, colorIndex: 5, type: .unfocus
        )
        let config3 = ScheduleEditorSupport.configuration(
            initialDay: nil, initialStartTime: nil, initialEndTime: nil, existingSchedule: existing)
        #expect(config3.name == "Existing")
        #expect(config3.colorIndex == 5)
        #expect(config3.type == .unfocus)
    }

    @Test("ScheduleEditorContext integrity")
    func scheduleEditorContextLogic() {
        let context1 = ScheduleEditorContext()
        #expect(context1.schedule == nil)
        #expect(context1.day == nil)

        let schedule = Schedule(name: "Test", days: [2], startTime: Date(), endTime: Date())
        let context2 = ScheduleEditorContext(schedule: schedule)
        #expect(context2.schedule?.id == schedule.id)

        let context3 = ScheduleEditorContext(day: 5, startTime: Date(), endTime: Date())
        #expect(context3.day == 5)
        #expect(context3.schedule == nil)
    }

    @Test("Negative: AddScheduleView configuration with end before start")
    func addScheduleViewNegative() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 9, minute: 0))!

        let config = ScheduleEditorSupport.configuration(
            initialDay: nil, initialStartTime: start, initialEndTime: end, existingSchedule: nil)

        #expect(config.endTime == end)
    }

    @Test("AppKit symbol control button maps shorthand symbols")
    func appKitSymbolControlButtonShorthand() {
        #expect(resolvedAppKitControlSymbolName("+") == "plus.circle.fill")
        #expect(resolvedAppKitControlSymbolName("-") == "minus.circle.fill")
        #expect(resolvedAppKitControlSymbolName("xmark") == "xmark")

        let plusButton = makeAppKitSymbolControlButton(
            symbol: "+",
            isEnabled: true,
            pointSize: 24,
            dimension: 24,
            color: .secondaryLabelColor,
            action: {}
        )
        let minusButton = makeAppKitSymbolControlButton(
            symbol: "-",
            isEnabled: false,
            pointSize: 24,
            dimension: 24,
            color: .secondaryLabelColor,
            action: {}
        )

        #expect((plusButton as? AppKitSymbolControlButton)?.symbolNameForTesting == "plus.circle.fill")
        #expect(plusButton.isEnabled)
        #expect((minusButton as? AppKitSymbolControlButton)?.symbolNameForTesting == "minus.circle.fill")
        #expect(minusButton.isEnabled == false)
    }

    @Test("Shared AppKit icon button helper applies image inset when supported")
    func sharedAppKitIconButtonInset() {
        let button = IconInsetButton()
        configureAppKitIconButton(
            button,
            symbolName: "chevron.left",
            pointSize: 8,
            weight: .medium,
            color: .labelColor,
            backgroundColor: .clear,
            cornerRadius: 12,
            imageInset: 2
        )

        #expect(button.image != nil)
        #expect(button.imageInset == 2)
    }

    @Test("Shared AppKit pill and selectable-row helpers configure common controls")
    func sharedAppKitControlHelpers() {
        let pillButton = makeAppKitPillButton(
            title: "25/5",
            isSelected: true,
            selectedColor: .systemOrange,
            width: 50,
            action: {}
        )
        let rowButton = makeAppKitSelectableRowButton(
            title: "Default",
            isSelected: true,
            accentColor: .systemBlue,
            action: {}
        )

        #expect(pillButton.attributedTitle.string == "25/5")
        #expect(pillButton.image == nil)
        #expect(rowButton.displayedTitleForTesting == "Default")
        #expect(rowButton.isSelectedState)
        #expect(rowButton.subviews.contains { $0 is NSStackView })
    }

    @Test("Shared AppKit selection button group applies accent to selected value")
    func sharedAppKitSelectionButtonGroup() {
        let control = AppKitSelectionButtonGroup(
            options: [
                AppKitSelectionButtonOption(title: "Focus", value: "focus"),
                AppKitSelectionButtonOption(title: "Break", value: "break"),
            ],
            selectedValue: "focus",
            accentColor: .systemOrange
        )

        #expect(control.selectedButtonTintColor == .systemOrange)

        control.selectedValue = "break"
        #expect(control.selectedButtonTintColor == .systemOrange)

        control.accentColor = .systemPurple
        #expect(control.selectedButtonTintColor == .systemPurple)
        #expect(control.intrinsicContentSize.width > 80)
        #expect(control.intrinsicContentSize.width < 220)
        #expect(control.intrinsicContentSize.height == 26)
    }

    @Test("Dynamic AppKit color providers resolve inside the requested appearance")
    func dynamicAppKitProviderResolution() {
        let lightAppearance = NSAppearance(named: .aqua)
        let darkAppearance = NSAppearance(named: .darkAqua)

        let lightComponents = rgbaComponents(
            resolvedAppKitCGColor(
                { NSColor.controlBackgroundColor.withAlphaComponent(0.8) },
                appearance: lightAppearance
            )
        )
        let darkComponents = rgbaComponents(
            resolvedAppKitCGColor(
                { NSColor.controlBackgroundColor.withAlphaComponent(0.8) },
                appearance: darkAppearance
            )
        )

        #expect(lightComponents != nil)
        #expect(darkComponents != nil)
        #expect(lightComponents?.0 != darkComponents?.0)
        #expect(lightComponents?.3 == darkComponents?.3)
    }

    @Test("Main sidebar selection callback routes to expected section controller")
    @MainActor
    func mainSidebarSelectionRoutesToExpectedController() {
        let suite = "UIComponentTests.mainSidebarSelectionRoutesToExpectedController"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let appState = AppState(defaults: defaults, isTesting: true)
        let shellState = FreeShellState()

        let focusController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .all
        )
        let schedulesController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .schedules
        )
        let pomodoroController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .pomodoro
        )
        let allowedWebsitesController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .allowedWebsites
        )
        let settingsController = SettingsSectionViewController(appState: appState)
        let router = MainSectionRouter(
            focusOverviewController: focusController,
            schedulesOverviewController: schedulesController,
            pomodoroSectionController: pomodoroController,
            allowedWebsitesSectionController: allowedWebsitesController,
            settingsSectionController: settingsController
        )

        let sidebar = MainSidebarView(
            selectedSection: .focus,
            isSidebarVisible: true,
            accentColorIndex: appState.accentColorIndex
        )
        sidebar.frame = NSRect(x: 0, y: 0, width: 220, height: 640)
        sidebar.layoutSubtreeIfNeeded()
        sidebar.displayIfNeeded()

        var didToggle = false
        sidebar.onToggleSidebar = { didToggle = true }

        var selectedSection: MainContentSection?
        var routedController: NSViewController?
        sidebar.onSelectSection = { section in
            selectedSection = section
            routedController = router.controller(for: section)
        }

        let pomodoroButton = findButton(
            with: NSUserInterfaceItemIdentifier(MainContentSection.pomodoro.rawValue),
            in: sidebar
        )
        #expect(pomodoroButton != nil)
        pomodoroButton?.performClick(nil)

        #expect(selectedSection == .pomodoro)
        #expect(routedController === pomodoroController)

        let toggleButton = findButton(with: NSUserInterfaceItemIdentifier("sidebar.toggle"), in: sidebar)
        #expect(toggleButton != nil)
        toggleButton?.performClick(nil)
        #expect(didToggle)
    }
}
