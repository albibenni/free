import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isBlocking = false {
        didSet {
            UserDefaults.standard.set(isBlocking, forKey: "IsBlocking")
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
            UserDefaults.standard.set(isUnblockable, forKey: "IsUnblockable")
        }
    }
    @Published var isTrusted = false
    @Published var weekStartsOnMonday: Bool = false {
        didSet {
            UserDefaults.standard.set(weekStartsOnMonday, forKey: "WeekStartsOnMonday")
        }
    }
    @Published var allowedRules: [String] = [] {
        didSet {
            UserDefaults.standard.set(allowedRules, forKey: "AllowedRules")
        }
    }
    
    // Schedules
    @Published var schedules: [Schedule] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(schedules) {
                UserDefaults.standard.set(encoded, forKey: "Schedules")
            }
            checkSchedules()
        }
    }
    
    // Pause / Timer Logic
    @Published var isPaused = false
    @Published var pauseRemaining: TimeInterval = 0
    private var pauseTimer: Timer?
    
    private var monitor: BrowserMonitor?
    private var scheduleTimer: Timer?
    private var wasStartedBySchedule = false
    
    init() {
        self.isBlocking = UserDefaults.standard.bool(forKey: "IsBlocking")
        self.isUnblockable = UserDefaults.standard.bool(forKey: "IsUnblockable")
        self.weekStartsOnMonday = UserDefaults.standard.bool(forKey: "WeekStartsOnMonday")
        self.allowedRules = UserDefaults.standard.stringArray(forKey: "AllowedRules") ?? [
            "https://www.youtube.com/watch?v=gmuTjeQUbTM"
        ]
        
        if let data = UserDefaults.standard.data(forKey: "Schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            self.schedules = decoded
        } else {
            self.schedules = []
        }
        
        self.monitor = BrowserMonitor(appState: self)
        
        startScheduleTimer()
    }
    
    func startScheduleTimer() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
        // Run immediately
        checkSchedules()
    }
    
    func checkSchedules() {
        let anyActive = schedules.contains { $0.isActive() }
        
        if anyActive {
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
