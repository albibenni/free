import Foundation

enum SchedulesSheetPresentationCoordinator {
    enum WeekNavigationAction {
        case previous
        case current
        case next
    }

    static func windowTitle(
        viewMode: Int
    ) -> String {
        viewMode == 1 ? "Schedules · Calendar" : "Schedules · List"
    }

    static func weekOffset(
        current: Int,
        action: WeekNavigationAction
    ) -> Int {
        switch action {
        case .previous:
            current - 1
        case .current:
            0
        case .next:
            current + 1
        }
    }
}
