import Foundation
import Testing

@testable import FreeLogic

private final class FakeClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@Suite(.serialized)
@MainActor
struct AppStateFocusStatsTests {
    /// A fixed noon so `+120s` style advances never cross a local midnight.
    private func noon() -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
    }

    private func makeAppState(
        name: String,
        clock: FakeClock,
        scheduler: MockRepeatingTimerScheduler
    ) -> AppState {
        let suite = "AppStateFocusStatsTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(
            defaults: defaults,
            timerScheduler: scheduler,
            dateProvider: { clock.now },
            isTesting: true
        )
    }

    @Test("Focus time accumulates while blocking and the tick folds it")
    func accumulatesWhileBlocking() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let appState = makeAppState(name: "accumulates", clock: clock, scheduler: scheduler)

        let baseline = scheduler.handlers.count
        appState.isBlocking = true // rising edge → focus-stats timer scheduled

        #expect(scheduler.intervals[baseline] == 60)
        #expect(appState.focusIntervalStartedAt == clock.now)

        clock.advance(120)
        scheduler.fire(at: baseline) // focusStatsTick folds the elapsed interval

        #expect(appState.focusedSecondsToday == 120)
        #expect(appState.focusedSecondsTodayDisplay == 120)
    }

    @Test("Stopping blocking folds the in-progress interval")
    func stopFoldsInterval() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let appState = makeAppState(name: "stopFolds", clock: clock, scheduler: scheduler)

        appState.isBlocking = true
        clock.advance(90)
        appState.isBlocking = false // falling edge folds 90s

        #expect(appState.focusedSecondsToday == 90)
        #expect(appState.focusIntervalStartedAt == nil)
    }

    @Test("Break time is not counted as focus time")
    func breaksExcluded() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let appState = makeAppState(name: "breaks", clock: clock, scheduler: scheduler)

        appState.isBlocking = true
        clock.advance(60) // 60s focused
        appState.startPause(minutes: 5) // break begins → fold 60s, stop counting

        #expect(appState.focusedSecondsToday == 60)
        #expect(appState.focusIntervalStartedAt == nil)

        clock.advance(300) // 5 min on break — must not count
        appState.cancelPause() // break ends → resume counting

        #expect(appState.focusedSecondsToday == 60)
        #expect(appState.focusIntervalStartedAt == clock.now)

        clock.advance(30)
        appState.isBlocking = false // fold final 30s

        #expect(appState.focusedSecondsToday == 90)
    }

    @Test("Overlapping blocking sources count as one wall-clock interval")
    func overlappingSourcesCountOnce() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let appState = makeAppState(name: "overlapping", clock: clock, scheduler: scheduler)

        appState.isBlocking = true // e.g. a schedule activates
        let start = appState.focusIntervalStartedAt
        let focusTimerCount = scheduler.intervals.filter { $0 == 60 }.count

        clock.advance(30)
        // A second overlapping source (another schedule / pomodoro) re-asserts
        // blocking while already focusing — must not restart or double-count.
        appState.isBlocking = true
        #expect(appState.focusIntervalStartedAt == start)
        #expect(scheduler.intervals.filter { $0 == 60 }.count == focusTimerCount)

        clock.advance(30)
        appState.isBlocking = false // all sources end

        // 60s of wall-clock elapsed total, counted once (not 120s).
        #expect(appState.focusedSecondsToday == 60)
    }

    @Test("A stale day reads as zero")
    func rollsOverStaleDay() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let appState = makeAppState(name: "rollover", clock: clock, scheduler: scheduler)

        appState.focusedSecondsToday = 3600
        appState.focusStatsDay = Calendar.current.startOfDay(for: clock.now.addingTimeInterval(-86_400))

        #expect(appState.focusedSecondsTodayDisplay == 0)
    }

    @Test("Focus total persists across relaunch on the same day")
    func persistsSameDay() {
        let clock = FakeClock(noon())
        let scheduler = MockRepeatingTimerScheduler()
        let suite = "AppStateFocusStatsTests.persist"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = AppState(
            defaults: defaults,
            timerScheduler: scheduler,
            dateProvider: { clock.now },
            isTesting: true
        )
        first.isBlocking = true
        clock.advance(120)
        first.isBlocking = false
        #expect(first.focusedSecondsToday == 120)

        let second = AppState(
            defaults: defaults,
            timerScheduler: MockRepeatingTimerScheduler(),
            dateProvider: { clock.now },
            isTesting: true
        )
        #expect(second.focusedSecondsToday == 120)
    }
}
