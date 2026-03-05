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
    private let timerScheduler: any RepeatingTimerScheduling
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let canPromptForLaunchAtLogin: () -> Bool
    private let timerLock = NSLock()
    private var pauseTimer: (any RepeatingTimer)?
    private var pomodoroTimer: (any RepeatingTimer)?
    private var scheduleTimer: (any RepeatingTimer)?
    private var wasStartedBySchedule = false
    private var manuallyPausedScheduleIds: Set<UUID> = []
    private var pomodoroRuleSetId: UUID?
    private var isSynchronizingImportedSchedules = false
    private var suppressedImportedCalendarEventKeys: Set<String> = []

    struct CalendarEventSignature: Hashable {
        let title: String
        let start: TimeInterval
        let end: TimeInterval
    }

    enum PomodoroStatus: String, Codable { case none, focus, breakTime }

    var isPomodoroLocked: Bool {
        guard isUnblockable, pomodoroStatus != .none, let startedAt = pomodoroStartedAt else {
            return false
        }
        return Date().timeIntervalSince(startedAt) > 10
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
        self.timerScheduler = timerScheduler
        self.launchAtLoginManager = launchAtLoginManager
        self.canPromptForLaunchAtLogin = canPromptForLaunchAtLogin

        self.isBlocking = settingsStore.isBlocking()
        self.isUnblockable = settingsStore.isUnblockable()
        self.weekStartsOnMonday = settingsStore.weekStartsOnMonday()
        self.accentColorIndex = settingsStore.accentColorIndex()
        self.calendarIntegrationEnabled = settingsStore.calendarIntegrationEnabled()
        self.calendarImportsBlockTime = settingsStore.calendarImportsBlockTime()
        self.blockNewTabs = settingsStore.blockNewTabs()
        self.blockDeveloperHosts = settingsStore.blockDeveloperHosts()
        self.blockLocalNetworkHosts = settingsStore.blockLocalNetworkHosts()
        self.pomodoroFocusDuration = settingsStore.pomodoroFocusDuration(default: 25)
        self.pomodoroBreakDuration = settingsStore.pomodoroBreakDuration(default: 5)

        if let modeStr = settingsStore.appearanceModeRawValue() {
            self.appearanceMode = AppearanceMode(rawValue: modeStr) ?? .system
        }
        self.ruleSets = settingsStore.loadRuleSets() ?? [RuleSet.defaultSet()]
        self.schedules = settingsStore.loadSchedules() ?? []
        self.activeRuleSetId = settingsStore.activeRuleSetId() ?? ruleSets.first?.id
        self.wasStartedBySchedule = settingsStore.wasStartedBySchedule()
        self.suppressedImportedCalendarEventKeys = settingsStore.suppressedImportedCalendarEventKeys()

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

        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 60) { [weak self] in
            self?.checkSchedules()
        }
        replaceScheduleTimer(with: timer)
        checkSchedules()
    }

    deinit {
        invalidateAllTimers()
        calendarCancellable?.cancel()
    }

    func toggleBlocking() {
        if !(isBlocking && isUnblockable) {
            if isBlocking {
                let activeFocusIds = schedules.filter { $0.isActive() && $0.type == .focus }.map {
                    $0.id
                }
                manuallyPausedScheduleIds.formUnion(activeFocusIds)
            } else {
                manuallyPausedScheduleIds.removeAll()
            }
            isBlocking.toggle()
            setWasStartedBySchedule(false)
        }
    }

    func checkSchedules() {
        synchronizeImportedCalendarSchedulesIfNeeded()
        let shouldBeBlocking = automaticBlockingState()

        if shouldBeBlocking && !isBlocking {
            isBlocking = true
            setWasStartedBySchedule(true)
        } else if !shouldBeBlocking && isBlocking && wasStartedBySchedule {
            isBlocking = false
            setWasStartedBySchedule(false)
        }
    }

    func addRule(_ rule: String, to setId: UUID) {
        if isStrictActive { return }
        RuleSetService.addRule(rule, to: setId, in: &ruleSets)
    }
    func addSpecificRule(_ rule: String, to setId: UUID) {
        if isStrictActive { return }
        RuleSetService.addSpecificRule(rule, to: setId, in: &ruleSets)
    }
    func removeRule(_ rule: String, from setId: UUID) {
        if isStrictActive { return }
        RuleSetService.removeRule(rule, from: setId, in: &ruleSets)
    }
    func deleteSet(id: UUID) {
        if isStrictActive { return }
        RuleSetService.deleteSet(id: id, in: &ruleSets, activeRuleSetId: &activeRuleSetId)
    }

    func saveSchedule(
        name: String, days: Set<Int>, date: Date?, start: Date, end: Date, color: Int,
        type: ScheduleType, ruleSet: UUID?, existingId: UUID?, modifyAllDays: Bool, initialDay: Int?
    ) {
        ScheduleEngine.saveSchedule(
            in: &schedules,
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
        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
    }

    func deleteSchedule(id: UUID, modifyAllDays: Bool, initialDay: Int?) {
        if let deletedSchedule = ScheduleEngine.deleteSchedule(
            in: &schedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        ) {
            suppressImportedCalendarEventIfNeeded(deletedSchedule)
        }
    }

    func stopPomodoroWithChallenge(phrase: String) -> Bool {
        guard phrase == AppState.challengePhrase else { return false }
        let wasUnblockable = isUnblockable
        isUnblockable = false
        stopPomodoro()
        isUnblockable = wasUnblockable
        return true
    }

    func disableUnblockableWithChallenge(phrase: String) -> Bool {
        guard phrase == AppState.challengePhrase else { return false }
        isUnblockable = false
        return true
    }

    func startPomodoro() {
        if pomodoroStatus == .none {
            pomodoroRuleSetId = RuleSetService.normalizeRuleSetId(activeRuleSetId, in: ruleSets)
        }
        pomodoroRuleSetId = RuleSetService.normalizeRuleSetId(
            pomodoroRuleSetId ?? activeRuleSetId,
            in: ruleSets
        )
        pomodoroStatus = .focus
        pomodoroRemaining = pomodoroFocusDuration * 60
        pomodoroStartedAt = Date()
        runTimer()
    }
    func stopPomodoro() {
        if !isPomodoroLocked {
            pomodoroStatus = .none
            pomodoroRuleSetId = nil
            replacePomodoroTimer(with: nil)
            checkSchedules()
        }
    }
    func skipPomodoroPhase() {
        if pomodoroStatus == .focus {
            startBreak()
        } else if pomodoroStatus == .breakTime {
            startPomodoro()
        }
    }
    private func startBreak() {
        pomodoroStatus = .breakTime
        pomodoroRemaining = pomodoroBreakDuration * 60
        runTimer()
    }

    func startPause(minutes: Double) {
        guard isBlocking, minutes > 0 else { return }
        isPaused = true
        pauseRemaining = minutes * 60
        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            if self.pauseRemaining > 0 { self.pauseRemaining -= 1 } else { self.cancelPause() }
        }
        replacePauseTimer(with: timer)
    }
    func cancelPause() {
        isPaused = false
        replacePauseTimer(with: nil)
    }
    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }

    func resyncImportedCalendarSchedules() {
        guard calendarIntegrationEnabled else { return }

        let preservedImportedByKey: [String: Schedule] = Dictionary(
            uniqueKeysWithValues: schedules.compactMap { schedule in
                guard let key = schedule.importedCalendarEventKey else { return nil }
                return (key, schedule)
            }
        )

        let signatures = Set(
            calendarProvider.events.map {
                CalendarEventSignature(
                    title: $0.title,
                    start: $0.startDate.timeIntervalSince1970,
                    end: $0.endDate.timeIntervalSince1970
                )
            }
        )

        let cleaned = schedules.filter { schedule in
            if schedule.importedCalendarEventKey != nil { return false }
            if isLegacyImportedCalendarDuplicate(schedule, signatures: signatures) {
                return false
            }
            return true
        }

        let rebuilt = mergedSchedulesWithImportedCalendarEvents(
            baseSchedules: cleaned,
            preservedImportedByKey: preservedImportedByKey
        )
        guard rebuilt != schedules else { return }

        isSynchronizingImportedSchedules = true
        schedules = rebuilt
        isSynchronizingImportedSchedules = false
    }

    func prepareLaunchAtLoginPromptIfNeeded() -> Bool {
        guard canPromptForLaunchAtLogin() else { return false }
        if settingsStore.launchAtLoginPromptShown() {
            return false
        }
        settingsStore.setLaunchAtLoginPromptShown(true)
        return !launchAtLoginManager.isEnabled
    }

    func launchAtLoginStatus() -> Bool {
        launchAtLoginManager.isEnabled
    }

    @discardableResult
    func enableLaunchAtLogin() -> Bool {
        do {
            try launchAtLoginManager.enable()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return enableLaunchAtLogin()
        }

        do {
            try launchAtLoginManager.disable()
            return true
        } catch {
            return false
        }
    }

    func timeString(time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }

    private func runTimer() {
        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                if self.pomodoroStatus == .focus { self.startBreak() } else { self.startPomodoro() }
            }
        }
        replacePomodoroTimer(with: timer)
        checkSchedules()
    }
    private func mergedSchedulesWithImportedCalendarEvents(
        baseSchedules: [Schedule],
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule] {
        let shouldImportCalendarEvents = calendarIntegrationEnabled && calendarImportsBlockTime
        guard shouldImportCalendarEvents else { return baseSchedules }

        let existingImported = schedules.filter { $0.importedCalendarEventKey != nil }
        let existingByKey: [String: Schedule] = Dictionary(
            uniqueKeysWithValues: existingImported.compactMap { schedule in
                guard let key = schedule.importedCalendarEventKey else { return nil }
                return (key, schedule)
            }
        )
        let defaultImportedRuleSetId = RuleSetService.normalizeRuleSetId(activeRuleSetId, in: ruleSets)

        let importedSchedules = calendarProvider.events
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event -> Schedule? in
                guard !suppressedImportedCalendarEventKeys.contains(event.id) else { return nil }
                let existing = existingByKey[event.id] ?? preservedImportedByKey[event.id]
                return Schedule(
                    id: existing?.id ?? UUID(),
                    name: event.title,
                    days: [],
                    date: event.startDate,
                    startTime: event.startDate,
                    endTime: event.endDate,
                    isEnabled: existing?.isEnabled ?? true,
                    colorIndex: existing?.colorIndex ?? 0,
                    type: existing?.type ?? .focus,
                    ruleSetId: existing?.ruleSetId ?? defaultImportedRuleSetId,
                    importedCalendarEventKey: event.id
                )
            }

        return baseSchedules + importedSchedules
    }

    private func replacePauseTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(keyPath: \.pauseTimer, with: newTimer)
    }

    private func replacePomodoroTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(keyPath: \.pomodoroTimer, with: newTimer)
    }

    private func replaceScheduleTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(keyPath: \.scheduleTimer, with: newTimer)
    }

    private func automaticBlockingState() -> Bool {
        let result = ScheduleEngine.automaticBlockingState(
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroIsFocus: pomodoroStatus == .focus,
            pomodoroIsBreak: pomodoroStatus == .breakTime,
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
        guard !isSynchronizingImportedSchedules else { return }
        let merged = mergedSchedulesWithImportedCalendarEvents(
            baseSchedules: schedules.filter { $0.importedCalendarEventKey == nil },
            preservedImportedByKey: preservedImportedByKey
        )
        guard merged != schedules else { return }

        isSynchronizingImportedSchedules = true
        schedules = merged
        isSynchronizingImportedSchedules = false
    }

    private func isLegacyImportedCalendarDuplicate(
        _ schedule: Schedule,
        signatures: Set<CalendarEventSignature>
    ) -> Bool {
        guard schedule.type == .focus, schedule.date != nil else { return false }
        let signature = CalendarEventSignature(
            title: schedule.name,
            start: schedule.startTime.timeIntervalSince1970,
            end: schedule.endTime.timeIntervalSince1970
        )
        return signatures.contains(signature)
    }

    private func suppressImportedCalendarEventIfNeeded(_ schedule: Schedule) {
        guard let key = schedule.importedCalendarEventKey else { return }
        if suppressedImportedCalendarEventKeys.insert(key).inserted {
            settingsStore.setSuppressedImportedCalendarEventKeys(suppressedImportedCalendarEventKeys)
        }
    }

    private func setWasStartedBySchedule(_ value: Bool) {
        wasStartedBySchedule = value
        settingsStore.setWasStartedBySchedule(value)
    }

    private func invalidateAllTimers() {
        replacePauseTimer(with: nil)
        replacePomodoroTimer(with: nil)
        replaceScheduleTimer(with: nil)
    }

    private func replaceTimer(
        keyPath: ReferenceWritableKeyPath<AppState, (any RepeatingTimer)?>,
        with newTimer: (any RepeatingTimer)?
    ) {
        timerLock.lock()
        let oldTimer = self[keyPath: keyPath]
        self[keyPath: keyPath] = newTimer
        timerLock.unlock()
        oldTimer?.invalidate()
    }
}
