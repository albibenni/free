import AppKit

final class MainSectionRouter {
    private let focusOverviewController: FocusSectionViewController
    private let schedulesViewController: SchedulesSheetViewController
    private let calendarSectionController: CalendarSectionViewController
    private let pomodoroSectionController: FocusSectionViewController
    private let allowedWebsitesSectionController: FocusSectionViewController
    private let settingsSectionController: SettingsSectionViewController

    init(
        focusOverviewController: FocusSectionViewController,
        schedulesViewController: SchedulesSheetViewController,
        calendarSectionController: CalendarSectionViewController,
        pomodoroSectionController: FocusSectionViewController,
        allowedWebsitesSectionController: FocusSectionViewController,
        settingsSectionController: SettingsSectionViewController
    ) {
        self.focusOverviewController = focusOverviewController
        self.schedulesViewController = schedulesViewController
        self.calendarSectionController = calendarSectionController
        self.pomodoroSectionController = pomodoroSectionController
        self.allowedWebsitesSectionController = allowedWebsitesSectionController
        self.settingsSectionController = settingsSectionController
    }

    func controller(for section: MainContentSection) -> NSViewController {
        switch section {
        case .settings:
            return settingsSectionController
        case .focus:
            return focusOverviewController
        case .schedules:
            return schedulesViewController
        case .calendar:
            return calendarSectionController
        case .pomodoro:
            return pomodoroSectionController
        case .allowedWebsites:
            return allowedWebsitesSectionController
        }
    }
}
