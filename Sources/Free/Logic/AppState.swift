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
            if calendarIntegrationEnabled { calendarManager.requestAccess() }
            checkSchedules()
        }
    }
    @Published var ruleSets: [RuleSet] = [] { didSet { saveJSON(ruleSets, key: "RuleSets") } }
    @Published var activeRuleSetId: UUID? = nil { didSet { defaults.set(activeRuleSetId?.uuidString, forKey: "ActiveRuleSetId") } }
    @Published var schedules: [Schedule] = [] { didSet { saveJSON(schedules, key: "Schedules") ; checkSchedules() } }

    @Published var pomodoroFocusDuration: Double = 25 { didSet { defaults.set(pomodoroFocusDuration, forKey: "PomodoroFocusDuration") } }
    @Published var pomodoroBreakDuration: Double = 5 { didSet { defaults.set(pomodoroBreakDuration, forKey: "PomodoroBreakDuration") } }

    // MARK: - Volatile State
    @Published var isPaused = false
    @Published var pauseRemaining: TimeInterval = 0
    @Published var pomodoroStatus: PomodoroStatus = .none
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroStartedAt: Date?
    @Published var currentOpenUrls: [String] = []

    var monitor: BrowserMonitor?
    let calendarManager = CalendarManager()
    private var calendarCancellable: AnyCancellable?
    private var pauseTimer: Timer?, pomodoroTimer: Timer?, scheduleTimer: Timer?
    private var wasStartedBySchedule = false

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

    // MARK: - Initialization
    init(defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil, isTesting: Bool = false) {
        self.defaults = defaults
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
        calendarCancellable = calendarManager.$events.sink { [weak self] _ in self?.checkSchedules() }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.checkSchedules() }
        checkSchedules()
    }

    // MARK: - Logic & Actions
    func toggleBlocking() { if !(isBlocking && isUnblockable) { isBlocking.toggle() ; wasStartedBySchedule = false } }
    func checkSchedules() {
        let active = schedules.filter { $0.isActive() }
        let hasFocus = active.contains { $0.type == .focus } || pomodoroStatus == .focus
        let hasBreak = active.contains { $0.type == .unfocus } || pomodoroStatus == .breakTime
        let hasMeeting = calendarIntegrationEnabled && !isUnblockable && calendarManager.events.contains { $0.isActive() }
        let shouldBeBlocking = hasFocus && !hasBreak && !hasMeeting
        if shouldBeBlocking && !isBlocking { isBlocking = true ; wasStartedBySchedule = true }
        else if !shouldBeBlocking && isBlocking && wasStartedBySchedule { isBlocking = false ; wasStartedBySchedule = false }
    }

    func addRule(_ rule: String, to setId: UUID) {
        updateSet(setId) { s in let r = rule.trimmingCharacters(in: .whitespaces) ; if !r.isEmpty && !s.urls.contains(r) { s.urls.append(r) } }
    }
    func addSpecificRule(_ rule: String, to setId: UUID) { updateSet(setId) { if !$0.urls.contains(rule) { $0.urls.append(rule) } } }
    func removeRule(_ rule: String, from setId: UUID) { updateSet(setId) { $0.urls.removeAll { $0 == rule } } }
    func deleteSet(id: UUID) { ruleSets.removeAll { $0.id == id } ; if activeRuleSetId == id { activeRuleSetId = ruleSets.first?.id } }

    func startPomodoro() { pomodoroStatus = .focus ; pomodoroRemaining = pomodoroFocusDuration * 60 ; pomodoroStartedAt = Date() ; runTimer() }
    func stopPomodoro() { if !isPomodoroLocked { pomodoroStatus = .none ; pomodoroTimer?.invalidate() ; checkSchedules() } }
    func skipPomodoroPhase() { if pomodoroStatus == .focus { startBreak() } else if pomodoroStatus == .breakTime { startPomodoro() } }
    private func startBreak() { pomodoroStatus = .breakTime ; pomodoroRemaining = pomodoroBreakDuration * 60 ; runTimer() }

    func startPause(minutes: Double) {
        guard isBlocking else { return }
        isPaused = true ; pauseRemaining = minutes * 60 ; pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pauseRemaining > 0 { self.pauseRemaining -= 1 } else { self.cancelPause() }
        }
    }
    func cancelPause() { isPaused = false ; pauseTimer?.invalidate() }
    func refreshCurrentOpenUrls() { currentOpenUrls = monitor?.getAllOpenUrls() ?? [] }
    func timeString(time: TimeInterval) -> String { String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60) }

    private func updateSet(_ id: UUID, _ action: (inout RuleSet) -> Void) {
        if let i = ruleSets.firstIndex(where: { $0.id == id }) { action(&ruleSets[i]) ; ruleSets = ruleSets }
    }
    private func runTimer() {
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 { self.pomodoroRemaining -= 1 }
            else { if self.pomodoroStatus == .focus { self.startBreak() } else { self.startPomodoro() } }
        }
        checkSchedules()
    }
    private func saveJSON<T: Encodable>(_ v: T, key: String) { if let e = try? JSONEncoder().encode(v) { defaults.set(e, forKey: key) } }
    private func loadJSON<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let d = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
