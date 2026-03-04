import AppKit
import Foundation
import Testing

@testable import FreeLogic

struct UIComponentTests {

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
    }
}
