import AppKit

struct SchedulesAppKitConfiguration {
    let viewMode: Int
    let monthTitle: String
    let schedules: [Schedule]
    let accentColor: NSColor
    let accentColorIndex: Int
    let canModifySchedules: Bool
    let appState: AppState
    let editorContext: ScheduleEditorContext?
    let calendarViewConfiguration: WeeklyCalendarSurfaceConfiguration
    let onChangeViewMode: (Int) -> Void
    let onSelectSchedule: (Schedule) -> Void
    let onDeleteSchedule: (UUID) -> Void
    let onToggleScheduleEnabled: (UUID, Bool) -> Void
    let onAddSchedule: () -> Void
    let onDismissEditor: () -> Void
    let onDismiss: (() -> Void)?
    let onPreviousWeek: () -> Void
    let onCurrentWeek: () -> Void
    let onNextWeek: () -> Void
}
