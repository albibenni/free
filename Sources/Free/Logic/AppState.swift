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
    private let logicFacade: AppStateLogicFacade

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
    private let launchAtLoginService: LaunchAtLoginService
    private let timerCoordinator: AppStateTimerCoordinator
    private var persistenceCancellables = Set<AnyCancellable>()
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

    func addRule(_ rule: String, to setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .add
        )
    }
    func addSpecificRule(_ rule: String, to setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .addSpecific
        )
    }
    func removeRule(_ rule: String, from setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .remove
        )
    }
    func deleteSet(id: UUID) {
        let result = logicFacade.deleteRuleSet(
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
        let result = logicFacade.createRuleSet(
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
        activeRuleSetId = logicFacade.selectActiveRuleSet(
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
        schedules = logicFacade.saveSchedule(
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
        schedules = logicFacade.updateScheduleOccurrence(
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
        let result = logicFacade.deleteSchedule(
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
        let result = logicFacade.stopPomodoroChallenge(
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
        let result = logicFacade.disableUnblockableChallenge(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: isUnblockable
        )
        guard result.didSucceed else { return false }
        isUnblockable = result.isUnblockable
        return result.didSucceed
    }

    func startPomodoro() {
        let transition = logicFacade.startPomodoro(
            state: pomodoroEngineState,
            focusDurationMinutes: pomodoroFocusDuration,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
        applyPomodoroEngineState(transition.state)
        if transition.shouldRunTimer {
            runTimer()
        }
    }
    func stopPomodoro() {
        guard
            let transition = logicFacade.stopPomodoroIfUnlocked(
                state: pomodoroEngineState,
                isLocked: isPomodoroLocked
            )
        else { return }
        applyPomodoroEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePomodoroTimer(with: nil)
        }
        if transition.shouldCheckSchedules {
            checkSchedules()
        }
    }
    func skipPomodoroPhase() {
        switch logicFacade.skipPhaseAction(for: pomodoroStatus) {
        case .startBreak:
            startBreak()
        case .startFocus:
            startPomodoro()
        case .none:
            break
        }
    }
    private func startBreak() {
        let transition = logicFacade.startBreak(
            state: pomodoroEngineState,
            breakDurationMinutes: pomodoroBreakDuration
        )
        applyPomodoroEngineState(transition.state)
        if transition.shouldRunTimer {
            runTimer()
        }
    }

    func startPause(minutes: Double) {
        guard
            let transition = logicFacade.startPause(
                state: sessionDomainState.pauseEngineState,
                minutes: minutes,
                isBlocking: sessionDomainState.isBlocking
            )
        else { return }
        applyPauseEngineState(transition.state)
        if transition.shouldStartTimer {
            let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
                guard let self = self else { return }
                let result = self.logicFacade.pauseTick(state: self.sessionDomainState.pauseEngineState)
                self.applyPauseEngineState(result.state)
                if result.shouldCancelPause {
                    self.cancelPause()
                }
            }
            timerCoordinator.replacePauseTimer(with: timer)
        }
    }
    func cancelPause() {
        let transition = logicFacade.cancelPause(state: sessionDomainState.pauseEngineState)
        applyPauseEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePauseTimer(with: nil)
        }
    }
    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }

    func resyncImportedCalendarSchedules(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let rebuilt = logicFacade.rebuildForResync(
                calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
                currentSchedules: scheduleDomainState.schedules,
                events: calendarProvider.events,
                calendarImportsBlockTime: scheduleDomainState.calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        var state = scheduleDomainState
        state.isSynchronizingImportedSchedules = true
        state.schedules = rebuilt
        state.isSynchronizingImportedSchedules = false
        applyScheduleDomainState(state)
    }

    func prepareLaunchAtLoginPromptIfNeeded() -> Bool {
        logicFacade.prepareLaunchAtLoginPromptIfNeeded(service: launchAtLoginService)
    }

    func launchAtLoginStatus() -> Bool {
        logicFacade.launchAtLoginStatus(service: launchAtLoginService)
    }

    @discardableResult
    func enableLaunchAtLogin() -> Bool {
        logicFacade.enableLaunchAtLogin(service: launchAtLoginService)
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        logicFacade.setLaunchAtLoginEnabled(enabled, service: launchAtLoginService)
    }

    func timeString(time: TimeInterval) -> String {
        logicFacade.timeString(time: time)
    }

    private func runTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            switch self.logicFacade.pomodoroTickAction(
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
        timerCoordinator.replacePomodoroTimer(with: timer)
        checkSchedules()
    }

    private func synchronizeImportedCalendarSchedulesIfNeeded(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let merged = logicFacade.rebuildForScheduleCheck(
                isSynchronizingImportedSchedules: scheduleDomainState.isSynchronizingImportedSchedules,
                currentSchedules: scheduleDomainState.schedules,
                events: calendarProvider.events,
                calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
                calendarImportsBlockTime: scheduleDomainState.calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        var state = scheduleDomainState
        state.isSynchronizingImportedSchedules = true
        state.schedules = merged
        state.isSynchronizingImportedSchedules = false
        applyScheduleDomainState(state)
    }

    private func setWasStartedBySchedule(_ value: Bool) {
        wasStartedBySchedule = value
        settingsStore.setWasStartedBySchedule(value)
    }

    private var sessionState: AppStateLogicFacade.SessionState {
        logicFacade.makeSessionState(
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule,
            manuallyPausedScheduleIds: sessionDomainState.manuallyPausedScheduleIds
        )
    }

    private func applySessionState(_ state: AppStateLogicFacade.SessionState) {
        manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        if state.isBlocking != isBlocking {
            isBlocking = state.isBlocking
        }
        if state.wasStartedBySchedule != wasStartedBySchedule {
            setWasStartedBySchedule(state.wasStartedBySchedule)
        }
    }

    private func applyPauseEngineState(_ state: PauseEngine.State) {
        var domainState = sessionDomainState
        domainState.isPaused = state.isPaused
        domainState.pauseRemaining = state.remaining
        applySessionDomainState(domainState)
    }

    private var pomodoroEngineState: PomodoroEngine.State {
        pomodoroDomainState.pomodoroEngineState
    }

    private var ruleContext: AppStateLogicFacade.RuleContext {
        logicFacade.makeRuleContext(
            ruleSets: rulesDomainState.ruleSets,
            schedules: scheduleDomainState.schedules,
            activeRuleSetId: rulesDomainState.activeRuleSetId,
            pomodoroRuleSetId: pomodoroDomainState.ruleSetId,
            isPomodoroFocus: pomodoroDomainState.status == .focus,
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule
        )
    }

    private func applyPomodoroEngineState(_ state: PomodoroEngine.State) {
        var domainState = pomodoroDomainState
        domainState.status = state.status
        domainState.remaining = state.remaining
        domainState.startedAt = state.startedAt
        domainState.ruleSetId = state.ruleSetId
        applyPomodoroDomainState(domainState)
    }

    private var sessionDomainState: AppSessionDomainState {
        AppSessionDomainState(
            isBlocking: isBlocking,
            isUnblockable: isUnblockable,
            isPaused: isPaused,
            pauseRemaining: pauseRemaining,
            wasStartedBySchedule: wasStartedBySchedule,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds
        )
    }

    private func applySessionDomainState(_ state: AppSessionDomainState) {
        if isBlocking != state.isBlocking { isBlocking = state.isBlocking }
        if isUnblockable != state.isUnblockable { isUnblockable = state.isUnblockable }
        if isPaused != state.isPaused { isPaused = state.isPaused }
        if pauseRemaining != state.pauseRemaining { pauseRemaining = state.pauseRemaining }
        if wasStartedBySchedule != state.wasStartedBySchedule {
            wasStartedBySchedule = state.wasStartedBySchedule
        }
        if manuallyPausedScheduleIds != state.manuallyPausedScheduleIds {
            manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        }
    }

    private var settingsDomainState: AppSettingsDomainState {
        AppSettingsDomainState(
            weekStartsOnMonday: weekStartsOnMonday,
            accentColorIndex: accentColorIndex,
            appearanceMode: appearanceMode,
            blockNewTabs: blockNewTabs,
            blockDeveloperHosts: blockDeveloperHosts,
            blockLocalNetworkHosts: blockLocalNetworkHosts
        )
    }

    private func applySettingsDomainState(_ state: AppSettingsDomainState) {
        if weekStartsOnMonday != state.weekStartsOnMonday {
            weekStartsOnMonday = state.weekStartsOnMonday
        }
        if accentColorIndex != state.accentColorIndex { accentColorIndex = state.accentColorIndex }
        if appearanceMode != state.appearanceMode { appearanceMode = state.appearanceMode }
        if blockNewTabs != state.blockNewTabs { blockNewTabs = state.blockNewTabs }
        if blockDeveloperHosts != state.blockDeveloperHosts {
            blockDeveloperHosts = state.blockDeveloperHosts
        }
        if blockLocalNetworkHosts != state.blockLocalNetworkHosts {
            blockLocalNetworkHosts = state.blockLocalNetworkHosts
        }
    }

    private var rulesDomainState: AppRulesDomainState {
        AppRulesDomainState(ruleSets: ruleSets, activeRuleSetId: activeRuleSetId)
    }

    private func applyRulesDomainState(_ state: AppRulesDomainState) {
        if ruleSets != state.ruleSets { ruleSets = state.ruleSets }
        if activeRuleSetId != state.activeRuleSetId { activeRuleSetId = state.activeRuleSetId }
    }

    private var scheduleDomainState: AppScheduleDomainState {
        AppScheduleDomainState(
            schedules: schedules,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            calendarImportsBlockTime: calendarImportsBlockTime,
            isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    private func applyScheduleDomainState(_ state: AppScheduleDomainState) {
        if schedules != state.schedules { schedules = state.schedules }
        if calendarIntegrationEnabled != state.calendarIntegrationEnabled {
            calendarIntegrationEnabled = state.calendarIntegrationEnabled
        }
        if calendarImportsBlockTime != state.calendarImportsBlockTime {
            calendarImportsBlockTime = state.calendarImportsBlockTime
        }
        if isSynchronizingImportedSchedules != state.isSynchronizingImportedSchedules {
            isSynchronizingImportedSchedules = state.isSynchronizingImportedSchedules
        }
        if suppressedImportedCalendarEventKeys != state.suppressedImportedCalendarEventKeys {
            suppressedImportedCalendarEventKeys = state.suppressedImportedCalendarEventKeys
        }
    }

    private var pomodoroDomainState: AppPomodoroDomainState {
        AppPomodoroDomainState(
            status: pomodoroStatus,
            remaining: pomodoroRemaining,
            startedAt: pomodoroStartedAt,
            focusDurationMinutes: pomodoroFocusDuration,
            breakDurationMinutes: pomodoroBreakDuration,
            ruleSetId: pomodoroRuleSetId
        )
    }

    private func applyPomodoroDomainState(_ state: AppPomodoroDomainState) {
        if pomodoroStatus != state.status { pomodoroStatus = state.status }
        if pomodoroRemaining != state.remaining { pomodoroRemaining = state.remaining }
        if pomodoroStartedAt != state.startedAt { pomodoroStartedAt = state.startedAt }
        if pomodoroFocusDuration != state.focusDurationMinutes {
            pomodoroFocusDuration = state.focusDurationMinutes
        }
        if pomodoroBreakDuration != state.breakDurationMinutes {
            pomodoroBreakDuration = state.breakDurationMinutes
        }
        if pomodoroRuleSetId != state.ruleSetId { pomodoroRuleSetId = state.ruleSetId }
    }

}
