import AppKit
import Combine

@MainActor
final class FreeShellState: ObservableObject {
    @Published var showSidebar = false
    @Published var selectedSection: MainContentSection = .focus
    @Published var showRules = false
    @Published var showSchedules = false
}

final class FreeStatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let statusLabelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")
    private let onQuit: () -> Void

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
        super.init()

        statusLabelItem.isEnabled = false
        quitItem.target = self
        quitItem.action = #selector(handleQuit)

        statusMenu.addItem(statusLabelItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
    }

    func update(statusText: String, isQuitDisabled: Bool, iconColor: NSColor) {
        statusLabelItem.title = statusText
        quitItem.isEnabled = !isQuitDisabled

        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = iconColor
    }

    @objc
    private func handleQuit() {
        onQuit()
    }
}

final class FreeSheetContainerViewController: NSViewController {
    private let titleText: String
    private let hostedController: NSViewController
    private let onDone: () -> Void

    private let titleLabel = NSTextField(labelWithString: "")
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let divider = AppKitDynamicView()
    private let contentContainer = NSView()

    init(title: String, contentController: NSViewController, onDone: @escaping () -> Void) {
        self.titleText = title
        self.hostedController = contentController
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        titleLabel.stringValue = titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        doneButton.target = self
        doneButton.action = #selector(handleDone)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.widthAnchor.constraint(equalToConstant: 76).isActive = true
        doneButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        doneButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        doneButton.setContentHuggingPriority(.required, for: .horizontal)
        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .regular

        divider.backgroundColorProvider = { NSColor.separatorColor }

        [titleLabel, doneButton, divider, contentContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        addChild(hostedController)
        let hostedView = hostedController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(hostedView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            contentContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostedView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    @objc
    private func handleDone() {
        onDone()
    }
}

final class FreeSheetWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void
    private let desiredContentSize: CGSize
    private var isClosingProgrammatically = false

    init(
        contentViewController: NSViewController,
        contentSize: CGSize,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        desiredContentSize = contentSize
        contentViewController.preferredContentSize = contentSize

        let window = NSWindow(contentViewController: contentViewController)
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.minSize = contentSize
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(for parentWindow: NSWindow) {
        guard let window else { return }
        restoreDesiredContentSize()
        parentWindow.beginSheet(window)
        restoreDesiredContentSize()
    }

    func restoreDesiredContentSize() {
        guard let window else { return }
        window.contentViewController?.preferredContentSize = desiredContentSize
        window.setContentSize(desiredContentSize)
        window.contentMinSize = desiredContentSize
        window.minSize = desiredContentSize
        let frameRect = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: desiredContentSize)
        )
        if abs(window.frame.width - frameRect.width) > 0.5
            || abs(window.frame.height - frameRect.height) > 0.5
        {
            window.setFrame(
                NSRect(origin: window.frame.origin, size: frameRect.size),
                display: true
            )
        }
        window.layoutIfNeeded()
    }

    func dismiss() {
        guard let window else { return }
        isClosingProgrammatically = true
        if let parentWindow = window.sheetParent {
            parentWindow.endSheet(window)
        }
        window.orderOut(nil)
        isClosingProgrammatically = false
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingProgrammatically else { return }
        onClose()
    }
}

final class AllowedWebsitesFloatingEditorViewController:
    NSViewController,
    NSTableViewDataSource,
    NSTableViewDelegate
{
    private let appState: AppState
    private var selectedRuleSetId: UUID?
    private var visibleRules: [String] = []
    private var cancellables: Set<AnyCancellable> = []

    private let listPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let urlField = NSTextField(string: "")
    private let addButton = ActionButton(title: "Add")
    private let removeButton = ActionButton(title: "Remove Selected")
    private let emptyLabel = NSTextField(labelWithString: "No allowed websites in this list yet.")
    private let tableView = NSTableView()
    private let tableScrollView = NSScrollView()

    init(appState: AppState, initialRuleSetId: UUID?) {
        self.appState = appState
        selectedRuleSetId = initialRuleSetId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        let listLabel = NSTextField(labelWithString: "List")
        listLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        listLabel.textColor = .secondaryLabelColor

        listPopup.target = self
        listPopup.action = #selector(handleRuleSetSelection)
        listPopup.translatesAutoresizingMaskIntoConstraints = false
        listPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let headerRow = NSStackView(views: [listLabel, listPopup, NSView()])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        urlField.placeholderString = "Add URL to allow..."
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.heightAnchor.constraint(equalToConstant: 30).isActive = true

        addButton.target = self
        addButton.action = #selector(handleAddRule)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .horizontal)

        let addRow = NSStackView(views: [urlField, addButton])
        addRow.orientation = .horizontal
        addRow.alignment = .centerY
        addRow.spacing = 10
        addRow.translatesAutoresizingMaskIntoConstraints = false

        let ruleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule"))
        ruleColumn.title = "Allowed Websites"
        ruleColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(ruleColumn)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(handleTableSelectionChange)
        tableView.doubleAction = #selector(handleRemoveSelected)

        tableScrollView.documentView = tableView
        tableScrollView.hasVerticalScroller = true
        tableScrollView.autohidesScrollers = true
        tableScrollView.drawsBackground = false
        tableScrollView.borderType = .noBorder
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let tableContainer = AppKitDynamicView()
        tableContainer.backgroundColorProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.35)
        }
        tableContainer.borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.45)
        }
        tableContainer.borderWidthValue = 1
        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = 8
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(tableScrollView)
        tableContainer.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableScrollView.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            tableScrollView.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            tableScrollView.topAnchor.constraint(equalTo: tableContainer.topAnchor, constant: 8),
            tableScrollView.bottomAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: tableContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableContainer.centerYAnchor),
        ])

        removeButton.target = self
        removeButton.action = #selector(handleRemoveSelected)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.widthAnchor.constraint(equalToConstant: 152).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        removeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        removeButton.setContentHuggingPriority(.required, for: .horizontal)

        let footerRow = NSStackView(views: [NSView(), removeButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 10
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        let divider = makeAppKitDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false

        [headerRow, addRow, divider, tableContainer, footerRow].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),

            addRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            addRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            addRow.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),

            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.topAnchor.constraint(equalTo: addRow.bottomAnchor, constant: 12),

            tableContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            tableContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            tableContainer.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),

            footerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            footerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            footerRow.topAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: 10),
            footerRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadContent()
            }
            .store(in: &cancellables)
        reloadContent()
    }

    func focusOnRuleSet(_ id: UUID?) {
        selectedRuleSetId = id
        reloadContent()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRules.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AllowedRuleCell")
        let cellView =
            (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView)
            ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier
                let label = NSTextField(labelWithString: "")
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                label.textColor = .labelColor
                label.lineBreakMode = .byTruncatingMiddle
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(label)
                cell.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }()
        if row >= 0, row < visibleRules.count {
            cellView.textField?.stringValue = visibleRules[row]
        }
        return cellView
    }

    @objc
    private func handleRuleSetSelection() {
        guard let selectedItem = listPopup.selectedItem else { return }
        guard let rawId = selectedItem.representedObject as? String else { return }
        selectedRuleSetId = UUID(uuidString: rawId)
        reloadRulesOnly()
    }

    @objc
    private func handleAddRule() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        appState.addRule(urlField.stringValue, to: setId)
        urlField.stringValue = ""
        reloadRulesOnly()
    }

    @objc
    private func handleRemoveSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < visibleRules.count else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        appState.removeRule(visibleRules[row], from: setId)
        reloadRulesOnly()
    }

    @objc
    private func handleTableSelectionChange() {
        updateControlStates()
    }

    private func reloadContent() {
        let previousSelection = selectedRuleSetId
        let resolvedSelection = resolvedRuleSetId(previousSelection)
        selectedRuleSetId = resolvedSelection
        reloadRuleSetPopup()
        reloadRulesOnly()
    }

    private func reloadRuleSetPopup() {
        let selectedRawValue = selectedRuleSetId?.uuidString
        listPopup.removeAllItems()
        for ruleSet in appState.ruleSets {
            listPopup.addItem(withTitle: ruleSet.name)
            listPopup.lastItem?.representedObject = ruleSet.id.uuidString
        }
        if let selectedRawValue {
            for (index, item) in listPopup.itemArray.enumerated() {
                if (item.representedObject as? String) == selectedRawValue {
                    listPopup.selectItem(at: index)
                    break
                }
            }
        } else if listPopup.numberOfItems > 0 {
            listPopup.selectItem(at: 0)
            if let rawId = listPopup.selectedItem?.representedObject as? String {
                selectedRuleSetId = UUID(uuidString: rawId)
            }
        }
    }

    private func reloadRulesOnly() {
        visibleRules =
            appState.ruleSets.first(where: { $0.id == selectedRuleSetId })?.urls
            ?? []
        tableView.reloadData()
        emptyLabel.isHidden = !visibleRules.isEmpty
        updateControlStates()
        applyButtonStyling()
    }

    private func applyButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        styleActionButton(addButton, title: "Add", color: accentColor)
        styleActionButton(removeButton, title: "Remove Selected", color: accentColor)
    }

    private func styleActionButton(_ button: ActionButton, title: String, color: NSColor) {
        button.isBordered = false
        button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
        button.focusRingType = .none
        button.setGradientBackground(
            colors: [
                color.withAlphaComponent(0.14),
                color.withAlphaComponent(0.08),
            ],
            borderColor: color.withAlphaComponent(0.28)
        )
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: AppKitUIConstants.Typography.buttonLabel,
                .foregroundColor: color,
            ]
        )
        button.contentTintColor = color
    }

    private func updateControlStates() {
        let canEdit = resolvedRuleSetId(selectedRuleSetId) != nil && !appState.isStrictActive
        let canRemove = canEdit && tableView.selectedRow >= 0 && tableView.selectedRow < visibleRules.count
        urlField.isEnabled = canEdit
        addButton.isEnabled = canEdit
        removeButton.isEnabled = canRemove
        listPopup.isEnabled = !appState.ruleSets.isEmpty
    }

    private func resolvedRuleSetId(_ id: UUID?) -> UUID? {
        if let id, appState.ruleSets.contains(where: { $0.id == id }) {
            return id
        }
        if let activeId = appState.activeRuleSetId,
           appState.ruleSets.contains(where: { $0.id == activeId })
        {
            return activeId
        }
        return appState.ruleSets.first?.id
    }
}

final class AllowedWebsitesSheetController: NSWindowController, NSWindowDelegate {
    private static let windowTitle = "Allowed Websites"

    private let onClose: () -> Void
    private let editorController: AllowedWebsitesFloatingEditorViewController
    private var isClosingProgrammatically = false
    private let desiredContentSize = CGSize(width: 760, height: 520)

    init(appState: AppState, onClose: @escaping () -> Void) {
        self.onClose = onClose
        editorController = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: appState.activeRuleSetId
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: desiredContentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = editorController
        panel.setContentSize(desiredContentSize)
        panel.contentMinSize = CGSize(width: 620, height: 420)
        panel.minSize = CGSize(width: 620, height: 420)
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true
        panel.title = Self.windowTitle
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: panel)
        panel.delegate = self
        editorController.focusOnRuleSet(appState.activeRuleSetId)
        Self.configureNativeCloseButton(in: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(for parentWindow: NSWindow, selectedRuleSetId: UUID?) {
        guard let window else { return }
        editorController.focusOnRuleSet(selectedRuleSetId)
        restoreDesiredContentSize()
        if let panel = window as? NSPanel {
            Self.configureNativeCloseButton(in: panel)
        }
        if !window.isVisible {
            let origin = NSPoint(
                x: parentWindow.frame.midX - (window.frame.width / 2),
                y: parentWindow.frame.midY - (window.frame.height / 2)
            )
            window.setFrameOrigin(origin)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreDesiredContentSize() {
        guard let window else { return }
        window.contentViewController?.preferredContentSize = desiredContentSize
        window.setContentSize(desiredContentSize)
    }

    private static func configureNativeCloseButton(in panel: NSPanel) {
        guard let closeButton = panel.standardWindowButton(.closeButton) else { return }
        closeButton.controlSize = .large
        let targetSize: CGFloat = 22
        let originalFrame = closeButton.frame
        closeButton.setFrameSize(NSSize(width: targetSize, height: targetSize))
        closeButton.setFrameOrigin(
            NSPoint(
                x: originalFrame.origin.x,
                y: originalFrame.origin.y - ((targetSize - originalFrame.height) / 2)
            )
        )
    }

    func dismiss() {
        guard let window else { return }
        isClosingProgrammatically = true
        window.close()
        isClosingProgrammatically = false
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingProgrammatically else { return }
        onClose()
    }
}

final class FreeMainWindowController: NSWindowController {
    init(rootViewController: NSViewController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = CGSize(width: 900, height: 800)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = rootViewController
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FreeMainViewController: NSViewController {
    private let appState: AppState
    private let shellState: FreeShellState
    private let focusOverviewController: FocusSectionViewController
    private let schedulesOverviewController: FocusSectionViewController
    private let pomodoroSectionController: FocusSectionViewController
    private let allowedWebsitesSectionController: FocusSectionViewController
    private let settingsSectionController: SettingsSectionViewController

    private let sidebarContainer = AppKitDynamicView()
    private let sidebarStack = NSStackView()
    private let headerRow = NSStackView()
    private let menuLabel = NSTextField(labelWithString: "Menu")
    private let sidebarToggleButton = NSButton()
    private let sidebarDivider = AppKitDynamicView()
    private let sectionButtonsStack = NSStackView()
    private let settingsDivider = AppKitDynamicView()
    private let contentDivider = AppKitDynamicView()
    private let contentContainer = NSView()

    private var sectionButtons: [MainContentSection: NSButton] = [:]
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var rulesSheetController: AllowedWebsitesSheetController?
    private var schedulesSheetController: FreeSheetWindowController?
    private var currentContentViewController: NSViewController?
    private var cancellables: Set<AnyCancellable> = []

    init(
        appState: AppState,
        initialSection: MainContentSection = .focus,
        initialShowSidebar: Bool = false
    ) {
        self.appState = appState
        let shellState = FreeShellState()
        shellState.selectedSection = initialSection
        shellState.showSidebar = initialShowSidebar
        self.shellState = shellState
        self.focusOverviewController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .all
        )
        self.schedulesOverviewController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .schedules
        )
        self.pomodoroSectionController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .pomodoro
        )
        self.allowedWebsitesSectionController = FocusSectionViewController(
            appState: appState,
            shellState: shellState,
            section: .allowedWebsites
        )
        self.settingsSectionController = SettingsSectionViewController(appState: appState)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        configureSidebar()
        configureContent()
        updateSidebarVisibility()
        updateSidebarSelection()
        updateContentController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindShellState()
    }

    func presentLaunchAtLoginPromptIfNeeded() {
        guard let window = view.window, appState.prepareLaunchAtLoginPromptIfNeeded() else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to launch at Login"
        alert.informativeText = "Would you like Free to start automatically when you log in?"
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not Now")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            _ = self?.appState.enableLaunchAtLogin()
        }
    }

    private func configureSidebar() {
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view.addSubview(sidebarContainer)

        contentDivider.translatesAutoresizingMaskIntoConstraints = false
        contentDivider.backgroundColorProvider = { NSColor.separatorColor }
        view.addSubview(contentDivider)

        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 12
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarStack)

        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        configureIconButton(sidebarToggleButton, symbolName: "sidebar.left")
        sidebarToggleButton.target = self
        sidebarToggleButton.action = #selector(toggleSidebar)
        menuLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerRow.addArrangedSubview(sidebarToggleButton)
        headerRow.addArrangedSubview(menuLabel)
        headerRow.addArrangedSubview(NSView())

        sidebarDivider.backgroundColorProvider = { NSColor.separatorColor }
        sidebarDivider.translatesAutoresizingMaskIntoConstraints = false
        sidebarDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        sidebarDivider.widthAnchor.constraint(equalToConstant: 156).isActive = true

        sectionButtonsStack.orientation = .vertical
        sectionButtonsStack.alignment = .leading
        sectionButtonsStack.spacing = 8

        for section in [.focus, .schedules, .pomodoro, .allowedWebsites] as [MainContentSection] {
            let button = sidebarButton(for: section)
            sectionButtons[section] = button
            sectionButtonsStack.addArrangedSubview(button)
        }

        settingsDivider.backgroundColorProvider = { NSColor.separatorColor }
        settingsDivider.translatesAutoresizingMaskIntoConstraints = false
        settingsDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        settingsDivider.widthAnchor.constraint(equalToConstant: 156).isActive = true

        if let settingsButton = sectionButtons[.settings] {
            settingsButton.removeFromSuperview()
        }
        let settingsButton = sidebarButton(for: .settings)
        sectionButtons[.settings] = settingsButton

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        [headerRow, sidebarDivider, sectionButtonsStack, spacer, settingsDivider, settingsButton]
            .forEach { sidebarStack.addArrangedSubview($0) }

        sidebarWidthConstraint = sidebarContainer.widthAnchor.constraint(equalToConstant: 56)
        sidebarWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentDivider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            contentDivider.topAnchor.constraint(equalTo: view.topAnchor),
            contentDivider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentDivider.widthAnchor.constraint(equalToConstant: 1),

            sidebarStack.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 12),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -12),
            sidebarStack.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 12),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor, constant: -12),
        ])
    }

    private func configureContent() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: contentDivider.trailingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindShellState() {
        shellState.$selectedSection
            .sink { [weak self] _ in
                self?.updateSidebarSelection()
                self?.updateContentController()
            }
            .store(in: &cancellables)

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSidebarSelection()
            }
            .store(in: &cancellables)

        shellState.$showRules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? self.presentRulesSheetIfNeeded() : self.dismissRulesSheetIfNeeded()
            }
            .store(in: &cancellables)

        shellState.$showSchedules
            .removeDuplicates()
            .sink { [weak self] isShown in
                guard let self else { return }
                isShown ? self.presentSchedulesSheetIfNeeded() : self.dismissSchedulesSheetIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func updateSidebarSelection() {
        for (section, button) in sectionButtons {
            applySidebarButtonStyle(button, section: section, isSelected: shellState.selectedSection == section)
        }
    }

    private func updateSidebarVisibility() {
        let isVisible = shellState.showSidebar
        menuLabel.isHidden = !isVisible
        sectionButtonsStack.isHidden = !isVisible
        sidebarDivider.isHidden = !isVisible
        settingsDivider.isHidden = !isVisible
        sectionButtons[.settings]?.isHidden = !isVisible
        sidebarWidthConstraint?.constant = isVisible ? 180 : 56
        let symbolName = isVisible ? "sidebar.left" : "sidebar.right"
        sidebarToggleButton.image = appKitSymbolImage(
            named: symbolName,
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor
        )
    }

    private func updateContentController() {
        let targetViewController: NSViewController
        switch shellState.selectedSection {
        case .settings:
            targetViewController = settingsSectionController
        case .focus:
            targetViewController = focusOverviewController
        case .schedules:
            targetViewController = schedulesOverviewController
        case .pomodoro:
            targetViewController = pomodoroSectionController
        case .allowedWebsites:
            targetViewController = allowedWebsitesSectionController
        }

        guard currentContentViewController !== targetViewController else { return }

        currentContentViewController?.view.removeFromSuperview()
        currentContentViewController?.removeFromParent()

        addChild(targetViewController)
        let childView = targetViewController.view
        childView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            childView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            childView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        currentContentViewController = targetViewController
    }

    private func applySelectedSection(_ section: MainContentSection) {
        shellState.selectedSection = section
        updateSidebarSelection()
        updateContentController()
    }

    private func configureIconButton(_ button: NSButton, symbolName: String) {
        configureAppKitIconButton(
            button,
            symbolName: symbolName,
            pointSize: 13,
            weight: .semibold,
            color: .secondaryLabelColor,
            backgroundColor: NSColor.labelColor.withAlphaComponent(0.05),
            cornerRadius: 8
        )
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func sidebarButton(for section: MainContentSection) -> NSButton {
        let button = LeadingInsetActionButton(title: section.rawValue)
        button.identifier = NSUserInterfaceItemIdentifier(section.rawValue)
        button.target = self
        button.action = #selector(handleSidebarButton(_:))
        button.leadingInset = 6
        button.titleAdditionalInset = 6
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 156).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        applySidebarButtonStyle(button, section: section, isSelected: shellState.selectedSection == section)
        return button
    }

    private func applySidebarButtonStyle(
        _ button: NSButton,
        section: MainContentSection,
        isSelected: Bool
    ) {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        let backgroundColor =
            isSelected
            ? accentColor.withAlphaComponent(0.18)
            : .clear
        let titleColor =
            isSelected
            ? NSColor.labelColor
            : NSColor.secondaryLabelColor
        let iconColor =
            isSelected
            ? accentColor
            : NSColor.secondaryLabelColor
        let fontWeight: NSFont.Weight = isSelected ? .semibold : .medium

        button.layer?.backgroundColor = backgroundColor.cgColor
        button.image = appKitSymbolImage(
            named: section.icon,
            pointSize: 13,
            weight: fontWeight,
            color: iconColor
        )
        button.attributedTitle = NSAttributedString(
            string: section.rawValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: fontWeight),
                .foregroundColor: titleColor,
            ]
        )
        button.needsDisplay = true
    }

    private func presentRulesSheetIfNeeded() {
        guard let parentWindow = view.window else { return }
        if let rulesSheetController {
            rulesSheetController.present(
                for: parentWindow,
                selectedRuleSetId: appState.activeRuleSetId
            )
            return
        }

        let controller = AllowedWebsitesSheetController(
            appState: appState
        ) { [weak self] in
            self?.rulesSheetController = nil
            if self?.shellState.showRules == true {
                self?.shellState.showRules = false
            }
        }
        rulesSheetController = controller
        controller.present(
            for: parentWindow,
            selectedRuleSetId: appState.activeRuleSetId
        )
    }

    private func dismissRulesSheetIfNeeded() {
        guard let controller = rulesSheetController else { return }
        rulesSheetController = nil
        controller.dismiss()
    }

    private func presentSchedulesSheetIfNeeded() {
        guard let parentWindow = view.window else { return }
        if let attachedSheet = parentWindow.attachedSheet,
           attachedSheet !== schedulesSheetController?.window
        {
            parentWindow.endSheet(attachedSheet)
            attachedSheet.orderOut(nil)
        }
        if let schedulesSheetController {
            schedulesSheetController.restoreDesiredContentSize()
            return
        }

        let schedulesController = SchedulesSheetViewController(appState: appState) { [weak self] in
            self?.shellState.showSchedules = false
        }
        let controller = FreeSheetWindowController(
            contentViewController: schedulesController,
            contentSize: CGSize(width: 750, height: 700)
        ) { [weak self] in
            self?.schedulesSheetController = nil
            if self?.shellState.showSchedules == true {
                self?.shellState.showSchedules = false
            }
        }
        schedulesSheetController = controller
        controller.present(for: parentWindow)
    }

    private func dismissSchedulesSheetIfNeeded() {
        guard let controller = schedulesSheetController else { return }
        schedulesSheetController = nil
        controller.dismiss()
    }

    private func section(for identifier: NSUserInterfaceItemIdentifier?) -> MainContentSection? {
        MainContentSection.allCases.first { section in
            identifier?.rawValue == section.rawValue
        }
    }

    @objc
    private func toggleSidebar() {
        shellState.showSidebar.toggle()
        updateSidebarVisibility()
    }

    @objc
    private func handleSidebarButton(_ sender: NSButton) {
        guard let section = section(for: sender.identifier) else { return }
        applySelectedSection(section)
    }
}

extension FreeMainViewController {
    var isSidebarVisibleForTesting: Bool { shellState.showSidebar }
    var selectedSectionForTesting: MainContentSection { shellState.selectedSection }
    var currentContentViewControllerForTesting: NSViewController? { currentContentViewController }
    var currentFocusSectionForTesting: FocusContentSection? {
        (currentContentViewController as? FocusSectionViewController)?.section
    }
    var pomodoroWidgetIdentifierForTesting: ObjectIdentifier? {
        pomodoroSectionController.widgetViewIdentifierForTesting
    }
    var selectedSidebarBackgroundColorForTesting: NSColor? {
        sectionButtons[shellState.selectedSection]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:))
    }
    func sidebarButtonLeadingInsetForTesting(_ section: MainContentSection) -> CGFloat? {
        (sectionButtons[section] as? LeadingInsetActionButton)?.leadingInset
    }

    func selectSectionForTesting(_ section: MainContentSection) {
        applySelectedSection(section)
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func isSidebarButtonSelectedForTesting(_ section: MainContentSection) -> Bool {
        guard let color = sectionButtons[section]?.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) else {
            return false
        }
        return color.alphaComponent > 0.01
    }
}
