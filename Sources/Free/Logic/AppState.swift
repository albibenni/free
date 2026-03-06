import Combine
import Foundation

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

class AppState: ObservableObject {
    static let challengePhrase =
        "I am choosing to break my focus and I acknowledge that this may impact my productivity."
    let settingsStore: SettingsStore
    let logicFacade: AppStateLogicFacade

    @Published var isBlocking = false {
        didSet {
            handleIsBlockingDidChange()
        }
    }
    @Published var isUnblockable = false
    @Published var isTrusted = false
    @Published var weekStartsOnMonday = false
    @Published var accentColorIndex = 0
    @Published var appearanceMode: AppearanceMode = .system
    @Published var calendarIntegrationEnabled = false {
        didSet {
            handleCalendarIntegrationEnabledDidChange()
        }
    }
    @Published var calendarImportsBlockTime = false {
        didSet {
            handleCalendarImportsBlockTimeDidChange()
        }
    }
    @Published var blockNewTabs = false
    @Published var blockDeveloperHosts = false
    @Published var blockLocalNetworkHosts = false
    @Published var ruleSets: [RuleSet] = []
    @Published var activeRuleSetId: UUID? = nil
    @Published var schedules: [Schedule] = [] {
        didSet {
            handleSchedulesDidChange()
        }
    }

    @Published var pomodoroFocusDuration: Double = 25 {
        didSet {
            handlePomodoroFocusDurationDidChange()
        }
    }
    @Published var pomodoroBreakDuration: Double = 5 {
        didSet {
            handlePomodoroBreakDurationDidChange()
        }
    }

    @Published var isPaused = false
    @Published var pauseRemaining: TimeInterval = 0
    @Published var pomodoroStatus: PomodoroStatus = .none
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroStartedAt: Date?
    @Published var currentOpenUrls: [String] = []

    var monitor: BrowserMonitor?
    let calendarProvider: any CalendarProvider
    private var calendarCancellable: AnyCancellable?
    let launchAtLoginService: LaunchAtLoginService
    let timerCoordinator: AppStateTimerCoordinator
    private var persistenceCancellables = Set<AnyCancellable>()
    var wasStartedBySchedule = false
    var manuallyPausedScheduleIds: Set<UUID> = []
    var pomodoroRuleSetId: UUID?
    var isSynchronizingImportedSchedules = false
    var suppressedImportedCalendarEventKeys: Set<String> = []

    enum PomodoroStatus: String, Codable { case none, focus, breakTime }

    init(
        defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil,
        calendar: (any CalendarProvider)? = nil,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        logicFacade: AppStateLogicFacade = .live,
        launchAtLoginManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager(),
        canPromptForLaunchAtLogin: @escaping () -> Bool = {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        },
        isTesting: Bool = false
    ) {
        let dependencies = AppStateDependencyFactory.make(
            defaults: defaults,
            injectedCalendar: calendar,
            timerScheduler: timerScheduler,
            launchAtLoginManager: launchAtLoginManager,
            canPromptForLaunchAtLogin: canPromptForLaunchAtLogin,
            isTesting: isTesting
        )

        self.settingsStore = dependencies.settingsStore
        self.logicFacade = logicFacade
        self.calendarProvider = dependencies.calendarProvider
        self.timerCoordinator = dependencies.timerCoordinator
        self.launchAtLoginService = dependencies.launchAtLoginService

        let snapshot = AppStateBootstrapService.snapshot(from: settingsStore)
        applyBootstrapSnapshot(snapshot)
        persistenceCancellables = AppStateLifecycleService.bindPersistence(
            appState: self,
            settingsStore: settingsStore
        )

        // Migration for older builds that persisted IsBlocking but not its source.
        performLegacyBlockingMigrationIfNeeded()
        let runtimeBindings = AppStateLifecycleService.startRuntime(
            appState: self,
            injectedMonitor: monitor,
            isTesting: isTesting
        )
        self.monitor = runtimeBindings.monitor
        calendarCancellable = runtimeBindings.calendarCancellable
        checkSchedules()
    }

    deinit {
        AppStateLifecycleService.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable,
            persistenceCancellables: &persistenceCancellables
        )
    }

    func toggleBlocking() {
        let updated = logicFacade.toggleSession(
            current: sessionState,
            isUnblockable: sessionDomainState.isUnblockable,
            schedules: scheduleDomainState.schedules
        )
        applySessionState(updated)
    }

    func checkSchedules() {
        synchronizeImportedCalendarSchedulesIfNeeded()
        let updated = logicFacade.checkSession(
            current: sessionState,
            schedules: scheduleDomainState.schedules,
            pomodoroStatus: pomodoroDomainState.status,
            calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
            isUnblockable: sessionDomainState.isUnblockable,
            calendarImportsBlockTime: scheduleDomainState.calendarImportsBlockTime,
            calendarEvents: calendarProvider.events
        )
        applySessionState(updated)
    }

    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }
}
