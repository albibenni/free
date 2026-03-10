import AppKit

struct AppKitUISymbolSpec {
    let name: String
    let pointSize: CGFloat
    let weight: NSFont.Weight
}

enum AppKitUISymbols {
    enum Name {
        static let focus = "leaf.fill"
        static let schedules = "calendar"
        static let calendar = "calendar.badge.clock"
        static let pomodoro = "timer"
        static let allowedWebsites = "lock.fill"
        static let settings = "gearshape.fill"
        static let globe = "globe"
        static let breakCup = "cup.and.saucer.fill"
        static let target = "target"
        static let link = "link"
        static let linkSelected = "link.circle.fill"
        static let checkmark = "checkmark"
        static let closeCircle = "xmark.circle.fill"
        static let closeWindow = "xmark"
        static let plus = "plus"
        static let minus = "minus.circle.fill"
        static let plusFilled = "plus.circle.fill"
        static let plusCircle = "plus.circle"
        static let trash = "trash"
        static let trashFilled = "trash.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let sidebarLeft = "sidebar.left"
        static let sidebarRight = "sidebar.right"
        static let chevronLeft = "chevron.left"
        static let chevronRight = "chevron.right"
        static let chevronUp = "chevron.up"
        static let list = "list.bullet"
        static let importedCalendar = "calendar.badge.clock"
    }

    // Header + section icons
    static let appHeader = AppKitUISymbolSpec(name: Name.focus, pointSize: 30, weight: .regular)
    static let cardHeader = AppKitUISymbolSpec(name: Name.globe, pointSize: 16, weight: .semibold)
    static let warning = AppKitUISymbolSpec(name: Name.warning, pointSize: 14, weight: .bold)

    // Sidebar + toolbar
    static let sidebarToggle = AppKitUISymbolSpec(name: Name.sidebarLeft, pointSize: 13, weight: .semibold)
    static let sidebarSection = AppKitUISymbolSpec(name: Name.focus, pointSize: 13, weight: .medium)
    static let sidebarSectionSelected = AppKitUISymbolSpec(name: Name.focus, pointSize: 13, weight: .semibold)
    static let navChevron = AppKitUISymbolSpec(name: Name.chevronLeft, pointSize: 8, weight: .medium)
    static let listMode = AppKitUISymbolSpec(name: Name.list, pointSize: 11, weight: .regular)
    static let calendarMode = AppKitUISymbolSpec(name: Name.schedules, pointSize: 11, weight: .regular)

    // Generic controls
    static let iconButtonDefault = AppKitUISymbolSpec(name: Name.plus, pointSize: 11, weight: .semibold)
    static let addList = AppKitUISymbolSpec(name: Name.plus, pointSize: 10, weight: .bold)
    static let deleteList = AppKitUISymbolSpec(name: Name.trash, pointSize: 9.5, weight: .semibold)
    static let deleteRule = AppKitUISymbolSpec(name: Name.trash, pointSize: 13, weight: .regular)
    static let closeEditor = AppKitUISymbolSpec(name: Name.closeCircle, pointSize: 18, weight: .regular)
    static let toggleSidebarChevron = AppKitUISymbolSpec(name: Name.chevronUp, pointSize: 11, weight: .semibold)
    static let addSuggestion = AppKitUISymbolSpec(name: Name.plusCircle, pointSize: 12, weight: .regular)
    static let dialPlus = AppKitUISymbolSpec(name: Name.plusFilled, pointSize: 24, weight: .regular)
    static let dialMinus = AppKitUISymbolSpec(name: Name.minus, pointSize: 24, weight: .regular)

    // Schedules
    static let scheduleTypeFocus = AppKitUISymbolSpec(name: Name.target, pointSize: 11, weight: .semibold)
    static let scheduleTypeBreak = AppKitUISymbolSpec(name: Name.breakCup, pointSize: 11, weight: .semibold)
    static let importedBadge = AppKitUISymbolSpec(name: Name.importedCalendar, pointSize: 9, weight: .semibold)
    static let importedEditorBadge = AppKitUISymbolSpec(name: Name.importedCalendar, pointSize: 13, weight: .semibold)

    // Pomodoro
    static let pomodoroCenter = AppKitUISymbolSpec(name: Name.focus, pointSize: AppKitUIConstants.IconSize.extraLarge, weight: .semibold)
    static let pomodoroBreakCenter = AppKitUISymbolSpec(name: Name.breakCup, pointSize: AppKitUIConstants.IconSize.extraLarge, weight: .semibold)
    static let activeRuleSet = AppKitUISymbolSpec(name: Name.link, pointSize: 11, weight: .regular)

    // Status item
    static let menuBar = AppKitUISymbolSpec(name: Name.focus, pointSize: 14, weight: .semibold)
}
