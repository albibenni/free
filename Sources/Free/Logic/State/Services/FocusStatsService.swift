import Foundation

/// Stateless accumulator for the "focused today" total shown in the Focus header.
///
/// Focus time is wall-clock time spent actively blocking and not on a break
/// (the caller decides when an interval is "focusing" — here it is just folded
/// in). The total resets at local midnight: any stored total whose day is not
/// `now`'s day reads as zero and is reset on the next fold.
enum FocusStatsService {
    struct Stats: Equatable {
        var secondsToday: TimeInterval
        /// Start-of-day the `secondsToday` total belongs to.
        var day: Date
    }

    /// Reset the accumulator to zero when `now` falls on a different day than
    /// `stats.day`; otherwise return it unchanged.
    static func rolledOver(_ stats: Stats, now: Date, calendar: Calendar) -> Stats {
        let today = calendar.startOfDay(for: now)
        guard stats.day != today else { return stats }
        return Stats(secondsToday: 0, day: today)
    }

    /// Fold a focus interval `[start, now]` into the accumulator.
    ///
    /// Rolls over first, then adds only the portion of the interval that falls
    /// on the current day (so a session spanning midnight credits each day
    /// correctly) and ignores non-positive spans (clock skew, `start > now`).
    static func folding(
        _ stats: Stats,
        intervalStart start: Date,
        now: Date,
        calendar: Calendar
    ) -> Stats {
        var rolled = rolledOver(stats, now: now, calendar: calendar)
        let dayStart = calendar.startOfDay(for: now)
        let effectiveStart = max(start, dayStart)
        let elapsed = now.timeIntervalSince(effectiveStart)
        if elapsed > 0 {
            rolled.secondsToday += elapsed
        }
        return rolled
    }
}
