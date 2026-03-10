import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
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

    private func firstStackView(in view: NSView) -> NSStackView? {
        if let stack = view as? NSStackView {
            return stack
        }
        for subview in view.subviews {
            if let stack = firstStackView(in: subview) {
                return stack
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

    @Test("AppKit symbol helper returns nil for unknown symbols")
    func appKitSymbolHelperUnknownSymbol() {
        let unknown = appKitSymbolImage(
            named: "definitely.not.a.real.symbol",
            pointSize: 14,
            weight: .regular,
            color: nil
        )
        #expect(unknown == nil)
    }

    @Test("AppKit symbol helper supports nil tint color")
    func appKitSymbolHelperNilTintColor() {
        let image = appKitSymbolImage(
            named: "chevron.left",
            pointSize: 12,
            weight: .regular,
            color: nil
        )
        #expect(image != nil)
    }

    @Test("AppKit symbol helper supports default color argument")
    func appKitSymbolHelperDefaultColorArgument() {
        let image = appKitSymbolImage(
            named: "chevron.left",
            pointSize: 12,
            weight: .regular
        )
        #expect(image != nil)
    }

    @Test("AppKit symbol helper supports symbol spec overload")
    func appKitSymbolHelperSpecOverload() {
        let image = appKitSymbolImage(
            spec: AppKitUISymbols.navChevron,
            color: .labelColor
        )
        #expect(image != nil)
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

    @MainActor
    @Test("AppKit button primitives cover action, gradient, and inset-cell geometry")
    func appKitButtonPrimitivesCoverage() {
        let plainButton = ActionButton(title: "Plain")
        plainButton.wantsLayer = false
        plainButton.frame = NSRect(x: 0, y: 0, width: 100, height: 24)
        plainButton.layoutSubtreeIfNeeded()
        plainButton.viewDidChangeEffectiveAppearance()

        let actionButton = ActionButton(title: "Run")
        var didTap = false
        actionButton.onAction = { didTap = true }
        actionButton.setGradientBackground(
            colors: [.systemBlue.withAlphaComponent(0.3), .systemBlue.withAlphaComponent(0.15)],
            borderColor: .systemBlue,
            borderWidth: 2
        )
        actionButton.frame = NSRect(x: 0, y: 0, width: 120, height: 32)
        actionButton.layoutSubtreeIfNeeded()
        actionButton.viewDidChangeEffectiveAppearance()
        actionButton.performClick(nil)
        #expect(didTap)
        #expect(actionButton.layer?.borderWidth == 2)

        let leadingCell = LeadingInsetButtonCell(textCell: "Row")
        leadingCell.leadingInset = 10
        leadingCell.imageSlotWidth = 20
        leadingCell.titleAdditionalInset = 6
        _ = leadingCell.imageRect(forBounds: NSRect(x: 0, y: 0, width: 180, height: 28))
        let titleRect = leadingCell.titleRect(forBounds: NSRect(x: 0, y: 0, width: 180, height: 28))
        #expect(titleRect.origin.x == 36)
        #expect(titleRect.width == 144)

        let iconCell = IconInsetButtonCell(textCell: "")
        iconCell.imageInset = 3
        _ = iconCell.imageRect(forBounds: NSRect(x: 0, y: 0, width: 24, height: 24))

        let iconButton = IconInsetButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        iconButton.imageInset = 4
        #expect(iconButton.imageInset == 4)
        IconInsetButton.cellClass = IconInsetButtonCell.self
        iconButton.cell = NSButtonCell(textCell: "")
        #expect(iconButton.imageInset == 0)

        let leadingButton = LeadingInsetActionButton(title: "Lead")
        leadingButton.leadingInset = 12
        leadingButton.titleAdditionalInset = 7
        leadingButton.imageSlotWidth = 18
        #expect(leadingButton.leadingInset == 12)
        #expect(leadingButton.titleAdditionalInset == 7)
        #expect(leadingButton.imageSlotWidth == 18)
        LeadingInsetActionButton.cellClass = LeadingInsetButtonCell.self
        leadingButton.cell = NSButtonCell(textCell: "")
        #expect(leadingButton.leadingInset == 0)
        #expect(leadingButton.titleAdditionalInset == 0)
        #expect(leadingButton.imageSlotWidth == 0)
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

    @MainActor
    @Test("AppKit button style helpers cover didSet, appearance refresh, and utility builders")
    func appKitButtonStylesCoverage() {
        let selectable = AppKitSelectableRowButton(
            title: "Row",
            isSelected: false,
            accentColor: .systemBlue,
            trailingSelectedSymbol: nil
        )
        selectable.applySelectionState(true)
        selectable.accentColor = .systemPink
        selectable.viewDidChangeEffectiveAppearance()
        #expect(selectable.displayedTitleForTesting == "Row")

        let pill = AppKitPillButton(
            title: "Pill",
            isSelected: false,
            selectedColor: .systemOrange
        )
        pill.applySelectionState(true)
        pill.selectedColor = .systemGreen
        pill.viewDidChangeEffectiveAppearance()
        #expect(pill.attributedTitle.string == "Pill")

        let symbol = AppKitSymbolControlButton(
            symbolName: "chevron.left",
            pointSize: 12,
            weight: .regular,
            color: .secondaryLabelColor
        )
        symbol.symbolColor = .systemPurple
        symbol.viewDidChangeEffectiveAppearance()
        #expect(symbol.symbolNameForTesting == "chevron.left")

        let dangerButton = NSButton()
        configureAppKitDangerSymbolButton(dangerButton, symbol: AppKitUISymbols.closeEditor)
        #expect(dangerButton.contentTintColor == .systemRed)
        #expect(dangerButton.image != nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        configureAppKitWindowButton(in: window, type: .closeButton, targetSize: nil)
        configureAppKitWindowButton(
            in: window,
            type: .closeButton,
            controlSize: .small,
            targetSize: 18,
            xOffset: 1,
            yOffset: -1
        )
        let borderless = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        configureAppKitWindowButton(in: borderless, type: .closeButton, targetSize: 16)

        let primary = makeAppKitPrimaryButton(title: "Primary", color: .systemBlue)
        #expect(primary.attributedTitle.string == "Primary")
        #expect(primary.contentTintColor == .systemBlue)

        let secondary = makeAppKitSecondaryButton(title: "Secondary", color: .systemTeal)
        #expect(secondary.attributedTitle.string == "Secondary")
        applyAppKitSecondaryButtonStyle(secondary, title: "Updated", color: .systemIndigo)
        #expect(secondary.attributedTitle.string == "Updated")

        applyAppKitNeutralButtonStyle(secondary, title: "Neutral")
        #expect(secondary.attributedTitle.string == "Neutral")
        #expect(secondary.contentTintColor == .labelColor)

        let divider = makeAppKitDividerView()
        #expect(divider is AppKitDynamicView)
        #expect(divider.constraints.contains { $0.constant == 1 })
    }

    @Test("Schedule editor support views cover arranged-subview removal and safe collection lookup")
    func scheduleEditorSupportViewsCoverage() {
        let section = EditorSectionView(title: "Section")
        #expect(section.contentStack.arrangedSubviews.count == 1)

        let first = NSTextField(labelWithString: "First")
        let second = NSTextField(labelWithString: "Second")
        section.contentStack.addArrangedSubview(first)
        section.contentStack.addArrangedSubview(second)
        #expect(section.contentStack.arrangedSubviews.count == 3)

        removeArrangedSubviews(from: section.contentStack)
        #expect(section.contentStack.arrangedSubviews.isEmpty)
        #expect(first.superview == nil)
        #expect(second.superview == nil)

        let untitled = EditorSectionView(title: "")
        #expect(untitled.contentStack.arrangedSubviews.isEmpty)

        let values = [10, 20]
        #expect(values[safe: 0] == 10)
        #expect(values[safe: 99] == nil)
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

    @Test("Selection button group handles empty options with stable intrinsic size")
    func sharedAppKitSelectionButtonGroupEmptyOptions() {
        let control = AppKitSelectionButtonGroup(
            options: [AppKitSelectionButtonOption<String>](),
            selectedValue: "",
            accentColor: .systemBlue
        )

        #expect(control.intrinsicContentSize.width == 2)
        #expect(control.intrinsicContentSize.height == 26)
    }

    @MainActor
    @Test("Selection button group routes click selection callback and appearance refresh")
    func sharedAppKitSelectionButtonGroupActions() {
        let control = AppKitSelectionButtonGroup(
            options: [
                AppKitSelectionButtonOption(title: "One", value: 1),
                AppKitSelectionButtonOption(title: "Two", value: 2),
            ],
            selectedValue: 1,
            accentColor: .systemBlue
        )

        var selectedValues: [Int] = []
        control.onSelection = { selectedValues.append($0) }

        let stack = firstStackView(in: control)
        #expect(stack != nil)
        let buttons = stack?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        #expect(buttons.count == 2)

        buttons.last?.performClick(nil)
        #expect(control.selectedValue == 2)
        #expect(selectedValues == [2])

        control.viewDidChangeEffectiveAppearance()
        #expect(control.selectedButtonTintColor != nil)
    }

    @MainActor
    @Test("AppKit toggle switch covers layout, key, and mouse interactions")
    func appKitToggleSwitchInteractions() {
        let toggle = AppKitToggleSwitch(frame: NSRect(x: 0, y: 0, width: 52, height: 28))
        toggle.accentColor = .systemGreen
        #expect(toggle.intrinsicContentSize == NSSize(width: 46, height: 24))
        #expect(toggle.acceptsFirstResponder)

        var actionCount = 0
        final class ToggleTarget: NSObject {
            var onToggle: (() -> Void)?
            @objc func didToggle() { onToggle?() }
        }
        let target = ToggleTarget()
        target.onToggle = { actionCount += 1 }
        toggle.target = target
        toggle.action = #selector(ToggleTarget.didToggle)

        toggle.layoutSubtreeIfNeeded()
        toggle.viewDidChangeEffectiveAppearance()

        let keyEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        )
        #expect(keyEvent != nil)
        if let keyEvent {
            toggle.keyDown(with: keyEvent)
        }
        #expect(toggle.state == .on)
        #expect(actionCount == 1)

        let mouseInside = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
        #expect(mouseInside != nil)
        if let mouseInside {
            toggle.mouseUp(with: mouseInside)
        }
        #expect(toggle.state == .off)
        #expect(actionCount == 2)

        let mouseOutside = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 500, y: 500),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
        #expect(mouseOutside != nil)
        if let mouseOutside {
            toggle.mouseUp(with: mouseOutside)
        }
        #expect(actionCount == 2)

        let nonToggleKey = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )
        #expect(nonToggleKey != nil)
        if let nonToggleKey {
            toggle.keyDown(with: nonToggleKey)
        }
        #expect(toggle.state == .off)

        toggle.isEnabled = false
        #expect(toggle.acceptsFirstResponder == false)
        if let keyEvent {
            toggle.keyDown(with: keyEvent)
        }
        #expect(toggle.state == .off)

        if let mouseInside {
            toggle.mouseUp(with: mouseInside)
        }
        #expect(actionCount == 2)
    }

    @Test("AppKit card stack view refreshes appearance colors on appearance changes")
    func appKitCardStackViewAppearanceRefresh() {
        let cardStack = AppKitCardStackView(frame: NSRect(x: 0, y: 0, width: 100, height: 60))
        #expect(cardStack.layer?.backgroundColor != nil)
        cardStack.viewDidChangeEffectiveAppearance()
        #expect(cardStack.layer?.backgroundColor != nil)
    }

    @Test("Shared AppKit stack helpers build consistent row and column layouts")
    func sharedAppKitStackHelpers() {
        let leading = NSTextField(labelWithString: "A")
        let trailing = NSTextField(labelWithString: "B")
        let row = makeAppKitHorizontalRow(
            views: [leading, trailing],
            alignment: .centerY,
            spacing: 12,
            edgeInsets: NSEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        )
        #expect(row.orientation == .horizontal)
        #expect(row.alignment == .centerY)
        #expect(row.spacing == 12)
        #expect(row.edgeInsets.left == 2)
        #expect(row.arrangedSubviews.count == 2)

        let column = makeAppKitVerticalStack(
            views: [leading, trailing],
            alignment: .leading,
            spacing: 6
        )
        #expect(column.orientation == .vertical)
        #expect(column.alignment == .leading)
        #expect(column.spacing == 6)
        #expect(column.arrangedSubviews.count == 2)
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

    @Test("Dynamic AppKit color helpers resolve without appearance context")
    func dynamicAppKitProviderResolutionWithoutAppearance() {
        let fixedColor = resolvedAppKitCGColor(NSColor.systemRed, appearance: nil)
        #expect(NSColor(cgColor: fixedColor) != nil)

        let providedColor = resolvedAppKitCGColor({ NSColor.systemBlue }, appearance: nil)
        #expect(providedColor != nil)

        let missingColor = resolvedAppKitCGColor({ nil }, appearance: nil)
        #expect(missingColor == nil)
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
        let calendarController = CalendarSectionViewController(appState: appState)
        let settingsController = SettingsSectionViewController(appState: appState)
        let router = MainSectionRouter(
            focusOverviewController: focusController,
            schedulesOverviewController: schedulesController,
            calendarSectionController: calendarController,
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

        // Cover unresolved sidebar identifier guard path.
        sidebar.invokeSidebarButtonForTesting(identifierRawValue: "does.not.exist")
        #expect(selectedSection == .pomodoro)
    }

    @MainActor
    @Test("Main section metadata and router cover all enum cases")
    func mainSectionMetadataAndRouterCoverage() {
        let suite = "UIComponentTests.mainSectionMetadataAndRouterCoverage"
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
        let calendarController = CalendarSectionViewController(appState: appState)
        let settingsController = SettingsSectionViewController(appState: appState)
        let router = MainSectionRouter(
            focusOverviewController: focusController,
            schedulesOverviewController: schedulesController,
            calendarSectionController: calendarController,
            pomodoroSectionController: pomodoroController,
            allowedWebsitesSectionController: allowedWebsitesController,
            settingsSectionController: settingsController
        )

        #expect(MainContentSection.focus.icon == AppKitUISymbols.Name.focus)
        #expect(MainContentSection.schedules.icon == AppKitUISymbols.Name.schedules)
        #expect(MainContentSection.calendar.icon == AppKitUISymbols.Name.calendar)
        #expect(MainContentSection.pomodoro.icon == AppKitUISymbols.Name.pomodoro)
        #expect(MainContentSection.allowedWebsites.icon == AppKitUISymbols.Name.allowedWebsites)
        #expect(MainContentSection.settings.icon == AppKitUISymbols.Name.settings)
        #expect(MainContentSection.settings.id == MainContentSection.settings.rawValue)

        #expect(router.controller(for: .focus) === focusController)
        #expect(router.controller(for: .schedules) === schedulesController)
        #expect(router.controller(for: .calendar) === calendarController)
        #expect(router.controller(for: .pomodoro) === pomodoroController)
        #expect(router.controller(for: .allowedWebsites) === allowedWebsitesController)
        #expect(router.controller(for: .settings) === settingsController)
    }
}
