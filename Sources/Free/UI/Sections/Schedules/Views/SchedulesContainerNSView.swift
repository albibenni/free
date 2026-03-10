import AppKit

final class SchedulesContainerNSView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let viewModeLabel = NSTextField(labelWithString: "View Mode")
    private let viewModeControl = NSSegmentedControl()
    private let navigationGroupView = AppKitDynamicView()
    private let previousWeekButton = IconInsetButton()
    private let todayButton = NSButton(title: "Today", target: nil, action: nil)
    private let nextWeekButton = IconInsetButton()
    private let listScrollView = NSScrollView()
    private let listDocumentView = SchedulesListDocumentNSView()
    private let calendarView = WeeklyCalendarSurfaceNSView()
    private let bottomDivider = AppKitDynamicView()
    private let addButton = NSButton(title: "Add Schedule", target: nil, action: nil)
    private var configuration: SchedulesAppKitConfiguration?
    private var editorSheetController: FreeSheetWindowController?
    private var presentedEditorContextId: UUID?
    private var editorDismissShouldClearContext = true
    var onWindowAttached: ((NSWindow?) -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )
        layer?.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .labelColor

        viewModeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        viewModeLabel.textColor = .labelColor

        configureViewModeControl()
        configureNavigationGroup()
        configureNavigationButton(previousWeekButton, symbolName: AppKitUISymbols.Name.chevronLeft)
        configureNavigationButton(nextWeekButton, symbolName: AppKitUISymbols.Name.chevronRight)
        configureTodayButton()
        configureAddButton()

        viewModeControl.target = self
        viewModeControl.action = #selector(changeViewMode)
        previousWeekButton.target = self
        previousWeekButton.action = #selector(goToPreviousWeek)
        todayButton.target = self
        todayButton.action = #selector(goToCurrentWeek)
        nextWeekButton.target = self
        nextWeekButton.action = #selector(goToNextWeek)
        addButton.target = self
        addButton.action = #selector(addSchedule)

        listScrollView.drawsBackground = false
        listScrollView.borderType = .noBorder
        listScrollView.hasVerticalScroller = true
        listScrollView.autohidesScrollers = true
        listScrollView.documentView = listDocumentView

        bottomDivider.backgroundColorProvider = { NSColor.separatorColor }

        addSubview(listScrollView)
        addSubview(calendarView)
        addSubview(titleLabel)
        addSubview(viewModeLabel)
        addSubview(viewModeControl)
        addSubview(navigationGroupView)
        addSubview(bottomDivider)
        addSubview(addButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAttached?(window)
        syncEditorPresentation()
    }

    func configure(with configuration: SchedulesAppKitConfiguration) {
        self.configuration = configuration
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )

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
            self?.handleEditorSheetDidClose()
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

    private func handleEditorSheetDidClose() {
        editorSheetController = nil
        presentedEditorContextId = nil
        if editorDismissShouldClearContext, configuration?.editorContext != nil {
            configuration?.onDismissEditor()
        }
        editorDismissShouldClearContext = true
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
            appKitSymbolImage(spec: AppKitUISymbols.listMode),
            forSegment: 0
        )
        viewModeControl.setImage(
            appKitSymbolImage(spec: AppKitUISymbols.calendarMode),
            forSegment: 1
        )
    }

    private func configureNavigationGroup() {
        [previousWeekButton, todayButton, nextWeekButton].forEach { navigationGroupView.addSubview($0) }
    }

    private func configureNavigationButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbol: AppKitUISymbolSpec(
                name: symbolName,
                pointSize: AppKitUISymbols.navChevron.pointSize,
                weight: AppKitUISymbols.navChevron.weight
            ),
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
    }

    private func layoutToolbar(in rect: CGRect) {
        let centerSpacing: CGFloat = 10
        let segmentedSize = CGSize(width: 54, height: 28)
        let modeLabelSize = viewModeLabel.intrinsicContentSize
        let centerWidth = modeLabelSize.width + centerSpacing + segmentedSize.width
        let centerOriginX = rect.midX - centerWidth / 2

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
        let navOriginX = rect.maxX - 16 - totalNavWidth

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
}

extension SchedulesContainerNSView {
    func listRowObjectIdentifierForTesting(scheduleId: UUID) -> ObjectIdentifier? {
        listDocumentView.rowObjectIdentifierForTesting(scheduleId: scheduleId)
    }

    func addScheduleForTesting() {
        addSchedule()
    }

    func changeViewModeForTesting() {
        changeViewMode()
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

    func setEditorSheetControllerForTesting(_ controller: FreeSheetWindowController?) {
        editorSheetController = controller
    }

    func dismissEditorIfNeededForTesting(clearContext: Bool = false) {
        dismissEditorIfNeeded(clearContext: clearContext)
    }
}
