import Foundation

@MainActor
enum FocusSectionOverviewCoordinator {
    struct Row: Equatable {
        let iconName: String
        let title: String
        let value: String
    }

    static func rows(appState: AppState) -> [Row] {
        let activeScheduleNames = appState.schedules
            .filter { $0.type == .focus && $0.isActive() }
            .map(\.name)
        let currentRuleSet = appState.ruleSets.first(where: { $0.id == appState.currentPrimaryRuleSetId })

        let shouldShowAllowList = FocusSectionSupport.shouldShowAllowListPreview(
            isBlocking: appState.isBlocking,
            pomodoroStatus: appState.pomodoroStatus,
            hasActiveFocusSchedule: !activeScheduleNames.isEmpty,
            hasCurrentRuleSet: currentRuleSet != nil
        )
        let shouldShowPomodoro = appState.pomodoroStatus != .none
        let shouldShowSchedules = !activeScheduleNames.isEmpty

        var rows: [Row] = []

        if shouldShowSchedules {
            rows.append(
                Row(
                    iconName: AppKitUISymbols.Name.schedules,
                    title: "Active Schedules",
                    value: activeScheduleNames.joined(separator: ", ")
                )
            )
        }

        if shouldShowAllowList, let currentRuleSet {
            rows.append(
                Row(
                    iconName: AppKitUISymbols.Name.globe,
                    title: "Allow List",
                    value: "\(currentRuleSet.name) • \(currentRuleSet.urls.count) rules"
                )
            )
        }

        if shouldShowPomodoro {
            rows.append(
                Row(
                    iconName: AppKitUISymbols.Name.pomodoro,
                    title: "Pomodoro",
                    value: "\(FocusSectionSupport.pomodoroPhaseLabel(status: appState.pomodoroStatus)) • \(appState.timeString(time: appState.pomodoroRemaining))"
                )
            )
        }

        return rows
    }
}
