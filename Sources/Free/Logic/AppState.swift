import Observation
import Combine
import Foundation

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

@MainActor
@Observable
class AppState {
    static let challengePhrase =
        "I understand and want to quit!"
    let settingsStore: SettingsStore
    let logicFacade: AppStateLogicFacade

    var isBlocking = false {
        didSet {
            AppStatePropertyEffectsService.handleIsBlockingDidChange(
                isBlocking: isBlocking,
                cancelPause: { cancelPause() }
            )
        }
    }
    var isStrict = false
    var isTrusted = false
    var weekStartsOnMonday = false
    var accentColorIndex = 0
    var appearanceMode: AppearanceMode = .system
    var cursorFluidAnimationEnabled = true
    var calendarIntegrationEnabled = false {
        didSet {
            AppStatePropertyEffectsService.handleCalendarIntegrationEnabledDidChange(
                isEnabled: calendarIntegrationEnabled,
                requestAccess: { calendarProvider.requestAccess() },
                checkSchedules: { checkSchedules() }
            )
        }
    }
    var calendarImportFocusTitleRules: [String] = [] {
        didSet { checkSchedules() }
    }
    var calendarImportBreakTitleRules: [String] = [] {
        didSet { checkSchedules() }
    }
    var calendarImportedScheduleRuleSetId: UUID? = nil {
        didSet { checkSchedules() }
    }
    var blockNewTabs = false
    var blockDeveloperHosts = false
    var blockLocalNetworkHosts = false
    var allowSearchEngineWebsites = false
    var allowAIProviderWebsites = false
    var ruleSets: [RuleSet] = []
    var activeRuleSetId: UUID? = nil
    var schedules: [Schedule] = [] {
        didSet {
            AppStatePropertyEffectsService.handleSchedulesDidChange(
                schedules: schedules,
                settingsStore: settingsStore,
                checkSchedules: { checkSchedules() }
            )
        }
    }

    var pomodoroFocusDuration: Double = 25 {
        didSet {
            pomodoroRemaining = AppStatePropertyEffectsService
                .updatedPomodoroRemainingAfterFocusDurationDidChange(
                    isFocusActive: pomodoroStatus == .focus,
                    focusDurationMinutes: pomodoroFocusDuration,
                    currentRemaining: pomodoroRemaining
                )
        }
    }
    var pomodoroBreakDuration: Double = 5 {
        didSet {
            pomodoroRemaining = AppStatePropertyEffectsService
                .updatedPomodoroRemainingAfterBreakDurationDidChange(
                    isBreakActive: pomodoroStatus == .breakTime,
                    breakDurationMinutes: pomodoroBreakDuration,
                    currentRemaining: pomodoroRemaining
                )
        }
    }

    var isPaused = false
    var pauseRemaining: TimeInterval = 0
    var pomodoroStatus: PomodoroStatus = .none
    var pomodoroRemaining: TimeInterval = 0
    var pomodoroStartedAt: Date?
    var currentOpenUrls: [String] = []

    var monitor: BrowserMonitor?
    let calendarProvider: any CalendarProvider
    private var calendarCancellable: AnyCancellable?
    let launchAtLoginService: LaunchAtLoginService
    let timerCoordinator: AppStateTimerCoordinator
    private var persistenceCancellables = Set<AnyCancellable>()
    private let scheduleCheckSubject = PassthroughSubject<Void, Never>()
    private let isTesting: Bool
    var internalState = AppStateInternalState()
    private var rescheduleScheduleTimer: (@MainActor () -> Void)?

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
            appState: self,
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
            isStrict: isStrict,
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
                guard let self else { return nil }
                return await MainActor.run {
                    self.reassertPersistedSessionFlags()
                    return BrowserMonitor.StateSnapshot(
                        isBlocking: self.isBlocking,
                        isPaused: self.isPaused,
                        blockNewTabs: self.blockNewTabs,
                        blockDeveloperHosts: self.blockDeveloperHosts,
                        blockLocalNetworkHosts: self.blockLocalNetworkHosts,
                        allowedRules: self.allowedRules
                    )
                }
            },
            onMonitorEvent: { [weak self] event in
                Task { @MainActor in
                    switch event {
                    case .trustedStateChanged(let trusted):
                        self?.isTrusted = trusted
                    }
                }
            },
            onScheduleUpdate: { [weak self] in Task { @MainActor in self?.checkSchedules() } },
            scheduleTickIntervalProvider: { [weak self] in
                MainActor.assumeIsolated {
                    self?.nextScheduleTickInterval() ?? 60
                }
            }
        )
        self.monitor = runtimeBindings.monitor
        calendarCancellable = runtimeBindings.calendarCancellable
        rescheduleScheduleTimer = runtimeBindings.rescheduleScheduleTimer
        if isBlocking && !wasStartedBySchedule && !manualBlockingEnabled {
            isBlocking = false
        }
        performCheckSchedules()
    }

    isolated deinit {
        AppStateLifecycleService.teardown(
            timerCoordinator: timerCoordinator
        )
    }

    func toggleBlocking() {
        let wasBlocking = isBlocking
        let updated = logicFacade.toggleSession(
            current: sessionState,
            isStrict: sessionDomainState.isStrict,
            schedules: scheduleDomainState.schedules
        )
        applySessionState(updated)
        if !wasBlocking && updated.isBlocking {
            Task {
                await monitor?.checkPermissions(prompt: false)
            }
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
            rescheduleScheduleTimer?()
            scheduleCheckSubject.send()
        }
    }

    /// In-memory session state is authoritative while the app runs. The persisted
    /// flags are externally writable (`defaults write com.benni.Free IsStrict -bool NO`),
    /// so tampering is repaired here — called on every monitor snapshot and schedule
    /// tick — rather than letting an external edit unlock strict mode or blocking.
    func reassertPersistedSessionFlags() {
        if settingsStore.isStrict() != isStrict {
            settingsStore.setIsStrict(isStrict)
        }
        if settingsStore.isBlocking() != isBlocking {
            settingsStore.setIsBlocking(isBlocking)
        }
    }

    private func performCheckSchedules() {
        synchronizeImportedCalendarSchedulesIfNeeded()
        reassertPersistedSessionFlags()
        let updated = logicFacade.checkSession(
            current: sessionState,
            schedules: scheduleDomainState.schedules,
            pomodoroStatus: pomodoroDomainState.status,
            calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
            isStrict: sessionDomainState.isStrict,
            calendarEvents: calendarProvider.events
        )
        applySessionState(updated)
    }

    private func nextScheduleTickInterval(now: Date = Date()) -> TimeInterval {
        AppStateScheduleTickCoordinator.nextInterval(
            schedules: scheduleDomainState.schedules,
            calendarEvents: calendarProvider.events,
            calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
            isStrict: sessionDomainState.isStrict,
            now: now
        )
    }

    func refreshCurrentOpenUrls() { 
        Task { @MainActor [weak self] in
            await self?.refreshCurrentOpenUrlsAsync()
        }
    }

    @MainActor
    func refreshCurrentOpenUrlsAsync() async {
        let urls = await self.monitor?.getAllOpenUrls()
        self.currentOpenUrls = urls ?? []
    }
}
