import AppKit

final class MainSectionRouter {
    private let focusOverviewController: FocusSectionViewController
    private let schedulesOverviewController: FocusSectionViewController
    private let pomodoroSectionController: FocusSectionViewController
    private let allowedWebsitesSectionController: FocusSectionViewController
    private let settingsSectionController: SettingsSectionViewController

    init(
        focusOverviewController: FocusSectionViewController,
        schedulesOverviewController: FocusSectionViewController,
        pomodoroSectionController: FocusSectionViewController,
        allowedWebsitesSectionController: FocusSectionViewController,
        settingsSectionController: SettingsSectionViewController
    ) {
        self.focusOverviewController = focusOverviewController
        self.schedulesOverviewController = schedulesOverviewController
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
            return schedulesOverviewController
        case .pomodoro:
            return pomodoroSectionController
        case .allowedWebsites:
            return allowedWebsitesSectionController
        }
    }
}
