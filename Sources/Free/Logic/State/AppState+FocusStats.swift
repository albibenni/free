import Foundation

extension AppState {
    /// Focus time accumulated for today, with a stale day rolled over to zero.
    /// This is the value the Focus header renders.
    var focusedSecondsTodayDisplay: TimeInterval {
        FocusStatsService.rolledOver(
            currentFocusStats,
            now: focusStatsNow(),
            calendar: .current
        ).secondsToday
    }

    private var currentFocusStats: FocusStatsService.Stats {
        FocusStatsService.Stats(secondsToday: focusedSecondsToday, day: focusStatsDay)
    }

    /// Detect rising/falling edges of "is focusing" (`isBlocking && !isPaused`)
    /// and open/close the accumulation interval accordingly. Idempotent: safe to
    /// call from any state mutation that could flip either flag.
    func refreshFocusAccumulation() {
        guard isFocusStatsReady else { return }
        let now = focusStatsNow()
        let isFocusing = isBlocking && !isPaused

        if isFocusing {
            guard focusIntervalStartedAt == nil else { return }
            applyFocusStats(FocusStatsService.rolledOver(currentFocusStats, now: now, calendar: .current))
            focusIntervalStartedAt = now
            startFocusStatsTimer()
        } else {
            guard let start = focusIntervalStartedAt else { return }
            applyFocusStats(
                FocusStatsService.folding(currentFocusStats, intervalStart: start, now: now, calendar: .current)
            )
            focusIntervalStartedAt = nil
            stopFocusStatsTimer()
        }
    }

    /// Reset the total when the persisted day is no longer today (e.g. the app
    /// was reopened on a new day). Called at launch.
    func rollOverFocusStatsIfNeeded() {
        applyFocusStats(FocusStatsService.rolledOver(currentFocusStats, now: focusStatsNow(), calendar: .current))
    }

    private func focusStatsTick() {
        guard let start = focusIntervalStartedAt else { return }
        let now = focusStatsNow()
        applyFocusStats(
            FocusStatsService.folding(currentFocusStats, intervalStart: start, now: now, calendar: .current)
        )
        focusIntervalStartedAt = now
    }

    private func applyFocusStats(_ stats: FocusStatsService.Stats) {
        if focusedSecondsToday != stats.secondsToday { focusedSecondsToday = stats.secondsToday }
        if focusStatsDay != stats.day { focusStatsDay = stats.day }
        settingsStore.setFocusedSecondsToday(stats.secondsToday)
        settingsStore.setFocusStatsDay(stats.day)
    }

    private func startFocusStatsTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 60) { [weak self] in
            self?.focusStatsTick()
        }
        timerCoordinator.replaceFocusStatsTimer(with: timer)
    }

    private func stopFocusStatsTimer() {
        timerCoordinator.replaceFocusStatsTimer(with: nil)
    }
}
