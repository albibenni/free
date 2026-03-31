import Foundation

enum SchedulesSheetPresentationCoordinator {
    private static let minimumWeekOffset = -1

    enum WeekNavigationAction {
        case previous
        case current
        case next
    }

    static func windowTitle(
        viewMode: Int
    ) -> String {
        viewMode == 0 ? "Schedules · Calendar" : "Schedules · List"
    }

    static func weekOffset(
        current: Int,
        action: WeekNavigationAction
    ) -> Int {
        switch action {
        case .previous:
            max(current - 1, minimumWeekOffset)
        case .current:
            0
        case .next:
            current + 1
        }
    }
}
