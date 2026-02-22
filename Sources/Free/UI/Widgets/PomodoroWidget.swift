import SwiftUI

struct PomodoroWidget: View {
    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    var appState: AppState { actionAppState ?? environmentAppState }
    @Binding var showPomodoroChallenge: Bool
    @Binding var pomodoroChallengeInput: String
    @State private var isExpanded = false
    @State private var showCustomTimer = false
    @State private var customMinutesString = ""

    init(
        showPomodoroChallenge: Binding<Bool>,
        pomodoroChallengeInput: Binding<String>,
        actionAppState: AppState? = nil,
        initialIsExpanded: Bool = false,
        initialShowCustomTimer: Bool = false,
        initialCustomMinutesString: String = ""
    ) {
        self._showPomodoroChallenge = showPomodoroChallenge
        self._pomodoroChallengeInput = pomodoroChallengeInput
        self.actionAppState = actionAppState
        self._isExpanded = State(initialValue: initialIsExpanded)
        self._showCustomTimer = State(initialValue: initialShowCustomTimer)
        self._customMinutesString = State(initialValue: initialCustomMinutesString)
    }

    func startCustomBreakFromInput() {
        if let minutes = Double(customMinutesString) {
            appState.startPause(minutes: minutes)
        }
        customMinutesString = ""
    }

    func stopPomodoroFromChallengeInput() {
        _ = appState.stopPomodoroWithChallenge(phrase: pomodoroChallengeInput)
        pomodoroChallengeInput = ""
    }

    func cancelChallengeInput() {
        pomodoroChallengeInput = ""
    }

    var body: some View {
        WidgetCard {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.red)
                    Text("Pomodoro Mode")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded || appState.pomodoroStatus != .none {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 20) {
                        PomodoroSidebar(showCustomTimer: $showCustomTimer)

                        VStack(alignment: .center, spacing: 16) {
                            if appState.pomodoroStatus == .none {
                                PomodoroSetupView()
                            } else {
                                PomodoroActiveView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }

                    PomodoroRuleSetPicker()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)

                    PomodoroActionButtons(
                        showPomodoroChallenge: $showPomodoroChallenge
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .alert("Custom Break", isPresented: $showCustomTimer) {
            TextField("Minutes", text: $customMinutesString)
            Button("Start", action: startCustomBreakFromInput)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter duration in minutes:")
        }
        .alert("Emergency Unlock", isPresented: $showPomodoroChallenge) {
            TextField("Type the phrase exactly", text: $pomodoroChallengeInput)
            Button("Stop Pomodoro", role: .destructive, action: stopPomodoroFromChallengeInput)
            Button("Cancel", role: .cancel, action: cancelChallengeInput)
        } message: {
            Text(
                "To stop a Strict Pomodoro session, you must type the following exactly:\n\n\"\(AppState.challengePhrase)\""
            )
        }
    }
}

struct PomodoroRuleSetPicker: View {
    @EnvironmentObject var appState: AppState

    var canSwitchRuleSetSelection: Bool {
        !appState.isStrictActive
    }

    var selectedRuleSetId: UUID? {
        Self.selectedRuleSetId(activeRuleSetId: appState.activeRuleSetId, ruleSets: appState.ruleSets)
    }

    static func selectedRuleSetId(activeRuleSetId: UUID?, ruleSets: [RuleSet]) -> UUID? {
        activeRuleSetId ?? ruleSets.first?.id
    }

    static func updatedActiveRuleSetId(
        currentActiveRuleSetId: UUID?,
        selectedRuleSetId: UUID,
        canSwitchRuleSetSelection: Bool
    ) -> UUID? {
        canSwitchRuleSetSelection ? selectedRuleSetId : currentActiveRuleSetId
    }

    func selectRuleSet(_ set: RuleSet) {
        let updatedId = Self.updatedActiveRuleSetId(
            currentActiveRuleSetId: appState.activeRuleSetId,
            selectedRuleSetId: set.id,
            canSwitchRuleSetSelection: canSwitchRuleSetSelection
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.activeRuleSetId = updatedId
        }
    }

    var body: some View {
        if !appState.ruleSets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("SELECT LIST")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(appState.ruleSets) { set in
                            Button(action: { selectRuleSet(set) }) {
                                HStack {
                                    Image(systemName: selectedRuleSetId == set.id ? "link.circle.fill" : "link")
                                        .font(.system(size: 12))
                                        .foregroundColor(
                                            selectedRuleSetId == set.id
                                                ? FocusColor.color(for: appState.accentColorIndex) : .secondary
                                        )

                                    Text(set.name)
                                        .font(.subheadline)
                                        .fontWeight(selectedRuleSetId == set.id ? .bold : .regular)
                                        .foregroundColor(selectedRuleSetId == set.id ? .primary : .secondary)

                                    Spacer()

                                    if selectedRuleSetId == set.id {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedRuleSetId == set.id
                                        ? FocusColor.color(for: appState.accentColorIndex).opacity(0.1)
                                        : Color.primary.opacity(0.03)
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSwitchRuleSetSelection)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }
}

struct PomodoroSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showCustomTimer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PRESETS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    ForEach(
                        [
                            (25.0, 5.0, "25/5"),
                            (45.0, 15.0, "45/15"),
                            (50.0, 10.0, "50/10"),
                            (90.0, 20.0, "90/20"),
                        ], id: \.2
                    ) { focus, breakTime, label in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appState.pomodoroFocusDuration = focus
                                appState.pomodoroBreakDuration = breakTime
                            }
                        }) {
                            Text(label)
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 50)
                                .padding(.vertical, 6)
                                .background(
                                    appState.pomodoroFocusDuration == focus
                                        && appState.pomodoroBreakDuration == breakTime
                                        ? FocusColor.color(for: appState.accentColorIndex).opacity(
                                            0.15)
                                        : Color.primary.opacity(0.05)
                                )
                                .foregroundColor(
                                    appState.pomodoroFocusDuration == focus
                                        && appState.pomodoroBreakDuration == breakTime
                                        ? FocusColor.color(for: appState.accentColorIndex)
                                        : .secondary
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK BREAK")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    ForEach([5, 15, 30], id: \.self) { mins in
                        Button(action: { appState.startPause(minutes: Double(mins)) }) {
                            Text("\(mins)m")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 50)
                                .padding(.vertical, 6)
                                .padding(.leading, 2)
                                .background(Color.primary.opacity(0.05))
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!appState.isBlocking || appState.isStrictActive)
                    }

                    Button(action: { showCustomTimer = true }) {
                        Text("Cust")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 50)
                            .padding(.vertical, 6)
                            .padding(.leading, 2)
                            .background(Color.primary.opacity(0.05))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!appState.isBlocking || appState.isStrictActive)
                }
            }
        }
        .padding(.top, 4)
        .padding(.leading, 20)
        .padding(.bottom, 20)
    }
}

struct PomodoroSetupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 60) {
                timerColumn(
                    title: "FOCUS",
                    duration: $appState.pomodoroFocusDuration,
                    maxMinutes: 120,
                    icon: "leaf.fill"
                )

                timerColumn(
                    title: "BREAK",
                    duration: $appState.pomodoroBreakDuration,
                    maxMinutes: 60,
                    icon: "cup.and.saucer.fill"
                )
            }
        }
    }

    @ViewBuilder
    private func timerColumn(
        title: String, duration: Binding<Double>, maxMinutes: Double, icon: String
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.secondary)

            PomodoroTimerView(
                durationMinutes: duration,
                maxMinutes: maxMinutes,
                iconName: icon,
                title: "",
                color: FocusColor.color(for: appState.accentColorIndex)
            )
            .frame(width: 240, height: 240)

            HStack(spacing: 20) {
                Button(action: { if duration.wrappedValue > 5 { duration.wrappedValue -= 5 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: {
                    if duration.wrappedValue < maxMinutes { duration.wrappedValue += 5 }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct PomodoroActiveView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            let total =
                (appState.pomodoroStatus == .focus
                    ? appState.pomodoroFocusDuration : appState.pomodoroBreakDuration) * 60

            VStack(spacing: 20) {
                Text(appState.pomodoroStatus == .focus ? "FOCUSING" : "BREAKING")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.secondary)

                ZStack {
                    PomodoroProgressView(
                        progress: appState.pomodoroRemaining / total,
                        iconName: appState.pomodoroStatus == .focus
                            ? "leaf.fill" : "cup.and.saucer.fill",
                        title: "",
                        color: FocusColor.color(for: appState.accentColorIndex),
                        timeString: appState.timeString(time: appState.pomodoroRemaining)
                    )
                    .frame(width: 240, height: 240)
                }

                if let activeId = appState.activeRuleSetId,
                    let setName = appState.ruleSets.first(where: { $0.id == activeId })?.name,
                    appState.pomodoroStatus == .focus
                {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(setName)
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct PomodoroActionButtons: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPomodoroChallenge: Bool

    var body: some View {
        VStack {
            if appState.pomodoroStatus == .none {
                Button(action: { appState.startPomodoro() }) {
                    Text("Start Focus Session")
                }
                .buttonStyle(
                    AppPrimaryButtonStyle(
                        color: FocusColor.color(for: appState.accentColorIndex),
                        maxWidth: .infinity
                    ))
            } else {
                HStack(spacing: 12) {
                    Button(action: { appState.skipPomodoroPhase() }) {
                        Label("Skip", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(
                        AppPrimaryButtonStyle(
                            color: FocusColor.color(for: appState.accentColorIndex),
                            maxWidth: .infinity
                        )
                    )
                    .disabled(appState.isPomodoroLocked)

                    Button(action: {
                        if appState.isPomodoroLocked {
                            showPomodoroChallenge = true
                        } else {
                            appState.stopPomodoro()
                        }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(
                        AppPrimaryButtonStyle(
                            color: .red,
                            maxWidth: .infinity
                        ))
                }
            }
        }
    }
}
