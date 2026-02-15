import SwiftUI
import Combine

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
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
    
    @Published var isBlocking = false {
        didSet {
            defaults.set(isBlocking, forKey: "IsBlocking")
            if !isBlocking { 
                cancelPause()
            }
        }
    }
    
    // Call this for manual toggles from the UI
    func toggleBlocking() {
        if isBlocking && isUnblockable { return }
        isBlocking.toggle()
        wasStartedBySchedule = false // Manual override
    }

    @Published var isUnblockable = false {
        didSet {
            defaults.set(isUnblockable, forKey: "IsUnblockable")
        }
    }
    @Published var isTrusted = false
    @Published var weekStartsOnMonday: Bool = false {
        didSet {
            defaults.set(weekStartsOnMonday, forKey: "WeekStartsOnMonday")
        }
    }
    @Published var accentColorIndex: Int = 0 {
        didSet {
            defaults.set(accentColorIndex, forKey: "AccentColorIndex")
        }
    }
    @Published var appearanceMode: AppearanceMode = .system {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: "AppearanceMode")
        }
    }
    @Published var calendarIntegrationEnabled: Bool = false {
        didSet {
            defaults.set(calendarIntegrationEnabled, forKey: "CalendarIntegrationEnabled")
            if calendarIntegrationEnabled {
                calendarManager.requestAccess()
            }
            checkSchedules()
        }
    }
    @Published var ruleSets: [RuleSet] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(ruleSets) {
                defaults.set(encoded, forKey: "RuleSets")
            }
        }
    }
    @Published var activeRuleSetId: UUID? = nil {
        didSet {
            defaults.set(activeRuleSetId?.uuidString, forKey: "ActiveRuleSetId")
        }
    }
    
    // Schedules
    @Published var schedules: [Schedule] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(schedules) {
                defaults.set(encoded, forKey: "Schedules")
            }
            checkSchedules()
        }
    }
    
    // Pause / Timer Logic
    @Published var isPaused = false
    @Published var pauseRemaining: TimeInterval = 0
    private var pauseTimer: Timer?
    
    @Published var currentOpenUrls: [String] = []
    
    var monitor: BrowserMonitor?
    private var scheduleTimer: Timer?
    private var wasStartedBySchedule = false
    
    // External Calendar
    @Published var calendarManager = CalendarManager()
    private var calendarCancellable: AnyCancellable?

    // Pomodoro
    enum PomodoroStatus: String, Codable {
        case none
        case focus
        case breakTime
    }
    @Published var pomodoroStatus: PomodoroStatus = .none
    @Published var pomodoroFocusDuration: Double = 25 {
        didSet { defaults.set(pomodoroFocusDuration, forKey: "PomodoroFocusDuration") }
    }
    @Published var pomodoroBreakDuration: Double = 5 {
        didSet { defaults.set(pomodoroBreakDuration, forKey: "PomodoroBreakDuration") }
    }
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroStartedAt: Date?
    private var pomodoroTimer: Timer?
    
    var isPomodoroLocked: Bool {
        guard isUnblockable && (pomodoroStatus == .focus || pomodoroStatus == .breakTime) else { return false }
        guard let startedAt = pomodoroStartedAt else { return false }
        return Date().timeIntervalSince(startedAt) > 10
    }

    var isStrictActive: Bool {
        return isBlocking && isUnblockable
    }

    var currentPrimaryRuleSetId: UUID? {
        // Priority 1: Manual focus or Pomodoro session
        if (isBlocking && !wasStartedBySchedule) || pomodoroStatus == .focus {
            return activeRuleSetId ?? ruleSets.first?.id
        }
        
        // Priority 2: Active schedule
        if let activeSchedule = schedules.first(where: { $0.isActive() && $0.type == .focus }) {
            return activeSchedule.ruleSetId ?? ruleSets.first?.id
        }
        
        // Default to active manual selection or first set
        return activeRuleSetId ?? ruleSets.first?.id
    }

    var allowedRules: [String] {
        var urls = Set<String>()
        
        // 1. Rules from active schedules
        let activeSchedules = schedules.filter { $0.isActive() && $0.type == .focus }
        for schedule in activeSchedules {
            if let ruleSetId = schedule.ruleSetId,
               let ruleSet = ruleSets.first(where: { $0.id == ruleSetId }) {
                urls.formUnion(ruleSet.urls)
            }
        }
        
        // 2. Rules from manual focus or Pomodoro
        if (isBlocking && !wasStartedBySchedule) || pomodoroStatus == .focus {
            if let activeId = activeRuleSetId,
               let ruleSet = ruleSets.first(where: { $0.id == activeId }) {
                urls.formUnion(ruleSet.urls)
            } else if let firstSet = ruleSets.first {
                // Fallback to first set if none selected
                urls.formUnion(firstSet.urls)
            }
        }

        // 3. Global fallback if nothing active but blocking
        if urls.isEmpty && isBlocking {
            if let firstSet = ruleSets.first {
                urls.formUnion(firstSet.urls)
            }
        }
        
        return Array(urls)
    }
    
    init(defaults: UserDefaults = .standard, monitor: BrowserMonitor? = nil, isTesting: Bool = false) {
        self.defaults = defaults
        
        // Initialize basic properties from defaults
        self.isBlocking = defaults.bool(forKey: "IsBlocking")
        self.isUnblockable = defaults.bool(forKey: "IsUnblockable")
        self.weekStartsOnMonday = defaults.bool(forKey: "WeekStartsOnMonday")
        self.accentColorIndex = defaults.integer(forKey: "AccentColorIndex")
        
        self.pomodoroFocusDuration = defaults.double(forKey: "PomodoroFocusDuration")
        if self.pomodoroFocusDuration == 0 { self.pomodoroFocusDuration = 25 }
        self.pomodoroBreakDuration = defaults.double(forKey: "PomodoroBreakDuration")
        if self.pomodoroBreakDuration == 0 { self.pomodoroBreakDuration = 5 }

        self.calendarIntegrationEnabled = defaults.bool(forKey: "CalendarIntegrationEnabled")

        // Load Appearance
        if let modeString = defaults.string(forKey: "AppearanceMode"),
           let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        
        // Load RuleSets
        if let data = defaults.data(forKey: "RuleSets"),
           let decoded = try? JSONDecoder().decode([RuleSet].self, from: data) {
            self.ruleSets = decoded
        } else {
            let defaultRules = defaults.stringArray(forKey: "AllowedRules") ?? ["https://www.youtube.com/watch?v=gmuTjeQUbTM"]
            self.ruleSets = [RuleSet(name: "Default", urls: defaultRules)]
        }

        if let idString = defaults.string(forKey: "ActiveRuleSetId"),
           let uuid = UUID(uuidString: idString) {
            self.activeRuleSetId = uuid
        } else {
            self.activeRuleSetId = ruleSets.first?.id
        }
        
        // Load Schedules
        if let data = defaults.data(forKey: "Schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            self.schedules = decoded
        } else {
            self.schedules = []
        }
        
        // Initialize Monitor
        if let monitor = monitor {
            self.monitor = monitor
        } else if !isTesting {
            // Only create real monitor if NOT testing
            self.monitor = BrowserMonitor(appState: self)
        }
        
        // Listen to calendar updates
        calendarCancellable = calendarManager.$events.sink { [weak self] _ in
            self?.checkSchedules()
        }
        
        startScheduleTimer()
    }
    
    func startScheduleTimer() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
        // Run immediately
        checkSchedules()
    }

    func refreshCurrentOpenUrls() {
        self.currentOpenUrls = monitor?.getAllOpenUrls() ?? []
    }

    // MARK: - Rule Management
    func addSpecificRule(_ rule: String, to setId: UUID) {
        if let index = ruleSets.firstIndex(where: { $0.id == setId }) {
            if !ruleSets[index].urls.contains(rule) {
                ruleSets[index].urls.append(rule)
            }
        }
    }

    func addRule(_ rule: String, to setId: UUID) {
        let cleanedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRule.isEmpty else { return }

        if let index = ruleSets.firstIndex(where: { $0.id == setId }) {
            if !ruleSets[index].urls.contains(cleanedRule) {
                ruleSets[index].urls.append(cleanedRule)
            }
        }
    }

    func removeRule(_ rule: String, from setId: UUID) {
        if let index = ruleSets.firstIndex(where: { $0.id == setId }) {
            if let ruleIndex = ruleSets[index].urls.firstIndex(of: rule) {
                ruleSets[index].urls.remove(at: ruleIndex)
            }
        }
    }

    func deleteSet(id: UUID) {
        ruleSets.removeAll(where: { $0.id == id })
        if activeRuleSetId == id {
            activeRuleSetId = ruleSets.first?.id
        }
    }
    
    func checkSchedules() {
        let activeSchedules = schedules.filter { $0.isActive() }
        let hasFocus = activeSchedules.contains { $0.type == .focus }
        let hasBreak = activeSchedules.contains { $0.type == .unfocus }
        
        // Check external events only if integration is enabled
        let hasExternalEvent = calendarIntegrationEnabled && calendarManager.events.contains { $0.isActive() }
        
        // Default Logic: Focus AND No Break AND No Calendar Event
        // If isUnblockable is true, we ignore hasExternalEvent (treat meetings as focus)
        var shouldBeBlocking = false
        
        if isUnblockable {
            // Strict: Blocking if ANY focus session is active, ignoring external events
            shouldBeBlocking = hasFocus && !hasBreak
        } else {
            // Normal: Blocking if focus active, but unblock for breaks or meetings
            shouldBeBlocking = hasFocus && !hasBreak && !hasExternalEvent
        }

        // Pomodoro Override
        if pomodoroStatus == .focus {
            if isUnblockable {
                shouldBeBlocking = true
            } else {
                shouldBeBlocking = !hasExternalEvent
            }
        } else if pomodoroStatus == .breakTime {
            shouldBeBlocking = false
        }
        
        if shouldBeBlocking {
            if !isBlocking {
                isBlocking = true
                wasStartedBySchedule = true
            }
        } else {
            if isBlocking && wasStartedBySchedule {
                isBlocking = false
                wasStartedBySchedule = false
            }
        }
    }

    // MARK: - Pomodoro Logic
    func startPomodoro() {
        pomodoroStatus = .focus
        pomodoroRemaining = pomodoroFocusDuration * 60
        pomodoroStartedAt = Date()
        startPomodoroTimer()
        checkSchedules()
    }

    func stopPomodoro() {
        if isPomodoroLocked { return }
        pomodoroStatus = .none
        pomodoroStartedAt = nil
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
        checkSchedules()
    }

    func skipPomodoroPhase() {
        if pomodoroStatus == .focus {
            startPomodoroBreak()
        } else if pomodoroStatus == .breakTime {
            startPomodoro()
        }
    }

    private func startPomodoroBreak() {
        pomodoroStatus = .breakTime
        pomodoroRemaining = pomodoroBreakDuration * 60
        startPomodoroTimer()
        checkSchedules()
    }

    private func startPomodoroTimer() {
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                self.pomodoroTimer?.invalidate()
                // Auto-switch phase or stop? Let's auto-switch for now or just stop.
                // Standard Pomodoro usually rings a bell and waits. 
                // For this MVP, let's switch automatically or just stop.
                // Let's try switching automatically.
                if self.pomodoroStatus == .focus {
                    self.startPomodoroBreak()
                } else {
                    self.startPomodoro()
                }
            }
        }
    }
    
    func startPause(minutes: Double) {
        guard isBlocking else { return }
        isPaused = true
        pauseRemaining = minutes * 60
        
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pauseRemaining > 0 {
                self.pauseRemaining -= 1
            } else {
                self.cancelPause()
            }
        }
    }

    func cancelPause() {
        isPaused = false
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
    
    func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
