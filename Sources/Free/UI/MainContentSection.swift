enum MainContentSection: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case schedules = "Schedules"
    case pomodoro = "Pomodoro"
    case allowedWebsites = "Allowed Websites"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus:
            return "leaf.fill"
        case .schedules:
            return "calendar"
        case .allowedWebsites:
            return "lock.fill"
        case .pomodoro:
            return "timer"
        case .settings:
            return "gearshape.fill"
        }
    }
}
