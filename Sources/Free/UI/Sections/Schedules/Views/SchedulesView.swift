import AppKit
import Combine

final class SchedulesSheetViewController: NSViewController {
    private struct RenderSignature: Equatable {
        struct ExternalEventSnapshot: Equatable {
            let id: String
            let title: String
            let startDate: Date
            let endDate: Date
        }

        let appearanceMode: AppearanceMode
        let accentColorIndex: Int
        let schedules: [Schedule]
        let weekStartsOnMonday: Bool
        let calendarIntegrationEnabled: Bool
        let calendarImportsBlockTime: Bool
        let externalEvents: [ExternalEventSnapshot]

        init(appState: AppState) {
            appearanceMode = appState.appearanceMode
            accentColorIndex = appState.accentColorIndex
            schedules = appState.schedules
            weekStartsOnMonday = appState.weekStartsOnMonday
            calendarIntegrationEnabled = appState.calendarIntegrationEnabled
            calendarImportsBlockTime = appState.calendarImportsBlockTime
            externalEvents = appState.calendarProvider.events.map {
                ExternalEventSnapshot(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate
                )
            }
        }
    }

    private let appState: AppState
    private let onDismiss: () -> Void
    private let schedulesContainerView = SchedulesContainerNSView()
    private let calendarHourHeight: CGFloat = 80
    private let calendarDayHeaderHeight: CGFloat = 40
    private let calendarTimeLabelWidth: CGFloat = 60
    private let calendarTimeColumnGutter: CGFloat = 12

    private var viewMode: Int
    private var editorContext: ScheduleEditorContext?
    private var weekOffset: Int
    private var renderSignature: RenderSignature?
    private var refreshGeneration = 0
    private var cancellables: Set<AnyCancellable> = []

    init(
        appState: AppState,
        onDismiss: @escaping () -> Void,
        initialViewMode: Int = 1,
        initialEditorContext: ScheduleEditorContext? = nil,
        initialWeekOffset: Int = 0
    ) {
        self.appState = appState
        self.onDismiss = onDismiss
        viewMode = initialViewMode
        editorContext = initialEditorContext
        weekOffset = initialWeekOffset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        schedulesContainerView.onWindowAttached = { [weak self] _ in
            self?.updateWindowTitle()
        }
        view = schedulesContainerView
        applyConfiguration()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        AppKitAppStateObservation.bind(
            appState: appState,
            cancellables: &cancellables
        ) { [weak self] in
            self?.handleObservedAppStateChange()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowTitle()
    }

    private func handleObservedAppStateChange() {
        let nextSignature = RenderSignature(appState: appState)
        guard renderSignature != nextSignature else { return }
        refreshConfiguration()
    }

    private var dayOrder: [Int] {
        WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
    }

    private var currentWeekDates: [Date] {
        WeeklyCalendarSupport.getWeekDates(
            at: Date(),
            weekStartsOnMonday: appState.weekStartsOnMonday,
            offset: weekOffset
        )
    }

    private var currentWeekBounds: (Date, Date) {
        WeeklyCalendarSupport.weekBounds(for: currentWeekDates)
    }

    private var shouldShowExternalCalendarOverlay: Bool {
        appState.calendarIntegrationEnabled && !appState.calendarImportsBlockTime
    }

    private func refreshConfiguration() {
        applyConfiguration()
    }

    private func applyConfiguration() {
        renderSignature = RenderSignature(appState: appState)
        refreshGeneration += 1
        schedulesContainerView.configure(with: makeAppKitConfiguration())
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        let title = viewMode == 1 ? "Schedules · Calendar" : "Schedules · List"
        guard let window = schedulesContainerView.window else { return }
        window.title = title

        DispatchQueue.main.async {
            configureAppKitWindowButton(
                in: window,
                type: .closeButton,
                controlSize: .large
            )
        }
    }

    private func makeAppKitConfiguration() -> SchedulesAppKitConfiguration {
        let weekRange = currentWeekDates
        let (weekStart, weekEnd) = currentWeekBounds
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)

        return SchedulesAppKitConfiguration(
            viewMode: viewMode,
            monthTitle: WeeklyCalendarSupport.monthYearString(for: weekStart),
            schedules: appState.schedules,
            accentColor: accentColor,
            accentColorIndex: appState.accentColorIndex,
            appState: appState,
            editorContext: editorContext,
            calendarViewConfiguration: WeeklyCalendarSurfaceConfiguration(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekStart,
                weekEnd: weekEnd,
                positionedSchedules: WeeklyCalendarSupport.positionedSchedules(
                    schedules: appState.schedules,
                    weekRange: weekRange
                ),
                externalEvents: WeeklyCalendarSupport.visibleCalendarEvents(
                    appState.calendarProvider.events,
                    weekStart: weekStart,
                    weekEnd: weekEnd
                ),
                showsExternalEvents: shouldShowExternalCalendarOverlay,
                hourHeight: calendarHourHeight,
                dayHeaderHeight: calendarDayHeaderHeight,
                timeLabelWidth: calendarTimeLabelWidth,
                timeColumnGutter: calendarTimeColumnGutter,
                accentColor: accentColor,
                onQuickAdd: { [weak self] day, hour in
                    self?.quickAdd(day: day, hour: hour)
                },
                onCreateSelection: { [weak self] day, startHour, endHour in
                    self?.openSelectionEditor(day: day, startHour: startHour, endHour: endHour)
                },
                onOpenSchedule: { [weak self] day, schedule in
                    self?.openScheduleEditor(day: day, schedule: schedule)
                },
                onUpdateSchedule: { [weak appState] scheduleId, originalDay, targetDay, targetDate, start, end in
                    appState?.updateScheduleOccurrence(
                        id: scheduleId,
                        originalDay: originalDay,
                        targetDay: targetDay,
                        targetDate: targetDate,
                        start: start,
                        end: end
                    )
                }
            ),
            onChangeViewMode: { [weak self] nextMode in
                self?.viewMode = nextMode
                self?.refreshConfiguration()
            },
            onSelectSchedule: { [weak self] schedule in
                self?.editorContext = ScheduleEditorContext(schedule: schedule)
                self?.refreshConfiguration()
            },
            onDeleteSchedule: { [weak self] scheduleId in
                self?.deleteSchedule(scheduleId: scheduleId)
            },
            onToggleScheduleEnabled: { [weak self] scheduleId, isEnabled in
                self?.setScheduleEnabled(scheduleId: scheduleId, isEnabled: isEnabled)
            },
            onAddSchedule: { [weak self] in
                self?.openAddSchedule()
            },
            onDismissEditor: { [weak self] in
                self?.editorContext = nil
                self?.refreshConfiguration()
            },
            onDismiss: onDismiss,
            onPreviousWeek: { [weak self] in
                self?.goToPreviousWeek()
            },
            onCurrentWeek: { [weak self] in
                self?.goToCurrentWeek()
            },
            onNextWeek: { [weak self] in
                self?.goToNextWeek()
            }
        )
    }

    private func setScheduleEnabled(scheduleId: UUID, isEnabled: Bool) {
        guard let index = appState.schedules.firstIndex(where: { $0.id == scheduleId }) else {
            return
        }
        appState.schedules[index].isEnabled = isEnabled
    }

    private func goToPreviousWeek() {
        weekOffset -= 1
        refreshConfiguration()
    }

    private func goToCurrentWeek() {
        weekOffset = 0
        refreshConfiguration()
    }

    private func goToNextWeek() {
        weekOffset += 1
        refreshConfiguration()
    }

    private func quickAdd(day: Int, hour: Int) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: hour, minute: 0))
        let end = calendar.date(from: DateComponents(hour: hour + 1, minute: 0))

        editorContext = ScheduleEditorContext(
            day: day,
            startTime: start,
            endTime: end,
            schedule: nil,
            weekOffset: weekOffset
        )
        refreshConfiguration()
    }

    private func openSelectionEditor(day: Int, startHour: CGFloat, endHour: CGFloat) {
        let result = WeeklyCalendarSupport.calculateDragSelection(
            startHour: startHour,
            endHour: endHour
        )

        editorContext = ScheduleEditorContext(
            day: day,
            startTime: result.start,
            endTime: result.end,
            schedule: nil,
            weekOffset: weekOffset
        )
        refreshConfiguration()
    }

    private func openScheduleEditor(day: Int, schedule: Schedule) {
        editorContext = ScheduleEditorContext(
            day: day,
            schedule: schedule,
            weekOffset: weekOffset
        )
        refreshConfiguration()
    }

    private func deleteSchedule(scheduleId: UUID) {
        guard let schedule = appState.schedules.first(where: { $0.id == scheduleId }) else {
            return
        }
        guard schedule.importedCalendarEventKey == nil else { return }
        appState.deleteSchedule(id: scheduleId, modifyAllDays: true, initialDay: nil)
    }

    private func openAddSchedule() {
        editorContext = ScheduleEditorContext()
        refreshConfiguration()
    }
}

extension SchedulesSheetViewController {
    var viewModeForTesting: Int { viewMode }
    var weekOffsetForTesting: Int { weekOffset }
    var editorContextForTesting: ScheduleEditorContext? { editorContext }
    var monthTitleForTesting: String { makeAppKitConfiguration().monthTitle }
    var calendarConfigurationForTesting: WeeklyCalendarSurfaceConfiguration {
        makeAppKitConfiguration().calendarViewConfiguration
    }

    func openAddScheduleForTesting() {
        openAddSchedule()
    }

    func goToPreviousWeekForTesting() {
        goToPreviousWeek()
    }

    func goToCurrentWeekForTesting() {
        goToCurrentWeek()
    }

    func goToNextWeekForTesting() {
        goToNextWeek()
    }

    func deleteScheduleForTesting(scheduleId: UUID) {
        deleteSchedule(scheduleId: scheduleId)
    }

    func removeSchedulesForTesting(at indexSet: IndexSet) {
        let idsToDelete: [UUID] = indexSet.compactMap { offset in
            guard appState.schedules.indices.contains(offset) else { return nil }
            let schedule = appState.schedules[offset]
            guard schedule.importedCalendarEventKey == nil else { return nil }
            return schedule.id
        }
        for id in idsToDelete {
            appState.deleteSchedule(id: id, modifyAllDays: true, initialDay: nil)
        }
    }

    func selectScheduleForTesting(_ schedule: Schedule) {
        editorContext = ScheduleEditorContext(schedule: schedule)
        refreshConfiguration()
    }

    var refreshGenerationForTesting: Int { refreshGeneration }
}
