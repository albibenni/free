import Foundation
import SwiftUI
import Testing

@testable import FreeLogic

struct UIComponentTests {

    @Test("SheetWrapper initialization and binding")
    func sheetWrapperLogic() {
        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })

        let view = SheetWrapper(title: "Settings", isPresented: binding) {
            Text("Hello")
        }

        #expect(view.title == "Settings")

        view.isPresented = false
        #expect(presented == false)
    }

    @Test("URLListRow property integrity")
    func urlListRowProperties() {
        var deleted = false
        let view = URLListRow(url: "test.com") {
            deleted = true
        }

        #expect(view.url == "test.com")

        view.onDelete()
        #expect(deleted == true)
    }

    @Test("PillMenuLabel property integrity")
    func pillMenuLabelProperties() {
        let view = PillMenuLabel(text: "Test", icon: "star", color: .blue)

        #expect(view.text == "Test")
        #expect(view.icon == "star")
        #expect(view.color == .blue)
    }

    @Test("AppPrimaryButtonStyle property integrity")
    func buttonStyleProperties() {
        let style = AppPrimaryButtonStyle(color: .red, maxWidth: 200, isProminent: true)

        #expect(style.color == .red)
        #expect(style.maxWidth == 200)
        #expect(style.isProminent == true)
    }

    @Test("AddScheduleView configuration logic")
    func addScheduleViewLogic() {
        let calendar = Calendar.current
        let now = Date()

        let config1 = AddScheduleView.configure(
            initialDay: 3, initialStartTime: nil, initialEndTime: nil, existingSchedule: nil)
        #expect(config1.days == [3])
        #expect(config1.name == "")

        let start = calendar.date(from: DateComponents(hour: 14, minute: 0))!
        let config2 = AddScheduleView.configure(
            initialDay: nil, initialStartTime: start, initialEndTime: nil, existingSchedule: nil)
        #expect(config2.startTime == start)
        let endHour = calendar.component(.hour, from: config2.endTime)
        #expect(endHour == 15)

        let existing = Schedule(
            name: "Existing", days: [1], startTime: now, endTime: now, colorIndex: 5, type: .unfocus
        )
        let config3 = AddScheduleView.configure(
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

        let config = AddScheduleView.configure(
            initialDay: nil, initialStartTime: start, initialEndTime: end, existingSchedule: nil)

        #expect(config.endTime == end)
    }
}
