import AppKit
import Combine

final class SchedulesSheetViewController: NSViewController {
    typealias AlertFactory = () -> NSAlert
    typealias AlertRunner = (NSAlert) -> NSApplication.ModalResponse

    private static var _makeScheduleModificationBlockedAlert: AlertFactory?
    private static var _runScheduleModificationBlockedAlert: AlertRunner?
    static var makeScheduleModificationBlockedAlert: AlertFactory {
        get { _makeScheduleModificationBlockedAlert ?? defaultMakeScheduleModificationBlockedAlert }
        set { _makeScheduleModificationBlockedAlert = newValue }
    }
    static var runScheduleModificationBlockedAlert: AlertRunner {
        get { _runScheduleModificationBlockedAlert ?? defaultRunScheduleModificationBlockedAlert }
        set { _runScheduleModificationBlockedAlert = newValue }
    }

    private static func defaultMakeScheduleModificationBlockedAlert() -> NSAlert { NSAlert() }
    private static func defaultRunScheduleModificationBlockedAlert(
        _ alert: NSAlert
    ) -> NSApplication.ModalResponse {
        if AppDelegate.isRunningInTestProcess() {
            return .alertFirstButtonReturn
        }
        return alert.runModal()
    }

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

        init(appState: AppState, viewMode: Int) {
            appearanceMode = appState.appearanceMode
            accentColorIndex = appState.accentColorIndex
            schedules = appState.schedules
            let isCalendarMode = viewMode == 1
            if isCalendarMode {
                weekStartsOnMonday = appState.weekStartsOnMonday
                calendarIntegrationEnabled = appState.calendarIntegrationEnabled
                calendarImportsBlockTime = appState.calendarImportsBlockTime
                let shouldIncludeExternalEvents = appState.calendarIntegrationEnabled && !appState.calendarImportsBlockTime
                externalEvents = shouldIncludeExternalEvents
                    ? appState.calendarProvider.events.map {
                        ExternalEventSnapshot(
                            id: $0.id,
                            title: $0.title,
                            startDate: $0.startDate,
                            endDate: $0.endDate
                        )
                    }
                    : []
            } else {
                weekStartsOnMonday = false
                calendarIntegrationEnabled = false
                calendarImportsBlockTime = false
                externalEvents = []
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

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        schedulesContainerView.onWindowAttached = { [weak self] _ in
            self?.updateWindowTitle()
        }
        view = schedulesContainerView
        applyConfiguration(signature: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.schedulesPublisher(appState: appState),
            signature: { [unowned self, appState] in
                RenderSignature(appState: appState, viewMode: self.viewMode)
            },
            cancellables: &cancellables
        ) { [weak self] nextSignature in
            self?.applyConfiguration(signature: nextSignature)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowTitle()
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

    private var canModifySchedules: Bool {
        !appState.isStrictActive
    }

    private func showScheduleModificationBlockedAlert() {
        let alert = Self.makeScheduleModificationBlockedAlert()
        alert.alertStyle = .warning
        alert.messageText = "Schedule Editing Locked"
        alert.informativeText =
            "Schedule changes are disabled while Focus Mode and Unblockable Mode are both active."
        alert.addButton(withTitle: "OK")
        _ = Self.runScheduleModificationBlockedAlert(alert)
    }

    private func refreshConfiguration(force: Bool = true) {
        if !force {
            let nextSignature = RenderSignature(appState: appState, viewMode: viewMode)
            guard renderSignature != nextSignature else { return }
            applyConfiguration(signature: nextSignature)
            return
        }
        applyConfiguration(signature: nil)
    }

    private func applyConfiguration(signature: RenderSignature?) {
        renderSignature = signature ?? RenderSignature(appState: appState, viewMode: viewMode)
        refreshGeneration += 1
        schedulesContainerView.configure(with: makeAppKitConfiguration())
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        let title = SchedulesSheetPresentationCoordinator.windowTitle(viewMode: viewMode)
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
        let visibleExternalEvents = WeeklyCalendarSupport.visibleCalendarEvents(
            appState.calendarProvider.events,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
        let mirroredImportedEventKeys = Set(appState.schedules.compactMap(\.importedCalendarEventKey))
        let externalEventsForOverlay = visibleExternalEvents.filter {
            !mirroredImportedEventKeys.contains($0.id)
        }

        return SchedulesAppKitConfiguration(
            viewMode: viewMode,
            monthTitle: WeeklyCalendarSupport.monthYearString(for: weekStart),
            schedules: appState.schedules,
            accentColor: accentColor,
            accentColorIndex: appState.accentColorIndex,
            canModifySchedules: canModifySchedules,
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
                externalEvents: externalEventsForOverlay,
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
                onUpdateSchedule: { [weak self, weak appState] scheduleId, originalDay, targetDay, targetDate, start, end in
                    guard let self else { return }
                    guard self.canModifySchedules else {
                        self.showScheduleModificationBlockedAlert()
                        return
                    }
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
                guard let self else { return }
                guard self.canModifySchedules else {
                    self.showScheduleModificationBlockedAlert()
                    return
                }
                self.editorContext = ScheduleEditorContext(schedule: schedule)
                self.refreshConfiguration()
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
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
        guard let index = appState.schedules.firstIndex(where: { $0.id == scheduleId }) else {
            return
        }
        appState.schedules[index].isEnabled = isEnabled
    }

    private func goToPreviousWeek() {
        weekOffset = SchedulesSheetPresentationCoordinator.weekOffset(
            current: weekOffset,
            action: .previous
        )
        refreshConfiguration()
    }

    private func goToCurrentWeek() {
        weekOffset = SchedulesSheetPresentationCoordinator.weekOffset(
            current: weekOffset,
            action: .current
        )
        refreshConfiguration()
    }

    private func goToNextWeek() {
        weekOffset = SchedulesSheetPresentationCoordinator.weekOffset(
            current: weekOffset,
            action: .next
        )
        refreshConfiguration()
    }

    private func quickAdd(day: Int, hour: Int) {
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
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
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
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
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
        editorContext = ScheduleEditorContext(
            day: day,
            schedule: schedule,
            weekOffset: weekOffset
        )
        refreshConfiguration()
    }

    private func deleteSchedule(scheduleId: UUID) {
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
        guard let schedule = appState.schedules.first(where: { $0.id == scheduleId }) else {
            return
        }
        guard schedule.importedCalendarEventKey == nil else { return }
        appState.deleteSchedule(id: scheduleId, modifyAllDays: true, initialDay: nil)
    }

    private func openAddSchedule() {
        guard canModifySchedules else {
            showScheduleModificationBlockedAlert()
            return
        }
        editorContext = ScheduleEditorContext()
        refreshConfiguration()
    }
}

extension SchedulesSheetViewController {
    var appKitConfigurationForTesting: SchedulesAppKitConfiguration {
        makeAppKitConfiguration()
    }

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

    func removableScheduleIDForTesting(at offset: Int) -> UUID? {
        guard appState.schedules.indices.contains(offset) else { return nil }
        let schedule = appState.schedules[offset]
        guard schedule.importedCalendarEventKey == nil else { return nil }
        return schedule.id
    }

    func selectScheduleForTesting(_ schedule: Schedule) {
        editorContext = ScheduleEditorContext(schedule: schedule)
        refreshConfiguration()
    }

    var refreshGenerationForTesting: Int { refreshGeneration }

    func setScheduleEnabledForTesting(scheduleId: UUID, isEnabled: Bool) {
        setScheduleEnabled(scheduleId: scheduleId, isEnabled: isEnabled)
    }

    func quickAddForTesting(day: Int, hour: Int) {
        quickAdd(day: day, hour: hour)
    }

    func openSelectionEditorForTesting(day: Int, startHour: CGFloat, endHour: CGFloat) {
        openSelectionEditor(day: day, startHour: startHour, endHour: endHour)
    }

    func openScheduleEditorForTesting(day: Int, schedule: Schedule) {
        openScheduleEditor(day: day, schedule: schedule)
    }

    func refreshConfigurationForTesting(force: Bool) {
        refreshConfiguration(force: force)
    }

    func updateWindowTitleForTesting() {
        updateWindowTitle()
    }

    func listRowObjectIdentifierForTesting(scheduleId: UUID) -> ObjectIdentifier? {
        schedulesContainerView.listRowObjectIdentifierForTesting(scheduleId: scheduleId)
    }

    func invokeDismissForTesting() {
        onDismiss()
    }

    static func setScheduleModificationAlertHooksForTesting(
        make: AlertFactory? = nil,
        run: AlertRunner? = nil
    ) {
        _makeScheduleModificationBlockedAlert = make
        _runScheduleModificationBlockedAlert = run
    }

    static func resetScheduleModificationAlertHooksForTesting() {
        _makeScheduleModificationBlockedAlert = nil
        _runScheduleModificationBlockedAlert = nil
    }
}
