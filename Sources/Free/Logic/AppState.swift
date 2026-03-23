import Combine
import Foundation

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

class AppState: ObservableObject {
    static let challengePhrase =
        "I undertand and want to quit!"
    let settingsStore: SettingsStore
    let logicFacade: AppStateLogicFacade

    @Published var isBlocking = false {
        didSet {
            AppStatePropertyEffectsService.handleIsBlockingDidChange(
                isBlocking: isBlocking,
                cancelPause: { cancelPause() }
            )
        }
    }
    @Published var isUnblockable = false
    @Published var isTrusted = false
    @Published var weekStartsOnMonday = false
    @Published var accentColorIndex = 0
    @Published var appearanceMode: AppearanceMode = .system
    @Published var cursorFluidAnimationEnabled = true
    @Published var calendarIntegrationEnabled = false {
        didSet {
            AppStatePropertyEffectsService.handleCalendarIntegrationEnabledDidChange(
                isEnabled: calendarIntegrationEnabled,
                requestAccess: { calendarProvider.requestAccess() },
                checkSchedules: { checkSchedules() }
            )
        }
    }
    @Published var calendarImportsBlockTime = false {
        didSet {
            AppStatePropertyEffectsService.handleCalendarImportsBlockTimeDidChange(
                checkSchedules: { checkSchedules() }
            )
        }
    }
    @Published var calendarImportFocusTitleRules: [String] = [] {
        didSet { checkSchedules() }
    }
    @Published var calendarImportBreakTitleRules: [String] = [] {
        didSet { checkSchedules() }
    }
    @Published var calendarImportedScheduleRuleSetId: UUID? = nil {
        didSet { checkSchedules() }
    }
    @Published var blockNewTabs = false
    @Published var blockDeveloperHosts = false
    @Published var blockLocalNetworkHosts = false
    @Published var allowSearchEngineWebsites = false
    @Published var allowAIProviderWebsites = false
    @Published var ruleSets: [RuleSet] = []
    @Published var activeRuleSetId: UUID? = nil
    @Published var schedules: [Schedule] = [] {
        didSet {
            AppStatePropertyEffectsService.handleSchedulesDidChange(
                schedules: schedules,
                settingsStore: settingsStore,
                checkSchedules: { checkSchedules() }
            )
        }
    }

    @Published var pomodoroFocusDuration: Double = 25 {
        didSet {
            pomodoroRemaining = AppStatePropertyEffectsService
                .updatedPomodoroRemainingAfterFocusDurationDidChange(
                    isFocusActive: pomodoroStatus == .focus,
                    focusDurationMinutes: pomodoroFocusDuration,
                    currentRemaining: pomodoroRemaining
                )
        }
    }
    @Published var pomodoroBreakDuration: Double = 5 {
        didSet {
            pomodoroRemaining = AppStatePropertyEffectsService
                .updatedPomodoroRemainingAfterBreakDurationDidChange(
                    isBreakActive: pomodoroStatus == .breakTime,
                    breakDurationMinutes: pomodoroBreakDuration,
                    currentRemaining: pomodoroRemaining
                )
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
    private let scheduleCheckSubject = PassthroughSubject<Void, Never>()
    private let isTesting: Bool
    var internalState = AppStateInternalState()

    init(
        defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil,
        calendar: (any CalendarProvider)? = nil,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        logicFacade: AppStateLogicFacade = .live,
        launchAtLoginManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager(),
        canPromptForLaunchAtLogin: @escaping () -> Bool = {
            let processInfo = ProcessInfo.processInfo
            let processName = processInfo.processName.lowercased()
            let isXCTestEnvironment = processInfo.environment["XCTestConfigurationFilePath"] != nil
            let isSwiftPMTestingHelper = processName.contains("swiftpm-testing-helper")
            let isXCTestProcess = processName.contains("xctest")
            let blockers = [isXCTestEnvironment, isSwiftPMTestingHelper, isXCTestProcess]
            let isBlocked = blockers.reduce(false) { $0 || $1 }
            return !isBlocked
        },
        isTesting: Bool = ProcessInfo.processInfo.environment["FREE_COVERAGE_MODE"] == "1"
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
        self.isTesting = isTesting

        let snapshot = AppStateBootstrapService.snapshot(from: settingsStore)
        let bootstrapProjection = AppStateLifecycleService.makeBootstrapProjection(snapshot: snapshot)
        applySessionDomainState(bootstrapProjection.session)
        applySettingsDomainState(bootstrapProjection.settings)
        applyPomodoroDomainState(bootstrapProjection.pomodoro)
        applyRulesDomainState(bootstrapProjection.rules)
        applyScheduleDomainState(bootstrapProjection.schedule)
        manualBlockingEnabled = snapshot.manualBlockingEnabled
        persistenceCancellables = AppStateLifecycleService.bindPersistence(
            bindings: persistenceBindings,
            settingsStore: settingsStore
        )
        scheduleCheckSubject
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] in self?.performCheckSchedules() }
            .store(in: &persistenceCancellables)

        // Migration for older builds that persisted IsBlocking but not its source.
        if let migration = AppStateLifecycleService.resolveLegacyBlockingMigration(
            logicFacade: logicFacade,
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
        let runtimeBindings = AppStateLifecycleService.startRuntime(
            injectedMonitor: monitor,
            isTesting: isTesting,
            calendarProvider: calendarProvider,
            timerCoordinator: timerCoordinator,
            monitorStateSnapshotProvider: { [weak self] in
                self.map { state in
                    BrowserMonitor.StateSnapshot(
                        isBlocking: state.isBlocking,
                        isPaused: state.isPaused,
                        blockNewTabs: state.blockNewTabs,
                        blockDeveloperHosts: state.blockDeveloperHosts,
                        blockLocalNetworkHosts: state.blockLocalNetworkHosts,
                        allowedRules: state.allowedRules
                    )
                }
            },
            onMonitorEvent: { [weak self] event in
                switch event {
                case .trustedStateChanged(let trusted):
                    self?.isTrusted = trusted
                }
            },
            onScheduleUpdate: { [weak self] in self?.checkSchedules() }
        )
        self.monitor = runtimeBindings.monitor
        calendarCancellable = runtimeBindings.calendarCancellable
        if isBlocking && !wasStartedBySchedule && !manualBlockingEnabled {
            isBlocking = false
        }
        performCheckSchedules()
    }

    deinit {
        AppStateLifecycleService.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &calendarCancellable,
            persistenceCancellables: &persistenceCancellables
        )
    }

    func toggleBlocking() {
        let wasBlocking = isBlocking
        let updated = logicFacade.toggleSession(
            current: sessionState,
            isUnblockable: sessionDomainState.isUnblockable,
            schedules: scheduleDomainState.schedules
        )
        applySessionState(updated)
        if !wasBlocking && updated.isBlocking {
            monitor?.checkPermissions(prompt: false)
        }
        if !wasBlocking && updated.isBlocking && !updated.wasStartedBySchedule {
            setManualBlockingEnabled(true)
        } else if wasBlocking && !updated.isBlocking {
            setManualBlockingEnabled(false)
        }
    }

    func checkSchedules() {
        if isTesting {
            performCheckSchedules()
        } else {
            scheduleCheckSubject.send()
        }
    }

    private func performCheckSchedules() {
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
