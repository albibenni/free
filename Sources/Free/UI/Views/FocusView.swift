import SwiftUI

enum FocusContentSection {
    case all
    case schedules
    case allowedWebsites
    case pomodoro
}

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @Binding var showSchedules: Bool
    let section: FocusContentSection

    @State private var showPomodoroChallenge: Bool
    @State private var pomodoroChallengeInput: String

    init(
        showRules: Binding<Bool>,
        showSchedules: Binding<Bool>,
        section: FocusContentSection = .all,
        initialShowPomodoroChallenge: Bool = false,
        initialPomodoroChallengeInput: String = ""
    ) {
        _showRules = showRules
        _showSchedules = showSchedules
        self.section = section
        _showPomodoroChallenge = State(initialValue: initialShowPomodoroChallenge)
        _pomodoroChallengeInput = State(initialValue: initialPomodoroChallengeInput)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionWarning
            headerView

            if Self.shouldShowUnblockableWarning(
                isBlocking: appState.isBlocking,
                isUnblockable: appState.isUnblockable
            ) {
                Text("Unblockable mode is active. You cannot disable Focus Mode.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            pauseDashboard
            if shouldShowOverview {
                liveOverview
            }
            if shouldShowPomodoroWidget {
                PomodoroWidget(
                    showPomodoroChallenge: $showPomodoroChallenge,
                    pomodoroChallengeInput: $pomodoroChallengeInput,
                    initialIsExpanded: section == .pomodoro
                )
            }
            if shouldShowSchedulesWidget {
                SchedulesWidget(
                    showSchedules: $showSchedules,
                    initialIsExpanded: section == .schedules
                )
            }
            if shouldShowAllowedWebsitesWidget {
                AllowedWebsitesWidget(
                    showRules: $showRules,
                    initialIsExpanded: section == .allowedWebsites
                )
            }

            Spacer()
        }
        .padding()
    }

    var shouldShowOverview: Bool {
        section == .all
    }

    var shouldShowPomodoroWidget: Bool {
        section == .pomodoro
    }

    var shouldShowSchedulesWidget: Bool {
        section == .schedules
    }

    var shouldShowAllowedWebsitesWidget: Bool {
        section == .allowedWebsites
    }

    var activeFocusScheduleNames: [String] {
        appState.schedules
            .filter { $0.type == .focus && $0.isActive() }
            .map(\.name)
    }

    var currentRuleSet: RuleSet? {
        guard let id = appState.currentPrimaryRuleSetId else { return nil }
        return appState.ruleSets.first(where: { $0.id == id })
    }

    var shouldShowAllowListPreview: Bool {
        Self.shouldShowAllowListPreview(
            isBlocking: appState.isBlocking,
            pomodoroStatus: appState.pomodoroStatus,
            hasActiveFocusSchedule: !activeFocusScheduleNames.isEmpty,
            hasCurrentRuleSet: currentRuleSet != nil
        )
    }

    var shouldShowPomodoroPreview: Bool {
        appState.pomodoroStatus != .none
    }

    var shouldShowSchedulePreview: Bool {
        !activeFocusScheduleNames.isEmpty
    }

    @ViewBuilder
    private var liveOverview: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live Overview")
                    .font(UIConstants.Typography.header)
                    .padding(.bottom, 2)

                if shouldShowSchedulePreview {
                    previewRow(
                        icon: "calendar",
                        title: "Active Schedules",
                        value: activeFocusScheduleNames.joined(separator: ", ")
                    )
                }

                if shouldShowAllowListPreview, let ruleSet = currentRuleSet {
                    previewRow(
                        icon: "globe",
                        title: "Allow List",
                        value: "\(ruleSet.name) • \(ruleSet.urls.count) rules"
                    )
                }

                if shouldShowPomodoroPreview {
                    previewRow(
                        icon: "timer",
                        title: "Pomodoro",
                        value:
                            "\(Self.pomodoroPhaseLabel(status: appState.pomodoroStatus)) • \(appState.timeString(time: appState.pomodoroRemaining))"
                    )
                }

                if !shouldShowSchedulePreview && !shouldShowAllowListPreview
                    && !shouldShowPomodoroPreview
                {
                    Text("No active schedule, allow list, or pomodoro session.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func previewRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                .frame(width: 14)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var permissionWarning: some View {
        if !appState.isTrusted {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text("Accessibility Permission Needed")
                    .foregroundColor(.white)
                    .bold()
                Spacer()
                Button("Grant", action: Self.makeGrantAccessibilityAction())
                    .foregroundColor(.black)
                    .padding(6)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            .padding()
            .background(Color.red)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.largeTitle)
                .foregroundColor(
                    Self.focusIconColor(
                        isBlocking: appState.isBlocking,
                        isPaused: appState.isPaused
                    )
                )
            VStack(alignment: .leading) {
                Text("Focus Mode")
                    .font(.title2)
                    .bold()
                HStack(spacing: 4) {
                    Text(
                        Self.statusLabel(
                            isBlocking: appState.isBlocking,
                            isPaused: appState.isPaused
                        )
                    )
                    if Self.shouldShowRuleSetName(
                        isBlocking: appState.isBlocking,
                        isPaused: appState.isPaused
                    ) {
                        Text("•")
                        Text(appState.currentPrimaryRuleSetName)
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var pauseDashboard: some View {
        if Self.shouldShowPauseDashboard(
            isBlocking: appState.isBlocking, isPaused: appState.isPaused)
        {
            VStack(spacing: 10) {
                Text("On Break")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(appState.timeString(time: appState.pauseRemaining))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)

                Button(action: Self.makeCancelPauseAction(appState: appState)) {
                    Text("End Break & Focus")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    static func shouldShowUnblockableWarning(isBlocking: Bool, isUnblockable: Bool) -> Bool {
        isBlocking && isUnblockable
    }

    static func accessibilityPromptOptions() -> CFDictionary {
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    }

    static func makeGrantAccessibilityAction(
        checkWithOptions: @escaping (CFDictionary) -> Bool = AXIsProcessTrustedWithOptions
    ) -> () -> Void {
        {
            let options = accessibilityPromptOptions()
            _ = checkWithOptions(options)
        }
    }

    static func focusIconColor(isBlocking: Bool, isPaused: Bool) -> Color {
        isBlocking && !isPaused ? .green : .gray
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
        pomodoroStatus: AppState.PomodoroStatus,
        hasActiveFocusSchedule: Bool,
        hasCurrentRuleSet: Bool
    ) -> Bool {
        hasCurrentRuleSet && (isBlocking || pomodoroStatus != .none || hasActiveFocusSchedule)
    }

    static func pomodoroPhaseLabel(status: AppState.PomodoroStatus) -> String {
        switch status {
        case .none:
            return "Inactive"
        case .focus:
            return "Focus"
        case .breakTime:
            return "Break"
        }
    }

    static func makeCancelPauseAction(appState: AppState) -> () -> Void {
        { appState.cancelPause() }
    }
}
