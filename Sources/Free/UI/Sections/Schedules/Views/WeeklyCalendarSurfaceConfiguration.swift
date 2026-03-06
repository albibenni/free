import AppKit

struct WeeklyCalendarSurfaceConfiguration {
    let dayOrder: [Int]
    let weekRange: [Date]
    let weekStart: Date
    let weekEnd: Date
    let positionedSchedules: [WeeklyCalendarSupport.PositionedSchedule]
    let externalEvents: [ExternalEvent]
    let showsExternalEvents: Bool
    let hourHeight: CGFloat
    let dayHeaderHeight: CGFloat
    let timeLabelWidth: CGFloat
    let timeColumnGutter: CGFloat
    let accentColor: NSColor
    let onQuickAdd: (Int, Int) -> Void
    let onCreateSelection: (Int, CGFloat, CGFloat) -> Void
    let onOpenSchedule: (Int, Schedule) -> Void
    let onUpdateSchedule: (UUID, Int, Int, Date?, Date, Date) -> Void
}
