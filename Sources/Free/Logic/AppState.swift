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
    private let settingsStore: SettingsStore

    @Published var isBlocking = false {
        didSet {
            settingsStore.setIsBlocking(isBlocking)
            if !isBlocking { cancelPause() }
        }
    }
    @Published var isUnblockable = false {
        didSet { settingsStore.setIsUnblockable(isUnblockable) }
    }
    @Published var isTrusted = false
    @Published var weekStartsOnMonday = false {
        didSet { settingsStore.setWeekStartsOnMonday(weekStartsOnMonday) }
    }
    @Published var accentColorIndex = 0 {
        didSet { settingsStore.setAccentColorIndex(accentColorIndex) }
    }
    @Published var appearanceMode: AppearanceMode = .system {
        didSet { settingsStore.setAppearanceModeRawValue(appearanceMode.rawValue) }
    }
    @Published var calendarIntegrationEnabled = false {
        didSet {
            settingsStore.setCalendarIntegrationEnabled(calendarIntegrationEnabled)
            if calendarIntegrationEnabled { calendarProvider.requestAccess() }
            checkSchedules()
        }
    }
    @Published var calendarImportsBlockTime = false {
        didSet {
            settingsStore.setCalendarImportsBlockTime(calendarImportsBlockTime)
            checkSchedules()
        }
    }
    @Published var blockNewTabs = false {
        didSet { settingsStore.setBlockNewTabs(blockNewTabs) }
    }
    @Published var blockDeveloperHosts = false {
        didSet { settingsStore.setBlockDeveloperHosts(blockDeveloperHosts) }
    }
    @Published var blockLocalNetworkHosts = false {
        didSet { settingsStore.setBlockLocalNetworkHosts(blockLocalNetworkHosts) }
    }
    @Published var ruleSets: [RuleSet] = [] { didSet { settingsStore.saveRuleSets(ruleSets) } }
    @Published var activeRuleSetId: UUID? = nil {
        didSet { settingsStore.setActiveRuleSetId(activeRuleSetId) }
    }
    @Published var schedules: [Schedule] = [] {
        didSet {
            settingsStore.saveSchedules(schedules)
            checkSchedules()
        }
    }

    @Published var pomodoroFocusDuration: Double = 25 {
        didSet {
            settingsStore.setPomodoroFocusDuration(pomodoroFocusDuration)
            if pomodoroStatus == .focus { pomodoroRemaining = pomodoroFocusDuration * 60 }
        }
    }
    @Published var pomodoroBreakDuration: Double = 5 {
        didSet {
            settingsStore.setPomodoroBreakDuration(pomodoroBreakDuration)
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
    private let launchAtLoginService: LaunchAtLoginService
    private let timerCoordinator: AppStateTimerCoordinator
    private var wasStartedBySchedule = false
    private var manuallyPausedScheduleIds: Set<UUID> = []
    private var pomodoroRuleSetId: UUID?
    private var isSynchronizingImportedSchedules = false
    private var suppressedImportedCalendarEventKeys: Set<String> = []

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
        RuleSetService.currentPrimaryRuleSetId(
            ruleSets: ruleSets,
            schedules: schedules,
            activeRuleSetId: activeRuleSetId,
            pomodoroRuleSetId: pomodoroRuleSetId,
            isPomodoroFocus: pomodoroStatus == .focus,
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule
        )
    }

    var currentPrimaryRuleSetName: String {
        RuleSetService.currentPrimaryRuleSetName(
            ruleSets: ruleSets,
            schedules: schedules,
            currentPrimaryRuleSetId: currentPrimaryRuleSetId,
            isPomodoroFocus: pomodoroStatus == .focus,
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule
        )
    }

    var allowedRules: [String] {
        RuleSetService.allowedRules(
            ruleSets: ruleSets,
            schedules: schedules,
            activeRuleSetId: activeRuleSetId,
            pomodoroRuleSetId: pomodoroRuleSetId,
            isPomodoroFocus: pomodoroStatus == .focus,
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule
        )
    }

    var todaySchedules: [Schedule] {
        ScheduleEngine.todaySchedules(from: schedules)
    }

    init(
        defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil,
        calendar: (any CalendarProvider)? = nil,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        launchAtLoginManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager(),
        canPromptForLaunchAtLogin: @escaping () -> Bool = {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        },
        isTesting: Bool = false
    ) {
        self.settingsStore = SettingsStore(defaults: defaults)
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
        self.isBlocking = snapshot.isBlocking
        self.isUnblockable = snapshot.isUnblockable
        self.weekStartsOnMonday = snapshot.weekStartsOnMonday
        self.accentColorIndex = snapshot.accentColorIndex
        self.appearanceMode = snapshot.appearanceMode
        self.calendarIntegrationEnabled = snapshot.calendarIntegrationEnabled
        self.calendarImportsBlockTime = snapshot.calendarImportsBlockTime
        self.blockNewTabs = snapshot.blockNewTabs
        self.blockDeveloperHosts = snapshot.blockDeveloperHosts
        self.blockLocalNetworkHosts = snapshot.blockLocalNetworkHosts
        self.pomodoroFocusDuration = snapshot.pomodoroFocusDuration
        self.pomodoroBreakDuration = snapshot.pomodoroBreakDuration
        self.ruleSets = snapshot.ruleSets
        self.schedules = snapshot.schedules
        self.activeRuleSetId = snapshot.activeRuleSetId
        self.wasStartedBySchedule = snapshot.wasStartedBySchedule
        self.suppressedImportedCalendarEventKeys = snapshot.suppressedImportedCalendarEventKeys

        // Migration for older builds that persisted IsBlocking but not its source.
        if !settingsStore.hasPersistedWasStartedBySchedule(), isBlocking {
            let shouldBeBlockingNow = automaticBlockingState()
            if !shouldBeBlockingNow {
                isBlocking = false
            }
            setWasStartedBySchedule(shouldBeBlockingNow)
        }

        if let monitor = monitor {
            self.monitor = monitor
        } else if !isTesting {
            self.monitor = BrowserMonitor(appState: self)
        }

        calendarCancellable = calendarProvider.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.checkSchedules() }
        }

        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 60) { [weak self] in
            self?.checkSchedules()
        }
        replaceScheduleTimer(with: timer)
        checkSchedules()
    }

    deinit {
        timerCoordinator.invalidateAllTimers()
        calendarCancellable?.cancel()
    }

    func toggleBlocking() {
        let result = BlockingSessionService.toggleBlocking(
            isBlocking: isBlocking,
            isUnblockable: isUnblockable,
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            wasStartedBySchedule: wasStartedBySchedule
        )

        manuallyPausedScheduleIds = result.manuallyPausedScheduleIds
        if result.isBlocking != isBlocking {
            isBlocking = result.isBlocking
        }
        if result.wasStartedBySchedule != wasStartedBySchedule {
            setWasStartedBySchedule(result.wasStartedBySchedule)
        }
    }

    func checkSchedules() {
        synchronizeImportedCalendarSchedulesIfNeeded()
        let result = AppStateScheduleCheckCoordinator.evaluate(
            currentIsBlocking: isBlocking,
            currentWasStartedBySchedule: wasStartedBySchedule,
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarProvider.events
        )
        manuallyPausedScheduleIds = result.normalizedManuallyPausedScheduleIds
        if result.isBlocking != isBlocking {
            isBlocking = result.isBlocking
        }
        if result.wasStartedBySchedule != wasStartedBySchedule {
            setWasStartedBySchedule(result.wasStartedBySchedule)
        }
    }

    func addRule(_ rule: String, to setId: UUID) {
        ruleSets = AppStateRuleSetCoordinator.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .add
        )
    }
    func addSpecificRule(_ rule: String, to setId: UUID) {
        ruleSets = AppStateRuleSetCoordinator.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .addSpecific
        )
    }
    func removeRule(_ rule: String, from setId: UUID) {
        ruleSets = AppStateRuleSetCoordinator.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .remove
        )
    }
    func deleteSet(id: UUID) {
        let result = AppStateRuleSetCoordinator.deleteRuleSet(
            id: id,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
        ruleSets = result.ruleSets
        activeRuleSetId = result.activeRuleSetId
    }

    @discardableResult
    func createRuleSet(name: String, makeActive: Bool = false) -> RuleSet {
        let result = AppStateRuleSetCoordinator.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId
        )
        ruleSets = result.ruleSets
        activeRuleSetId = result.activeRuleSetId
        return result.created
    }

    func selectActiveRuleSet(_ id: UUID) {
        activeRuleSetId = AppStateRuleSetCoordinator.selectActiveRuleSet(
            id,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    func saveSchedule(
        name: String, days: Set<Int>, date: Date?, start: Date, end: Date, color: Int,
        type: ScheduleType, ruleSet: UUID?, existingId: UUID?, modifyAllDays: Bool, initialDay: Int?
    ) {
        schedules = AppStateScheduleMutationCoordinator.saveSchedule(
            currentSchedules: schedules,
            name: name,
            days: days,
            date: date,
            start: start,
            end: end,
            color: color,
            type: type,
            ruleSet: ruleSet,
            existingId: existingId,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
    }

    func updateScheduleOccurrence(
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) {
        schedules = AppStateScheduleMutationCoordinator.updateScheduleOccurrence(
            currentSchedules: schedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
    }

    func deleteSchedule(id: UUID, modifyAllDays: Bool, initialDay: Int?) {
        let result = AppStateScheduleMutationCoordinator.deleteSchedule(
            currentSchedules: schedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
        guard result.didMutateSchedules else { return }

        suppressedImportedCalendarEventKeys = result.suppressedImportedCalendarEventKeys
        if result.didPersistSuppressedImportedKeys {
            settingsStore.setSuppressedImportedCalendarEventKeys(suppressedImportedCalendarEventKeys)
        }
        schedules = result.schedules
    }

    func stopPomodoroWithChallenge(phrase: String) -> Bool {
        let result = AppStateChallengeCoordinator.stopPomodoro(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: isUnblockable
        )
        guard result.didSucceed else { return false }

        isUnblockable = result.temporaryIsUnblockable
        stopPomodoro()
        isUnblockable = result.restoredIsUnblockable
        return true
    }

    func disableUnblockableWithChallenge(phrase: String) -> Bool {
        let result = AppStateChallengeCoordinator.disableUnblockable(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: isUnblockable
        )
        guard result.didSucceed else { return false }
        isUnblockable = result.isUnblockable
        return result.didSucceed
    }

    func startPomodoro() {
        let updated = AppStatePomodoroCoordinator.startFocus(
            from: pomodoroEngineState,
            focusDurationMinutes: pomodoroFocusDuration,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
        applyPomodoroEngineState(updated)
        runTimer()
    }
    func stopPomodoro() {
        guard
            let stopped = AppStatePomodoroCoordinator.stopIfUnlocked(
                from: pomodoroEngineState,
                isLocked: isPomodoroLocked
            )
        else { return }
        applyPomodoroEngineState(stopped)
        replacePomodoroTimer(with: nil)
        checkSchedules()
    }
    func skipPomodoroPhase() {
        if pomodoroStatus == .focus {
            startBreak()
        } else if pomodoroStatus == .breakTime {
            startPomodoro()
        }
    }
    private func startBreak() {
        let updated = AppStatePomodoroCoordinator.startBreak(
            from: pomodoroEngineState,
            breakDurationMinutes: pomodoroBreakDuration
        )
        applyPomodoroEngineState(updated)
        runTimer()
    }

    func startPause(minutes: Double) {
        guard
            let updated = AppStatePauseCoordinator.start(
                from: pauseEngineState,
                minutes: minutes,
                isBlocking: isBlocking
            )
        else { return }
        applyPauseEngineState(updated)
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            let ticked = AppStatePauseCoordinator.tick(from: self.pauseEngineState)
            self.applyPauseEngineState(ticked)
            if !ticked.isPaused {
                self.cancelPause()
            }
        }
        replacePauseTimer(with: timer)
    }
    func cancelPause() {
        applyPauseEngineState(AppStatePauseCoordinator.cancel(from: pauseEngineState))
        replacePauseTimer(with: nil)
    }
    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }

    func resyncImportedCalendarSchedules(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let rebuilt = AppStateCalendarSyncCoordinator.rebuildForResync(
                calendarIntegrationEnabled: calendarIntegrationEnabled,
                currentSchedules: schedules,
                events: calendarProvider.events,
                calendarImportsBlockTime: calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
                activeRuleSetId: activeRuleSetId,
                ruleSets: ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        isSynchronizingImportedSchedules = true
        schedules = rebuilt
        isSynchronizingImportedSchedules = false
    }

    func prepareLaunchAtLoginPromptIfNeeded() -> Bool {
        AppStateLaunchAtLoginCoordinator.preparePromptIfNeeded(
            dependencies: .live(service: launchAtLoginService)
        )
    }

    func launchAtLoginStatus() -> Bool {
        AppStateLaunchAtLoginCoordinator.status(
            dependencies: .live(service: launchAtLoginService)
        )
    }

    @discardableResult
    func enableLaunchAtLogin() -> Bool {
        AppStateLaunchAtLoginCoordinator.enable(
            dependencies: .live(service: launchAtLoginService)
        )
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        AppStateLaunchAtLoginCoordinator.setEnabled(
            enabled,
            dependencies: .live(service: launchAtLoginService)
        )
    }

    func timeString(time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }

    private func runTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            switch AppStatePomodoroCoordinator.timerAction(
            status: self.pomodoroStatus,
            remaining: self.pomodoroRemaining
            ) {
            case .decrement:
                self.pomodoroRemaining -= 1
            case .startBreak:
                self.startBreak()
            case .startFocus:
                self.startPomodoro()
            }
        }
        replacePomodoroTimer(with: timer)
        checkSchedules()
    }
    private func replacePauseTimer(with newTimer: (any RepeatingTimer)?) {
        timerCoordinator.replacePauseTimer(with: newTimer)
    }

    private func replacePomodoroTimer(with newTimer: (any RepeatingTimer)?) {
        timerCoordinator.replacePomodoroTimer(with: newTimer)
    }

    private func replaceScheduleTimer(with newTimer: (any RepeatingTimer)?) {
        timerCoordinator.replaceScheduleTimer(with: newTimer)
    }

    private func automaticBlockingState() -> Bool {
        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarProvider.events
        )
        manuallyPausedScheduleIds = result.normalizedManuallyPausedScheduleIds
        return result.shouldBlock
    }

    private func synchronizeImportedCalendarSchedulesIfNeeded(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let merged = AppStateCalendarSyncCoordinator.rebuildForScheduleCheck(
                isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
                currentSchedules: schedules,
                events: calendarProvider.events,
                calendarIntegrationEnabled: calendarIntegrationEnabled,
                calendarImportsBlockTime: calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
                activeRuleSetId: activeRuleSetId,
                ruleSets: ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        isSynchronizingImportedSchedules = true
        schedules = merged
        isSynchronizingImportedSchedules = false
    }

    private func setWasStartedBySchedule(_ value: Bool) {
        wasStartedBySchedule = value
        settingsStore.setWasStartedBySchedule(value)
    }

    private var pauseEngineState: PauseEngine.State {
        PauseEngine.State(isPaused: isPaused, remaining: pauseRemaining)
    }

    private func applyPauseEngineState(_ state: PauseEngine.State) {
        isPaused = state.isPaused
        pauseRemaining = state.remaining
    }

    private var pomodoroEngineState: PomodoroEngine.State {
        PomodoroEngine.State(
            status: pomodoroStatus,
            remaining: pomodoroRemaining,
            startedAt: pomodoroStartedAt,
            ruleSetId: pomodoroRuleSetId
        )
    }

    private func applyPomodoroEngineState(_ state: PomodoroEngine.State) {
        pomodoroStatus = state.status
        pomodoroRemaining = state.remaining
        pomodoroStartedAt = state.startedAt
        pomodoroRuleSetId = state.ruleSetId
    }

    private func invalidateAllTimers() {
        timerCoordinator.invalidateAllTimers()
    }
}
