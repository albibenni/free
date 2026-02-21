import SwiftUI

struct AddScheduleThemeColorRow: View {
    @Binding var selectedColorIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<FocusColor.all.count, id: \.self) { index in
                Circle().fill(FocusColor.all[index]).frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2 : 0).padding(-4))
                    .onTapGesture(perform: Self.makeSelectColorAction(selectedColorIndex: $selectedColorIndex, index: index))
            }
        }
    }

    static func makeSelectColorAction(selectedColorIndex: Binding<Int>, index: Int) -> () -> Void {
        { selectedColorIndex.wrappedValue = index }
    }
}

struct AddScheduleRecurringDaysRow: View {
    @EnvironmentObject var appState: AppState
    let existingSchedule: Schedule?
    let modifyAllDays: Bool
    let initialDay: Int?
    @Binding var days: Set<Int>

    var body: some View {
        if AddScheduleView.shouldShowSingleDayBadge(existingSchedule: existingSchedule, modifyAllDays: modifyAllDays, initialDay: initialDay), let day = initialDay {
            Text(AddScheduleView.dayName(for: day))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        } else {
            HStack(spacing: 12) {
                let order = AddScheduleView.weekDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
                ForEach(order, id: \.self) { day in
                    DayToggle(day: day, isSelected: days.contains(day), action: Self.makeToggleDayAction(days: $days, day: day))
                }
            }
        }
    }

    static func makeToggleDayAction(days: Binding<Set<Int>>, day: Int) -> () -> Void {
        { days.wrappedValue = AddScheduleView.toggledDays(days.wrappedValue, day: day) }
    }
}
