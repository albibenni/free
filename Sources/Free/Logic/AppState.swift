import SwiftUI
import Combine

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System", light = "Light", dark = "Dark"
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class AppState: ObservableObject {
    static let challengePhrase = "I am choosing to break my focus and I acknowledge that this may impact my productivity."
    private let defaults: UserDefaults

    // MARK: - Persisted Properties
    @Published var isBlocking = false {
        didSet { defaults.set(isBlocking, forKey: "IsBlocking") ; if !isBlocking { cancelPause() } }
    }
    @Published var isUnblockable = false { didSet { defaults.set(isUnblockable, forKey: "IsUnblockable") } }
    @Published var isTrusted = false
    @Published var weekStartsOnMonday = false { didSet { defaults.set(weekStartsOnMonday, forKey: "WeekStartsOnMonday") } }
    @Published var accentColorIndex = 0 { didSet { defaults.set(accentColorIndex, forKey: "AccentColorIndex") } }
    @Published var appearanceMode: AppearanceMode = .system { didSet { defaults.set(appearanceMode.rawValue, forKey: "AppearanceMode") } }
    @Published var calendarIntegrationEnabled = false {
        didSet {
            defaults.set(calendarIntegrationEnabled, forKey: "CalendarIntegrationEnabled")
            if calendarIntegrationEnabled { calendarProvider.requestAccess() }
            checkSchedules()
        }
    }
    @Published var ruleSets: [RuleSet] = [] { didSet { saveJSON(ruleSets, key: "RuleSets") } }
    @Published var activeRuleSetId: UUID? = nil { didSet { defaults.set(activeRuleSetId?.uuidString, forKey: "ActiveRuleSetId") } }
    @Published var schedules: [Schedule] = [] { didSet { saveJSON(schedules, key: "Schedules") ; checkSchedules() } }
    
    @Published var pomodoroFocusDuration: Double = 25 { 
        didSet { 
            defaults.set(pomodoroFocusDuration, forKey: "PomodoroFocusDuration")
            if pomodoroStatus == .focus { pomodoroRemaining = pomodoroFocusDuration * 60 }
        } 
    }
    @Published var pomodoroBreakDuration: Double = 5 { 
        didSet { 
            defaults.set(pomodoroBreakDuration, forKey: "PomodoroBreakDuration")
            if pomodoroStatus == .breakTime { pomodoroRemaining = pomodoroBreakDuration * 60 }
        } 
    }

    // MARK: - Volatile State
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
    private let timerLock = NSLock()
    private var pauseTimer: (any RepeatingTimer)?
    private var pomodoroTimer: (any RepeatingTimer)?
    private var scheduleTimer: (any RepeatingTimer)?
    private var wasStartedBySchedule = false
    private var manuallyPausedScheduleIds: Set<UUID> = []

    enum PomodoroStatus: String, Codable { case none, focus, breakTime }

    // MARK: - Computed Properties
    var isPomodoroLocked: Bool {
        guard isUnblockable, pomodoroStatus != .none, let startedAt = pomodoroStartedAt else { return false }
        return Date().timeIntervalSince(startedAt) > 10
    }
    var isStrictActive: Bool { isBlocking && isUnblockable }

    var currentPrimaryRuleSetId: UUID? {
        if (isBlocking && !wasStartedBySchedule) || pomodoroStatus == .focus { return activeRuleSetId ?? ruleSets.first?.id }
        return schedules.first { $0.isActive() && $0.type == .focus }?.ruleSetId ?? activeRuleSetId ?? ruleSets.first?.id
    }

    var currentPrimaryRuleSetName: String {
        guard let id = currentPrimaryRuleSetId else { return "No List" }
        return ruleSets.first { $0.id == id }?.name ?? "Unknown List"
    }

    var allowedRules: [String] {
        var urls = Set<String>()
        schedules.filter { $0.isActive() && $0.type == .focus }.forEach { s in
            if let id = s.ruleSetId, let set = ruleSets.first(where: { $0.id == id }) { urls.formUnion(set.urls) }
        }
        if (isBlocking && !wasStartedBySchedule) || pomodoroStatus == .focus {
            if let set = ruleSets.first(where: { $0.id == activeRuleSetId ?? ruleSets.first?.id }) { urls.formUnion(set.urls) }
        }
        if urls.isEmpty && isBlocking, let firstSet = ruleSets.first { urls.formUnion(firstSet.urls) }
        return Array(urls)
    }

    var todaySchedules: [Schedule] {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        
        return schedules.filter { s in
            if let specificDate = s.date {
                return calendar.isDate(specificDate, inSameDayAs: now)
            }
            return s.days.contains(weekday)
        }
        .sorted { s1, s2 in
                let c1 = Calendar.current.dateComponents([.hour, .minute], from: s1.startTime)
                let c2 = Calendar.current.dateComponents([.hour, .minute], from: s2.startTime)
                return (c1.hour ?? 0) * 60 + (c1.minute ?? 0) < (c2.hour ?? 0) * 60 + (c2.minute ?? 0)
            }
    }

    // MARK: - Initialization
    init(defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil, calendar: (any CalendarProvider)? = nil, timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(), isTesting: Bool = false) {
        self.defaults = defaults
        self.calendarProvider = calendar ?? (isTesting ? MockCalendarManager() : RealCalendarManager())
        self.timerScheduler = timerScheduler
        
        self.isBlocking = defaults.bool(forKey: "IsBlocking")
        self.isUnblockable = defaults.bool(forKey: "IsUnblockable")
        self.weekStartsOnMonday = defaults.bool(forKey: "WeekStartsOnMonday")
        self.accentColorIndex = defaults.integer(forKey: "AccentColorIndex")
        self.calendarIntegrationEnabled = defaults.bool(forKey: "CalendarIntegrationEnabled")
        self.pomodoroFocusDuration = defaults.double(forKey: "PomodoroFocusDuration") == 0 ? 25 : defaults.double(forKey: "PomodoroFocusDuration")
        self.pomodoroBreakDuration = defaults.double(forKey: "PomodoroBreakDuration") == 0 ? 5 : defaults.double(forKey: "PomodoroBreakDuration")
        
        if let modeStr = defaults.string(forKey: "AppearanceMode") { self.appearanceMode = AppearanceMode(rawValue: modeStr) ?? .system }
        self.ruleSets = loadJSON(key: "RuleSets", as: [RuleSet].self) ?? [RuleSet.defaultSet()]
        self.schedules = loadJSON(key: "Schedules", as: [Schedule].self) ?? []
        self.activeRuleSetId = UUID(uuidString: defaults.string(forKey: "ActiveRuleSetId") ?? "") ?? ruleSets.first?.id
        
        if let monitor = monitor { self.monitor = monitor }
        else if !isTesting { self.monitor = BrowserMonitor(appState: self) }
        
        calendarCancellable = calendarProvider.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.checkSchedules() }
        }
        
        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 60) { [weak self] in self?.checkSchedules() }
        replaceScheduleTimer(with: timer)
        checkSchedules()
    }

    deinit {
        invalidateAllTimers()
        calendarCancellable?.cancel()
    }

    // MARK: - Logic & Actions
    func toggleBlocking() {
        if !(isBlocking && isUnblockable) {
            if isBlocking {
                // Manually turning OFF: record all current focus schedules so they don't immediately restart
                let activeFocusIds = schedules.filter { $0.isActive() && $0.type == .focus }.map { $0.id }
                manuallyPausedScheduleIds.formUnion(activeFocusIds)
            } else {
                // Manually turning ON: clear previous manual pauses
                manuallyPausedScheduleIds.removeAll()
            }
            isBlocking.toggle()
            wasStartedBySchedule = false
        }
    }

    func checkSchedules() {
        let active = schedules.filter { $0.isActive() }
        let focusSchedules = active.filter { $0.type == .focus }
        
        // 1. Prune the paused set: remove IDs of schedules that are no longer active
        let activeFocusIds = Set(focusSchedules.map { $0.id })
        manuallyPausedScheduleIds.formIntersection(activeFocusIds)

        // 2. We should block if there is a focus session that is NOT manually paused
        let hasFocus = (focusSchedules.contains { !manuallyPausedScheduleIds.contains($0.id) }) || pomodoroStatus == .focus
        let hasBreak = active.contains { $0.type == .unfocus } || pomodoroStatus == .breakTime
        let hasMeeting = calendarIntegrationEnabled && !isUnblockable && calendarProvider.events.contains { $0.isActive() }
        
        let shouldBeBlocking = hasFocus && !hasBreak && !hasMeeting

        if shouldBeBlocking && !isBlocking {
            isBlocking = true
            wasStartedBySchedule = true
        } else if !shouldBeBlocking && isBlocking && wasStartedBySchedule {
            isBlocking = false
            wasStartedBySchedule = false
        }
    }

    func addRule(_ rule: String, to setId: UUID) {
        if isStrictActive { return }
        updateSet(setId) { s in let r = rule.trimmingCharacters(in: .whitespaces) ; if !r.isEmpty && !s.urls.contains(r) { s.urls.append(r) } }
    }
    func addSpecificRule(_ rule: String, to setId: UUID) { 
        if isStrictActive { return }
        updateSet(setId) { if !$0.urls.contains(rule) { $0.urls.append(rule) } } 
    }
    func removeRule(_ rule: String, from setId: UUID) { 
        if isStrictActive { return }
        updateSet(setId) { $0.urls.removeAll { $0 == rule } } 
    }
    func deleteSet(id: UUID) { 
        if isStrictActive { return }
        ruleSets.removeAll { $0.id == id } ; if activeRuleSetId == id { activeRuleSetId = ruleSets.first?.id } 
    }

    // MARK: - Schedule Management
    func saveSchedule(name: String, days: Set<Int>, date: Date?, start: Date, end: Date, color: Int, type: ScheduleType, ruleSet: UUID?, existingId: UUID?, modifyAllDays: Bool, initialDay: Int?) {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? (type == .focus ? "Focus Session" : "Break Session") : name
        
        if let id = existingId, let i = schedules.firstIndex(where: { $0.id == id }) {
            if modifyAllDays {
                schedules[i].name = finalName ; schedules[i].days = days ; schedules[i].date = date ; schedules[i].startTime = start ; schedules[i].endTime = end
                schedules[i].colorIndex = color ; schedules[i].type = type ; schedules[i].ruleSetId = ruleSet
            } else if let day = initialDay {
                schedules[i].days.remove(day)
                if schedules[i].days.isEmpty { schedules.remove(at: i) }
                schedules.append(Schedule(name: finalName, days: [day], date: date, startTime: start, endTime: end, colorIndex: color, type: type, ruleSetId: ruleSet))
            }
        } else {
            schedules.append(Schedule(name: finalName, days: days, date: date, startTime: start, endTime: end, colorIndex: color, type: type, ruleSetId: ruleSet))
        }
    }

    func deleteSchedule(id: UUID, modifyAllDays: Bool, initialDay: Int?) {
        if let i = schedules.firstIndex(where: { $0.id == id }) {
            if !modifyAllDays, let day = initialDay {
                schedules[i].days.remove(day)
                if schedules[i].days.isEmpty { schedules.remove(at: i) }
            } else {
                schedules.remove(at: i)
            }
        }
    }

    // MARK: - Challenge Logic
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

    func startPomodoro() { pomodoroStatus = .focus ; pomodoroRemaining = pomodoroFocusDuration * 60 ; pomodoroStartedAt = Date() ; runTimer() }
    func stopPomodoro() { if !isPomodoroLocked { pomodoroStatus = .none ; replacePomodoroTimer(with: nil) ; checkSchedules() } }
    func skipPomodoroPhase() { if pomodoroStatus == .focus { startBreak() } else if pomodoroStatus == .breakTime { startPomodoro() } }
    private func startBreak() { pomodoroStatus = .breakTime ; pomodoroRemaining = pomodoroBreakDuration * 60 ; runTimer() }

    func startPause(minutes: Double) {
        guard isBlocking, minutes > 0 else { return }
        isPaused = true ; pauseRemaining = minutes * 60
        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            if self.pauseRemaining > 0 { self.pauseRemaining -= 1 } else { self.cancelPause() }
        }
        replacePauseTimer(with: timer)
    }
    func cancelPause() { isPaused = false ; replacePauseTimer(with: nil) }
    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }
    func timeString(time: TimeInterval) -> String { String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60) }

    private func updateSet(_ id: UUID, _ action: (inout RuleSet) -> Void) {
        if let i = ruleSets.firstIndex(where: { $0.id == id }) { action(&ruleSets[i]) ; ruleSets = ruleSets }
    }
    private func runTimer() {
        let timer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 { self.pomodoroRemaining -= 1 }
            else { if self.pomodoroStatus == .focus { self.startBreak() } else { self.startPomodoro() } }
        }
        replacePomodoroTimer(with: timer)
        checkSchedules()
    }
    private func saveJSON<T: Encodable>(_ v: T, key: String) { if let e = try? JSONEncoder().encode(v) { defaults.set(e, forKey: key) } }
    private func loadJSON<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let d = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
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

    private func invalidateAllTimers() {
        replacePauseTimer(with: nil)
        replacePomodoroTimer(with: nil)
        replaceScheduleTimer(with: nil)
    }

    private func replaceTimer(keyPath: ReferenceWritableKeyPath<AppState, (any RepeatingTimer)?>, with newTimer: (any RepeatingTimer)?) {
        timerLock.lock()
        let oldTimer = self[keyPath: keyPath]
        self[keyPath: keyPath] = newTimer
        timerLock.unlock()
        oldTimer?.invalidate()
    }
}
