enum MainContentSection: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case schedules = "Schedules"
    case calendar = "Calendar Settings"
    case pomodoro = "Pomodoro"
    case allowedWebsites = "Allowed Websites"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus:
            return AppKitUISymbols.Name.focus
        case .schedules:
            return AppKitUISymbols.Name.schedules
        case .calendar:
            return AppKitUISymbols.Name.calendar
        case .allowedWebsites:
            return AppKitUISymbols.Name.allowedWebsites
        case .pomodoro:
            return AppKitUISymbols.Name.pomodoro
        case .settings:
            return AppKitUISymbols.Name.settings
        }
    }
}
