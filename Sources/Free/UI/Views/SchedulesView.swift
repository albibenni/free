import AppKit
import Combine

final class SchedulesSheetViewController: NSViewController {
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
        self.viewMode = initialViewMode
        self.editorContext = initialEditorContext
        self.weekOffset = initialWeekOffset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        schedulesContainerView.configure(with: makeAppKitConfiguration())
        view = schedulesContainerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshConfiguration()
            }
            .store(in: &cancellables)
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
        schedulesContainerView.configure(with: makeAppKitConfiguration())
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
}

    private struct SchedulesAppKitConfiguration {
        let viewMode: Int
        let monthTitle: String
        let schedules: [Schedule]
        let accentColor: NSColor
        let accentColorIndex: Int
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

    private final class SchedulesContainerNSView: NSView {
        private let titleLabel = NSTextField(labelWithString: "")
        private let viewModeLabel = NSTextField(labelWithString: "View Mode")
        private let viewModeControl = NSSegmentedControl()
        private let navigationGroupView = NSView()
        private let previousWeekButton = IconInsetButton()
        private let todayButton = NSButton(title: "Today", target: nil, action: nil)
        private let nextWeekButton = IconInsetButton()
        private let doneButton = NSButton(title: "Done", target: nil, action: nil)
        private let listScrollView = NSScrollView()
        private let listDocumentView = SchedulesListDocumentNSView()
        private let calendarView = WeeklyCalendarSurfaceNSView()
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
            configureNavigationGroup()
            configureNavigationButton(previousWeekButton, symbolName: "chevron.left")
            configureNavigationButton(nextWeekButton, symbolName: "chevron.right")
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
            addSubview(navigationGroupView)
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
            navigationGroupView.isHidden = !showsCalendar
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
                appKitSymbolImage(named: "list.bullet", pointSize: 11, weight: .regular),
                forSegment: 0
            )
            viewModeControl.setImage(
                appKitSymbolImage(named: "calendar", pointSize: 11, weight: .regular),
                forSegment: 1
            )
        }

        private func configureNavigationGroup() {
            [previousWeekButton, todayButton, nextWeekButton].forEach { navigationGroupView.addSubview($0) }
        }

        private func configureNavigationButton(_ button: NSButton, symbolName: String) {
            configureAppKitIconButton(
                button,
                symbolName: symbolName,
                pointSize: 8,
                weight: .medium,
                color: .labelColor.withAlphaComponent(0.9),
                backgroundColor: NSColor.white.withAlphaComponent(0.08),
                cornerRadius: 12,
                imageInset: 8
            )
        }

        private func configureTodayButton() {
            todayButton.isBordered = false
            todayButton.wantsLayer = true
            todayButton.layer?.cornerRadius = 11
            todayButton.layer?.cornerCurve = .continuous
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
            navigationGroupView.layer?.backgroundColor = nil
            previousWeekButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            nextWeekButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            previousWeekButton.contentTintColor = .labelColor.withAlphaComponent(0.9)
            nextWeekButton.contentTintColor = .labelColor.withAlphaComponent(0.9)
            todayButton.attributedTitle = NSAttributedString(
                string: "Today",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.labelColor,
                ]
            )
            todayButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
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

            let navButtonSize = CGSize(width: 24, height: 24)
            let todaySize = CGSize(width: 52, height: 24)
            let navSpacing: CGFloat = 8
            let totalNavWidth = navButtonSize.width * 2 + todaySize.width + navSpacing * 2
            let navOriginX = doneButton.isHidden
                ? rect.maxX - 16 - totalNavWidth
                : doneOriginX - 12 - totalNavWidth

            navigationGroupView.frame = CGRect(
                x: navOriginX,
                y: rect.minY + floor((rect.height - navButtonSize.height) / 2),
                width: totalNavWidth,
                height: navButtonSize.height
            )
            previousWeekButton.frame = CGRect(
                x: 0,
                y: 0,
                width: navButtonSize.width,
                height: navButtonSize.height
            )
            todayButton.frame = CGRect(
                x: previousWeekButton.frame.maxX + navSpacing,
                y: 0,
                width: todaySize.width,
                height: todaySize.height
            )
            nextWeekButton.frame = CGRect(
                x: todayButton.frame.maxX + navSpacing,
                y: 0,
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
            deleteButton.image = appKitSymbolImage(
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

            let indicatorColor =
                schedule.type == .focus
                ? FocusColor.nsColor(for: accentColorIndex)
                : FocusColor.nsColor(for: schedule.colorIndex)
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

            if let typeImage = appKitSymbolImage(
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

            if let icon = appKitSymbolImage(
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

    }
