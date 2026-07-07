import AppKit

enum FocusContentSection {
    case all
    case schedules
    case allowedWebsites
    case pomodoro
}

enum FocusSectionSupport {
    static func shouldShowStrictWarning(isBlocking: Bool, isStrict: Bool) -> Bool {
        isBlocking && isStrict
    }

    static func accessibilityPromptOptions() -> CFDictionary {
        ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    }

    static func makeGrantAccessibilityAction(
        checkWithOptions: @escaping (CFDictionary) -> Bool = AXIsProcessTrustedWithOptions
    ) -> () -> Void {
        {
            let options = accessibilityPromptOptions()
            _ = checkWithOptions(options)
        }
    }

    static func focusIconColor(isBlocking: Bool, isPaused: Bool) -> NSColor {
        isBlocking && !isPaused ? .systemGreen : .systemGray
    }

    static func statusLabel(isBlocking: Bool, isPaused: Bool) -> String {
        isBlocking ? (isPaused ? "Paused" : "Active") : "Inactive"
    }

    static func shouldShowRuleSetName(isBlocking: Bool, isPaused: Bool) -> Bool {
        isBlocking && !isPaused
    }

    static func shouldShowPauseDashboard(isBlocking: Bool, isPaused: Bool) -> Bool {
        isBlocking && isPaused
    }

    static func shouldShowAllowListPreview(
        isBlocking: Bool,
        pomodoroStatus: PomodoroStatus,
        hasActiveFocusSchedule: Bool,
        hasCurrentRuleSet: Bool
    ) -> Bool {
        hasCurrentRuleSet && (isBlocking || pomodoroStatus != .none || hasActiveFocusSchedule)
    }

    static func pomodoroPhaseLabel(status: PomodoroStatus) -> String {
        switch status {
        case .none:
            return "Inactive"
        case .focus:
            return "Focus"
        case .breakTime:
            return "Break"
        }
    }

    static func strictWarningText(for section: FocusContentSection) -> String {
        switch section {
        case .all:
            return StrictModeCopy.active(withSuffix: " A challenge phrase is required to disable Focus Mode.")
        case .schedules, .allowedWebsites, .pomodoro:
            return StrictModeCopy.active
        }
    }

    static func makeCancelPauseAction(cancelPause: @escaping () -> Void) -> () -> Void {
        cancelPause
    }

    /// Formats the daily focus total for the header stat: `0m`, `Ym`, or `Xh Ym`
    /// (whole minutes, rounded down). Negative input is clamped to zero.
    static func focusedTodayText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
