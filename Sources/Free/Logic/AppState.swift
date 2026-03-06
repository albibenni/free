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
            if !isBlocking { cancelPause() }
        }
    }
    @Published var isUnblockable = false
    @Published var isTrusted = false
    @Published var weekStartsOnMonday = false
    @Published var accentColorIndex = 0
    @Published var appearanceMode: AppearanceMode = .system
    @Published var calendarIntegrationEnabled = false {
        didSet {
            if calendarIntegrationEnabled { calendarProvider.requestAccess() }
            checkSchedules()
        }
    }
    @Published var calendarImportsBlockTime = false {
        didSet {
            checkSchedules()
        }
    }
    @Published var blockNewTabs = false
    @Published var blockDeveloperHosts = false
    @Published var blockLocalNetworkHosts = false
    @Published var ruleSets: [RuleSet] = []
    @Published var activeRuleSetId: UUID? = nil
    @Published var schedules: [Schedule] = [] {
        didSet {
            AppStatePersistenceCoordinator.persistSchedulesSynchronously(
                schedules,
                settingsStore: settingsStore
            )
            checkSchedules()
        }
    }

    @Published var pomodoroFocusDuration: Double = 25 {
        didSet {
            if pomodoroStatus == .focus { pomodoroRemaining = pomodoroFocusDuration * 60 }
        }
    }
    @Published var pomodoroBreakDuration: Double = 5 {
        didSet {
            if pomodoroStatus == .breakTime { pomodoroRemaining = pomodoroBreakDuration * 60 }
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

    var isPomodoroLocked: Bool {
        PomodoroEngine.isLocked(
            isUnblockable: isUnblockable,
            status: pomodoroStatus,
            startedAt: pomodoroStartedAt
        )
    }
    var isStrictActive: Bool { isBlocking && isUnblockable }

    var currentPrimaryRuleSetId: UUID? {
        logicFacade.currentPrimaryRuleSetId(context: ruleContext)
    }

    var currentPrimaryRuleSetName: String {
        logicFacade.currentPrimaryRuleSetName(context: ruleContext)
    }

    var allowedRules: [String] {
        logicFacade.allowedRules(context: ruleContext)
    }

    var todaySchedules: [Schedule] {
        logicFacade.todaySchedules(from: scheduleDomainState.schedules)
    }

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
        self.settingsStore = SettingsStore(defaults: defaults)
        self.logicFacade = logicFacade
        self.calendarProvider =
            calendar
            ?? (isTesting ? MockCalendarManager() : RealCalendarManager(nowProvider: { Date() }))
        self.timerCoordinator = AppStateTimerCoordinator(timerScheduler: timerScheduler)
        self.launchAtLoginService = LaunchAtLoginService(
            launchAtLoginManager: launchAtLoginManager,
            settingsStore: self.settingsStore,
            canPromptForLaunchAtLogin: canPromptForLaunchAtLogin
        )

        let snapshot = AppStateBootstrapService.snapshot(from: settingsStore)
        applySessionDomainState(
            AppSessionDomainState(
                isBlocking: snapshot.isBlocking,
                isUnblockable: snapshot.isUnblockable,
                isPaused: false,
                pauseRemaining: 0,
                wasStartedBySchedule: snapshot.wasStartedBySchedule,
                manuallyPausedScheduleIds: []
            )
        )
        applySettingsDomainState(
            AppSettingsDomainState(
                weekStartsOnMonday: snapshot.weekStartsOnMonday,
                accentColorIndex: snapshot.accentColorIndex,
                appearanceMode: snapshot.appearanceMode,
                blockNewTabs: snapshot.blockNewTabs,
                blockDeveloperHosts: snapshot.blockDeveloperHosts,
                blockLocalNetworkHosts: snapshot.blockLocalNetworkHosts
            )
        )
        applyPomodoroDomainState(
            AppPomodoroDomainState(
                status: .none,
                remaining: 0,
                startedAt: nil,
                focusDurationMinutes: snapshot.pomodoroFocusDuration,
                breakDurationMinutes: snapshot.pomodoroBreakDuration,
                ruleSetId: nil
            )
        )
        applyRulesDomainState(
            AppRulesDomainState(
                ruleSets: snapshot.ruleSets,
                activeRuleSetId: snapshot.activeRuleSetId
            )
        )
        applyScheduleDomainState(
            AppScheduleDomainState(
                schedules: snapshot.schedules,
                calendarIntegrationEnabled: snapshot.calendarIntegrationEnabled,
                calendarImportsBlockTime: snapshot.calendarImportsBlockTime,
                isSynchronizingImportedSchedules: false,
                suppressedImportedCalendarEventKeys: snapshot.suppressedImportedCalendarEventKeys
            )
        )
        persistenceCancellables = AppStatePersistenceCoordinator.bind(
            appState: self,
            settingsStore: settingsStore
        )

        // Migration for older builds that persisted IsBlocking but not its source.
        if let migration = logicFacade.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: settingsStore.hasPersistedWasStartedBySchedule(),
            current: sessionState,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarProvider.events
        ) {
            applySessionState(migration)
        }
        self.monitor = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: monitor,
            isTesting: isTesting
        ) {
            BrowserMonitor(appState: self)
        }

        calendarCancellable = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: calendarProvider,
            timerCoordinator: timerCoordinator,
            onCalendarChange: { [weak self] in self?.checkSchedules() },
            onScheduleTick: { [weak self] in self?.checkSchedules() }
        )
        checkSchedules()
    }

    deinit {
        AppStateRuntimeWiringCoordinator.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable
        )
        persistenceCancellables.removeAll()
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
