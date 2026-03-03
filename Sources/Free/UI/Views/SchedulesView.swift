import SwiftUI
import AppKit

struct ScheduleEditorContext: Identifiable {
    let id = UUID()
    var day: Int?
    var startTime: Date?
    var endTime: Date?
    var schedule: Schedule?
    var weekOffset: Int = 0
}

struct SchedulesView: View {
    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    private let presentationBinding: Binding<Bool>?
    var appState: AppState { actionAppState ?? environmentAppState }
    @State private var viewMode = 1  // 0 = List, 1 = Calendar
    @State private var editorContext: ScheduleEditorContext?
    @State private var weekOffset: Int = 0

    private let calendarHourHeight: CGFloat = 80
    private let calendarDayHeaderHeight: CGFloat = 40
    private let calendarTimeLabelWidth: CGFloat = 60
    private let calendarTimeColumnGutter: CGFloat = 12

    init(
        initialViewMode: Int = 1,
        initialEditorContext: ScheduleEditorContext? = nil,
        actionAppState: AppState? = nil,
        presentationBinding: Binding<Bool>? = nil
    ) {
        self.actionAppState = actionAppState
        self.presentationBinding = presentationBinding
        _viewMode = State(initialValue: initialViewMode)
        _editorContext = State(initialValue: initialEditorContext)
    }

    var body: some View {
        SchedulesAppKitView(configuration: makeAppKitConfiguration())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var dayOrder: [Int] {
        WeeklyCalendarView.getDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
    }

    private var currentWeekDates: [Date] {
        WeeklyCalendarView.getWeekDates(
            at: Date(),
            weekStartsOnMonday: appState.weekStartsOnMonday,
            offset: weekOffset
        )
    }

    private var currentWeekBounds: (Date, Date) {
        WeeklyCalendarView.weekBounds(for: currentWeekDates)
    }

    private var shouldShowExternalCalendarOverlay: Bool {
        appState.calendarIntegrationEnabled && !appState.calendarImportsBlockTime
    }

    private func makeAppKitConfiguration() -> SchedulesAppKitConfiguration {
        let weekRange = currentWeekDates
        let (weekStart, weekEnd) = currentWeekBounds
        let dismissAction = presentationBinding.map { binding in
            { binding.wrappedValue = false }
        }
        return SchedulesAppKitConfiguration(
            viewMode: viewMode,
            monthTitle: monthYearString(for: weekStart),
            schedules: appState.schedules,
            accentColor: NSColor(FocusColor.color(for: appState.accentColorIndex)),
            accentColorIndex: appState.accentColorIndex,
            appState: appState,
            editorContext: editorContext,
            calendarViewConfiguration: WeeklyCalendarAppKitView(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekStart,
                weekEnd: weekEnd,
                positionedSchedules: positionedSchedules(weekRange: weekRange),
                externalEvents: visibleCalendarEvents(weekStart: weekStart, weekEnd: weekEnd),
                showsExternalEvents: shouldShowExternalCalendarOverlay,
                hourHeight: calendarHourHeight,
                dayHeaderHeight: calendarDayHeaderHeight,
                timeLabelWidth: calendarTimeLabelWidth,
                timeColumnGutter: calendarTimeColumnGutter,
                accentColor: NSColor(FocusColor.color(for: appState.accentColorIndex)),
                onQuickAdd: { day, hour in
                    quickAdd(day: day, hour: hour)
                },
                onCreateSelection: { day, startHour, endHour in
                    openSelectionEditor(day: day, startHour: startHour, endHour: endHour)
                },
                onOpenSchedule: { day, schedule in
                    openScheduleEditor(day: day, schedule: schedule)
                },
                onUpdateSchedule: {
                    scheduleId, originalDay, targetDay, targetDate, start, end in
                    appState.updateScheduleOccurrence(
                        id: scheduleId,
                        originalDay: originalDay,
                        targetDay: targetDay,
                        targetDate: targetDate,
                        start: start,
                        end: end
                    )
                }
            ),
            onChangeViewMode: { nextMode in
                viewMode = nextMode
            },
            onSelectSchedule: { schedule in
                selectScheduleAction(schedule: schedule)()
            },
            onDeleteSchedule: { scheduleId in
                deleteScheduleAction(scheduleId: scheduleId)()
            },
            onToggleScheduleEnabled: { scheduleId, isEnabled in
                setScheduleEnabled(scheduleId: scheduleId, isEnabled: isEnabled)
            },
            onAddSchedule: openAddSchedule,
            onDismissEditor: { editorContext = nil },
            onDismiss: dismissAction,
            onPreviousWeek: goToPreviousWeek,
            onCurrentWeek: goToCurrentWeek,
            onNextWeek: goToNextWeek
        )
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func visibleCalendarEvents(weekStart: Date, weekEnd: Date) -> [ExternalEvent] {
        appState.calendarProvider.events.filter {
            $0.startDate >= weekStart && $0.startDate < weekEnd
        }
    }

    private func shouldDisplaySchedule(_ schedule: Schedule, weekStart: Date, weekEnd: Date) -> Bool
    {
        let calendar = Calendar.current
        if let specificDate = schedule.date {
            let scheduleDay = calendar.startOfDay(for: specificDate)
            let weekStartDay = calendar.startOfDay(for: weekStart)
            let weekEndDay = calendar.startOfDay(for: weekEnd)
            return scheduleDay >= weekStartDay && scheduleDay < weekEndDay
        }
        return true
    }

    private func schedulePlacements(for schedule: Schedule, weekRange: [Date])
        -> [WeeklyCalendarView.SchedulePlacement]
    {
        let calendar = Calendar.current

        if let specificDate = schedule.date {
            guard
                let inWeekDate = weekRange.first(where: {
                    calendar.isDate($0, inSameDayAs: specificDate)
                })
            else {
                return []
            }

            return [
                WeeklyCalendarView.SchedulePlacement(
                    id:
                        "\(schedule.id.uuidString)-\(calendar.startOfDay(for: inWeekDate).timeIntervalSince1970)",
                    day: calendar.component(.weekday, from: inWeekDate),
                    startDate: schedule.startTime,
                    endDate: schedule.endTime
                )
            ]
        }

        return schedule.days.sorted().map { day in
            WeeklyCalendarView.SchedulePlacement(
                id: "\(schedule.id.uuidString)-\(day)",
                day: day,
                startDate: schedule.startTime,
                endDate: schedule.endTime
            )
        }
    }

    private func positionedSchedules(weekRange: [Date]) -> [WeeklyCalendarView.PositionedSchedule] {
        let bounds = WeeklyCalendarView.weekBounds(for: weekRange)
        let visible = appState.schedules.filter {
            shouldDisplaySchedule($0, weekStart: bounds.0, weekEnd: bounds.1)
        }
        let placements = visible.flatMap { schedule in
            schedulePlacements(for: schedule, weekRange: weekRange).map {
                (schedule: schedule, placement: $0)
            }
        }
        return WeeklyCalendarView.positionedSchedules(from: placements)
    }

    private func setScheduleEnabled(scheduleId: UUID, isEnabled: Bool) {
        guard let index = appState.schedules.firstIndex(where: { $0.id == scheduleId }) else {
            return
        }
        appState.schedules[index].isEnabled = isEnabled
    }

    private func goToPreviousWeek() {
        weekOffset -= 1
    }

    private func goToCurrentWeek() {
        weekOffset = 0
    }

    private func goToNextWeek() {
        weekOffset += 1
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
    }

    private func openSelectionEditor(day: Int, startHour: CGFloat, endHour: CGFloat) {
        let result = WeeklyCalendarView.calculateDragSelection(
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
    }

    private func openScheduleEditor(day: Int, schedule: Schedule) {
        editorContext = ScheduleEditorContext(
            day: day,
            schedule: schedule,
            weekOffset: weekOffset
        )
    }

    func deleteScheduleAction(scheduleId: UUID) -> () -> Void {
        {
            guard let schedule = appState.schedules.first(where: { $0.id == scheduleId }) else {
                return
            }
            guard schedule.importedCalendarEventKey == nil else { return }
            appState.deleteSchedule(id: scheduleId, modifyAllDays: true, initialDay: nil)
        }
    }

    func selectScheduleAction(schedule: Schedule) -> () -> Void {
        {
            editorContext = ScheduleEditorContext(schedule: schedule)
        }
    }

    func removeSchedules(at indexSet: IndexSet) {
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

    func openAddSchedule() {
        editorContext = ScheduleEditorContext()
    }

    func makeEditorPresentationBinding() -> Binding<Bool> {
        Binding(
            get: { editorContext != nil },
            set: { if !$0 { editorContext = nil } }
        )
    }

    func makeAddScheduleSheet(context: ScheduleEditorContext) -> some View {
        AddScheduleView(
            isPresented: makeEditorPresentationBinding(),
            initialDay: context.day,
            initialStartTime: context.startTime,
            initialEndTime: context.endTime,
            existingSchedule: context.schedule,
            editorContext: context
        )
    }

    var viewModeForTesting: Int { viewMode }
    var editorContextForTesting: ScheduleEditorContext? { editorContext }
}

    private struct SchedulesAppKitConfiguration {
        let viewMode: Int
        let monthTitle: String
        let schedules: [Schedule]
        let accentColor: NSColor
        let accentColorIndex: Int
        let appState: AppState
        let editorContext: ScheduleEditorContext?
        let calendarViewConfiguration: WeeklyCalendarAppKitView
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

    private struct SchedulesAppKitView: NSViewRepresentable {
        let configuration: SchedulesAppKitConfiguration

        func makeNSView(context: Context) -> SchedulesContainerNSView {
            let view = SchedulesContainerNSView()
            view.configure(with: configuration)
            return view
        }

        func updateNSView(_ nsView: SchedulesContainerNSView, context: Context) {
            nsView.configure(with: configuration)
        }
    }

    private final class SchedulesContainerNSView: NSView {
        private let titleLabel = NSTextField(labelWithString: "")
        private let viewModeLabel = NSTextField(labelWithString: "View Mode")
        private let viewModeControl = NSSegmentedControl()
        private let previousWeekButton = NSButton()
        private let todayButton = NSButton(title: "Today", target: nil, action: nil)
        private let nextWeekButton = NSButton()
        private let doneButton = NSButton(title: "Done", target: nil, action: nil)
        private let listScrollView = NSScrollView()
        private let listDocumentView = SchedulesListDocumentNSView()
        private let calendarView = WeeklyCalendarContainerNSView()
        private let bottomDivider = NSView()
        private let addButton = NSButton(title: "Add Schedule", target: nil, action: nil)
        private var configuration: SchedulesAppKitConfiguration?
        private var editorSheetController: FreeSheetWindowController?
        private var presentedEditorContextId: UUID?
        private var editorDismissShouldClearContext = true

        override var isFlipped: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)

            wantsLayer = true
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer?.masksToBounds = true

            titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
            titleLabel.textColor = .labelColor

            viewModeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            viewModeLabel.textColor = .labelColor

            configureViewModeControl()
            configureIconButton(previousWeekButton, symbolName: "chevron.left")
            configureIconButton(nextWeekButton, symbolName: "chevron.right")
            configureTodayButton()
            configureDoneButton()
            configureAddButton()

            viewModeControl.target = self
            viewModeControl.action = #selector(changeViewMode)
            previousWeekButton.target = self
            previousWeekButton.action = #selector(goToPreviousWeek)
            todayButton.target = self
            todayButton.action = #selector(goToCurrentWeek)
            nextWeekButton.target = self
            nextWeekButton.action = #selector(goToNextWeek)
            doneButton.target = self
            doneButton.action = #selector(dismissSheet)
            addButton.target = self
            addButton.action = #selector(addSchedule)

            listScrollView.drawsBackground = false
            listScrollView.borderType = .noBorder
            listScrollView.hasVerticalScroller = true
            listScrollView.autohidesScrollers = true
            listScrollView.documentView = listDocumentView

            bottomDivider.wantsLayer = true
            bottomDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor

            addSubview(listScrollView)
            addSubview(calendarView)
            addSubview(titleLabel)
            addSubview(viewModeLabel)
            addSubview(viewModeControl)
            addSubview(previousWeekButton)
            addSubview(todayButton)
            addSubview(nextWeekButton)
            addSubview(doneButton)
            addSubview(bottomDivider)
            addSubview(addButton)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            syncEditorPresentation()
        }

        func configure(with configuration: SchedulesAppKitConfiguration) {
            self.configuration = configuration

            applyAddButtonStyle(accentColor: configuration.accentColor)
            applyToolbarStyle(accentColor: configuration.accentColor)
            titleLabel.stringValue = configuration.viewMode == 1 ? configuration.monthTitle : "Schedules"
            titleLabel.isHidden = false
            viewModeLabel.isHidden = false
            viewModeControl.isHidden = false
            viewModeControl.selectedSegment = configuration.viewMode
            let showsCalendar = configuration.viewMode == 1
            previousWeekButton.isHidden = !showsCalendar
            todayButton.isHidden = !showsCalendar
            nextWeekButton.isHidden = !showsCalendar
            doneButton.isHidden = configuration.onDismiss == nil

            listDocumentView.configure(
                schedules: configuration.schedules,
                accentColorIndex: configuration.accentColorIndex,
                onSelectSchedule: configuration.onSelectSchedule,
                onDeleteSchedule: configuration.onDeleteSchedule,
                onToggleScheduleEnabled: configuration.onToggleScheduleEnabled
            )

            calendarView.configure(with: configuration.calendarViewConfiguration)
            listScrollView.isHidden = showsCalendar
            calendarView.isHidden = !showsCalendar

            syncEditorPresentation()
            needsLayout = true
        }

        private func syncEditorPresentation() {
            guard let configuration else { return }

            guard let context = configuration.editorContext else {
                dismissEditorIfNeeded()
                return
            }

            guard let window else { return }

            if presentedEditorContextId == context.id, editorSheetController != nil {
                return
            }

            dismissEditorIfNeeded()
            presentEditor(context: context, in: window, appState: configuration.appState)
        }

        private func presentEditor(
            context: ScheduleEditorContext,
            in window: NSWindow,
            appState: AppState
        ) {
            let editorViewController = ScheduleEditorViewController(
                appState: appState,
                context: context
            ) { [weak self] in
                self?.editorSheetController?.dismiss()
            }
            let controller = FreeSheetWindowController(
                contentViewController: editorViewController,
                contentSize: CGSize(width: 500, height: 650)
            ) { [weak self] in
                guard let self else { return }
                self.editorSheetController = nil
                self.presentedEditorContextId = nil
                if self.editorDismissShouldClearContext, self.configuration?.editorContext != nil {
                    self.configuration?.onDismissEditor()
                }
                self.editorDismissShouldClearContext = true
            }
            editorSheetController = controller
            presentedEditorContextId = context.id
            editorDismissShouldClearContext = true
            controller.present(for: window)
        }

        private func dismissEditorIfNeeded(clearContext: Bool = false) {
            guard let controller = editorSheetController else { return }
            editorDismissShouldClearContext = clearContext
            editorSheetController = nil
            presentedEditorContextId = nil
            controller.dismiss()
        }

        override func layout() {
            super.layout()

            let toolbarHeight: CGFloat = 52
            let bottomInset = safeAreaInsets.bottom
            let bottomBarHeight: CGFloat = 60
            let buttonHeight: CGFloat = 32
            let horizontalInset: CGFloat = 14

            let toolbarFrame = CGRect(x: 0, y: 0, width: bounds.width, height: toolbarHeight)
            layoutToolbar(in: toolbarFrame)

            let dividerY = max(
                bounds.height - bottomBarHeight - bottomInset - 1,
                0
            )
            bottomDivider.frame = CGRect(x: 0, y: dividerY, width: bounds.width, height: 1)
            addButton.frame = CGRect(
                x: horizontalInset,
                y: dividerY + (bottomBarHeight - buttonHeight) / 2,
                width: max(bounds.width - horizontalInset * 2, 0),
                height: buttonHeight
            )

            let contentFrame = CGRect(
                x: 0,
                y: toolbarFrame.maxY,
                width: bounds.width,
                height: max(dividerY - toolbarFrame.maxY, 0)
            )

            listScrollView.frame = contentFrame
            listDocumentView.layoutRows(width: listScrollView.contentSize.width)

            let calendarFrame = CGRect(
                x: 10,
                y: contentFrame.minY,
                width: max(contentFrame.width - 18, 0),
                height: contentFrame.height
            )
            calendarView.frame = calendarFrame
        }

        private func configureAddButton() {
            addButton.isBordered = false
            addButton.wantsLayer = true
            addButton.layer?.cornerRadius = 10
            addButton.font = .systemFont(ofSize: 14, weight: .semibold)
        }

        private func configureViewModeControl() {
            viewModeControl.segmentCount = 2
            viewModeControl.trackingMode = .selectOne
            viewModeControl.segmentStyle = .capsule
            viewModeControl.setWidth(27, forSegment: 0)
            viewModeControl.setWidth(27, forSegment: 1)
            viewModeControl.setImage(
                symbolImage(named: "list.bullet", pointSize: 11, weight: .regular),
                forSegment: 0
            )
            viewModeControl.setImage(
                symbolImage(named: "calendar", pointSize: 11, weight: .regular),
                forSegment: 1
            )
        }

        private func configureIconButton(_ button: NSButton, symbolName: String) {
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 14
            button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
            button.image = symbolImage(
                named: symbolName,
                pointSize: 11,
                weight: .semibold,
                color: .secondaryLabelColor
            )
            button.imagePosition = .imageOnly
        }

        private func configureTodayButton() {
            todayButton.isBordered = false
            todayButton.wantsLayer = true
            todayButton.layer?.cornerRadius = 8
            todayButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
            todayButton.font = .systemFont(ofSize: 12, weight: .semibold)
        }

        private func configureDoneButton() {
            doneButton.isBordered = false
            doneButton.wantsLayer = true
            doneButton.layer?.cornerRadius = 8
            doneButton.font = .systemFont(ofSize: 13, weight: .semibold)
        }

        private func applyAddButtonStyle(accentColor: NSColor) {
            addButton.layer?.backgroundColor = accentColor.withAlphaComponent(0.12).cgColor
            addButton.attributedTitle = NSAttributedString(
                string: "Add Schedule",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: accentColor,
                ]
            )
        }

        private func applyToolbarStyle(accentColor: NSColor) {
            todayButton.attributedTitle = NSAttributedString(
                string: "Today",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: accentColor,
                ]
            )
            doneButton.layer?.backgroundColor = accentColor.cgColor
            doneButton.attributedTitle = NSAttributedString(
                string: "Done",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.white,
                ]
            )
        }

        private func layoutToolbar(in rect: CGRect) {
            let centerSpacing: CGFloat = 10
            let segmentedSize = CGSize(width: 54, height: 28)
            let modeLabelSize = viewModeLabel.intrinsicContentSize
            let centerWidth = modeLabelSize.width + centerSpacing + segmentedSize.width
            let centerOriginX = rect.midX - centerWidth / 2
            let doneSize = CGSize(width: 58, height: 32)
            let doneOriginX = rect.maxX - 16 - doneSize.width

            viewModeLabel.frame = CGRect(
                x: centerOriginX,
                y: rect.minY + floor((rect.height - modeLabelSize.height) / 2),
                width: modeLabelSize.width,
                height: modeLabelSize.height
            )
            viewModeControl.frame = CGRect(
                x: viewModeLabel.frame.maxX + centerSpacing,
                y: rect.minY + floor((rect.height - segmentedSize.height) / 2),
                width: segmentedSize.width,
                height: segmentedSize.height
            )

            let titleSize = titleLabel.intrinsicContentSize
            titleLabel.frame = CGRect(
                x: 16,
                y: rect.minY + floor((rect.height - titleSize.height) / 2),
                width: min(titleSize.width, max(viewModeLabel.frame.minX - 32, 0)),
                height: titleSize.height
            )

            let navButtonSize = CGSize(width: 28, height: 28)
            let todaySize = CGSize(width: 54, height: 28)
            let navSpacing: CGFloat = 8
            let totalNavWidth = navButtonSize.width * 2 + todaySize.width + navSpacing * 2
            let navOriginX = doneButton.isHidden
                ? rect.maxX - 16 - totalNavWidth
                : doneOriginX - 12 - totalNavWidth

            previousWeekButton.frame = CGRect(
                x: navOriginX,
                y: rect.minY + floor((rect.height - navButtonSize.height) / 2),
                width: navButtonSize.width,
                height: navButtonSize.height
            )
            todayButton.frame = CGRect(
                x: previousWeekButton.frame.maxX + navSpacing,
                y: rect.minY + floor((rect.height - todaySize.height) / 2),
                width: todaySize.width,
                height: todaySize.height
            )
            nextWeekButton.frame = CGRect(
                x: todayButton.frame.maxX + navSpacing,
                y: rect.minY + floor((rect.height - navButtonSize.height) / 2),
                width: navButtonSize.width,
                height: navButtonSize.height
            )
            doneButton.frame = CGRect(
                x: doneOriginX,
                y: rect.minY + floor((rect.height - doneSize.height) / 2),
                width: doneSize.width,
                height: doneSize.height
            )
        }

        private func symbolImage(
            named symbolName: String,
            pointSize: CGFloat,
            weight: NSFont.Weight,
            color: NSColor? = nil
        ) -> NSImage? {
            guard
                let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            else {
                return nil
            }

            var configuredImage =
                baseImage.withSymbolConfiguration(
                    .init(pointSize: pointSize, weight: weight)
                )

            if let color {
                configuredImage = configuredImage?.withSymbolConfiguration(
                    .init(paletteColors: [color])
                )
            }

            return configuredImage ?? baseImage
        }

        @objc
        private func addSchedule() {
            configuration?.onAddSchedule()
        }

        @objc
        private func changeViewMode() {
            configuration?.onChangeViewMode(viewModeControl.selectedSegment)
        }

        @objc
        private func goToPreviousWeek() {
            configuration?.onPreviousWeek()
        }

        @objc
        private func goToCurrentWeek() {
            configuration?.onCurrentWeek()
        }

        @objc
        private func goToNextWeek() {
            configuration?.onNextWeek()
        }

        @objc
        private func dismissSheet() {
            configuration?.onDismiss?()
        }
    }

    private final class SchedulesListDocumentNSView: NSView {
        private var schedules: [Schedule] = []
        private var accentColorIndex: Int = 0
        private var onSelectSchedule: ((Schedule) -> Void)?
        private var onDeleteSchedule: ((UUID) -> Void)?
        private var onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
        private var rowViews: [UUID: SchedulesListRowNSView] = [:]

        override var isFlipped: Bool { true }

        func configure(
            schedules: [Schedule],
            accentColorIndex: Int,
            onSelectSchedule: @escaping (Schedule) -> Void,
            onDeleteSchedule: @escaping (UUID) -> Void,
            onToggleScheduleEnabled: @escaping (UUID, Bool) -> Void
        ) {
            self.schedules = schedules
            self.accentColorIndex = accentColorIndex
            self.onSelectSchedule = onSelectSchedule
            self.onDeleteSchedule = onDeleteSchedule
            self.onToggleScheduleEnabled = onToggleScheduleEnabled

            rebuildRows()
        }

        func layoutRows(width: CGFloat) {
            let rowHeight: CGFloat = 68
            let contentWidth = max(width, 1)
            var y: CGFloat = 0

            for (index, schedule) in schedules.enumerated() {
                guard let rowView = rowViews[schedule.id] else { continue }
                rowView.frame = CGRect(x: 0, y: y, width: contentWidth, height: rowHeight)
                rowView.showsSeparator = index < schedules.count - 1
                y += rowHeight
            }

            frame = CGRect(x: 0, y: 0, width: contentWidth, height: max(y, 1))
        }

        private func rebuildRows() {
            rowViews.values.forEach { $0.removeFromSuperview() }
            rowViews.removeAll()

            for schedule in schedules {
                let rowView = SchedulesListRowNSView()
                rowView.configure(
                    schedule: schedule,
                    accentColorIndex: accentColorIndex,
                    onSelectSchedule: onSelectSchedule,
                    onDeleteSchedule: onDeleteSchedule,
                    onToggleScheduleEnabled: onToggleScheduleEnabled
                )
                addSubview(rowView)
                rowViews[schedule.id] = rowView
            }

            needsLayout = true
        }
    }

    private final class SchedulesListRowNSView: NSView {
        var showsSeparator = true {
            didSet { needsDisplay = true }
        }

        private var schedule: Schedule?
        private var accentColorIndex: Int = 0
        private var onSelectSchedule: ((Schedule) -> Void)?
        private var onDeleteSchedule: ((UUID) -> Void)?
        private var onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
        private let deleteButton = NSButton()
        private let toggleSwitch = NSSwitch()

        override var isFlipped: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)

            deleteButton.isBordered = false
            deleteButton.image = symbolImage(
                named: "trash",
                pointSize: 13,
                weight: .regular,
                color: .systemRed
            )
            deleteButton.imagePosition = .imageOnly
            deleteButton.target = self
            deleteButton.action = #selector(deleteSchedule)

            toggleSwitch.controlSize = .small
            toggleSwitch.target = self
            toggleSwitch.action = #selector(toggleScheduleEnabled)

            addSubview(deleteButton)
            addSubview(toggleSwitch)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(
            schedule: Schedule,
            accentColorIndex: Int,
            onSelectSchedule: ((Schedule) -> Void)?,
            onDeleteSchedule: ((UUID) -> Void)?,
            onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
        ) {
            self.schedule = schedule
            self.accentColorIndex = accentColorIndex
            self.onSelectSchedule = onSelectSchedule
            self.onDeleteSchedule = onDeleteSchedule
            self.onToggleScheduleEnabled = onToggleScheduleEnabled

            toggleSwitch.state = schedule.isEnabled ? .on : .off
            deleteButton.isHidden = schedule.importedCalendarEventKey != nil

            needsLayout = true
            needsDisplay = true
        }

        override func layout() {
            super.layout()

            let toggleSize = toggleSwitch.fittingSize
            let toggleOriginX = bounds.width - 18 - toggleSize.width
            toggleSwitch.frame = CGRect(
                x: toggleOriginX,
                y: floor((bounds.height - toggleSize.height) / 2),
                width: toggleSize.width,
                height: toggleSize.height
            )

            let deleteSize = CGSize(width: 24, height: 24)
            deleteButton.frame = CGRect(
                x: toggleSwitch.frame.minX - 12 - deleteSize.width,
                y: floor((bounds.height - deleteSize.height) / 2),
                width: deleteSize.width,
                height: deleteSize.height
            )
        }

        override func mouseUp(with event: NSEvent) {
            guard let schedule else { return }
            onSelectSchedule?(schedule)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard let schedule else { return }

            if showsSeparator {
                NSColor.separatorColor.setStroke()
                let separator = NSBezierPath()
                separator.move(to: CGPoint(x: 0, y: bounds.maxY - 0.5))
                separator.line(to: CGPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
                separator.stroke()
            }

            let indicatorColor = NSColor(
                schedule.type == .focus
                    ? FocusColor.color(for: accentColorIndex)
                    : schedule.themeColor
            )
            let indicatorRect = CGRect(x: 16, y: 16, width: 4, height: bounds.height - 32)
            let indicatorPath = NSBezierPath(roundedRect: indicatorRect, xRadius: 2, yRadius: 2)
            indicatorColor.setFill()
            indicatorPath.fill()

            let contentLeft: CGFloat = 30
            let contentRight =
                deleteButton.isHidden
                ? toggleSwitch.frame.minX - 16
                : deleteButton.frame.minX - 16
            let availableWidth = max(contentRight - contentLeft, 0)

            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.lineBreakMode = .byTruncatingTail

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: titleParagraph,
            ]
            let secondaryAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: titleParagraph,
            ]

            var titleX = contentLeft
            let titleY: CGFloat = 10

            if let typeImage = symbolImage(
                named: schedule.type == .focus ? "target" : "cup.and.saucer.fill",
                pointSize: 11,
                weight: .semibold,
                color: .secondaryLabelColor
            ) {
                let iconRect = CGRect(x: titleX, y: titleY + 2, width: 11, height: 11)
                typeImage.draw(in: iconRect)
                titleX = iconRect.maxX + 6
            }

            let importedBadgeWidth: CGFloat = schedule.importedCalendarEventKey == nil ? 0 : 72
            let titleRect = CGRect(
                x: titleX,
                y: titleY,
                width: max(availableWidth - (titleX - contentLeft) - importedBadgeWidth, 0),
                height: 16
            )
            (schedule.name as NSString).draw(in: titleRect, withAttributes: titleAttributes)

            if schedule.importedCalendarEventKey != nil {
                drawBadge(
                    title: "Imported",
                    symbolName: "calendar.badge.clock",
                    in: CGRect(
                        x: max(titleRect.maxX + 8, contentLeft),
                        y: titleY - 1,
                        width: min(
                            importedBadgeWidth - 8, max(contentRight - titleRect.maxX - 8, 0)),
                        height: 18
                    )
                )
            }

            let timeRect = CGRect(
                x: contentLeft,
                y: 30,
                width: availableWidth,
                height: 14
            )
            (schedule.timeRangeString as NSString).draw(
                in: timeRect,
                withAttributes: secondaryAttributes
            )

            drawTag(
                title: schedule.daysString,
                in: CGRect(
                    x: contentLeft,
                    y: 48,
                    width: availableWidth,
                    height: 18
                )
            )
        }

        @objc
        private func deleteSchedule() {
            guard let schedule else { return }
            onDeleteSchedule?(schedule.id)
        }

        @objc
        private func toggleScheduleEnabled() {
            guard let schedule else { return }
            onToggleScheduleEnabled?(schedule.id, toggleSwitch.state == .on)
        }

        private func drawBadge(title: String, symbolName: String, in rect: CGRect) {
            guard rect.width > 24 else { return }

            let badgePath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
            badgePath.fill()

            if let icon = symbolImage(
                named: symbolName,
                pointSize: 9,
                weight: .semibold,
                color: .secondaryLabelColor
            ) {
                let iconRect = CGRect(x: rect.minX + 6, y: rect.minY + 4, width: 10, height: 10)
                icon.draw(in: iconRect)

                let textRect = CGRect(
                    x: iconRect.maxX + 4,
                    y: rect.minY + 2,
                    width: max(rect.width - 22, 0),
                    height: rect.height - 4
                )
                (title as NSString).draw(
                    in: textRect,
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ]
                )
            }
        }

        private func drawTag(title: String, in rect: CGRect) {
            let tagAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
            let textSize = (title as NSString).size(withAttributes: tagAttributes)
            let tagWidth = min(textSize.width + 12, rect.width)
            guard tagWidth > 0 else { return }

            let tagRect = CGRect(x: rect.minX, y: rect.minY, width: tagWidth, height: rect.height)
            let tagPath = NSBezierPath(roundedRect: tagRect, xRadius: 4, yRadius: 4)
            NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
            tagPath.fill()

            let textRect = CGRect(
                x: tagRect.minX + 6,
                y: tagRect.minY + 2,
                width: max(tagRect.width - 12, 0),
                height: tagRect.height - 4
            )
            (title as NSString).draw(in: textRect, withAttributes: tagAttributes)
        }

        private func symbolImage(
            named symbolName: String,
            pointSize: CGFloat,
            weight: NSFont.Weight,
            color: NSColor
        ) -> NSImage? {
            guard
                let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            else {
                return nil
            }

            let configuredImage =
                baseImage
                .withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))?
                .withSymbolConfiguration(.init(paletteColors: [color]))

            return configuredImage ?? baseImage
        }
    }
