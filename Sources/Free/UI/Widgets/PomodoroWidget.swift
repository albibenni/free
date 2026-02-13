import SwiftUI

struct PomodoroWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPomodoroChallenge: Bool
    @Binding var pomodoroChallengeInput: String
    @State private var isExpanded = false
    
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
                VStack(alignment: .leading, spacing: 16) {
                    if appState.pomodoroStatus == .none {
                        pomodoroSetupView
                    } else {
                        pomodoroActiveView
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .alert("Emergency Unlock", isPresented: $showPomodoroChallenge) {
            TextField("Type the phrase exactly", text: $pomodoroChallengeInput)
            Button("Stop Pomodoro", role: .destructive) {
                if pomodoroChallengeInput == AppState.challengePhrase {
                    let wasUnblockable = appState.isUnblockable
                    appState.isUnblockable = false
                    appState.stopPomodoro()
                    appState.isUnblockable = wasUnblockable
                }
                pomodoroChallengeInput = ""
            }
            Button("Cancel", role: .cancel) {
                pomodoroChallengeInput = ""
            }
        } message: {
            Text("To stop a Strict Pomodoro session, you must type the following exactly:\n\n\"\(AppState.challengePhrase)\"")
        }
    }

    @ViewBuilder
    private var pomodoroSetupView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                Text("FOCUS")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.secondary)
                    .frame(width: 160)

                Text("BREAK")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.secondary)
                    .frame(width: 160)
            }
            .padding(.top, 10)

            HStack(spacing: 30) {
                VStack(spacing: 12) {
                    PomodoroTimerView(
                        durationMinutes: $appState.pomodoroFocusDuration,
                        maxMinutes: 120,
                        iconName: "leaf.fill",
                        title: "",
                        color: FocusColor.color(for: appState.accentColorIndex)
                    )
                    .frame(width: 160, height: 160)

                    HStack(spacing: 15) {
                        Button(action: { if appState.pomodoroFocusDuration > 5 { appState.pomodoroFocusDuration -= 5 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button(action: { if appState.pomodoroFocusDuration < 120 { appState.pomodoroFocusDuration += 5 } }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: 12) {
                    PomodoroTimerView(
                        durationMinutes: $appState.pomodoroBreakDuration,
                        maxMinutes: 60,
                        iconName: "cup.and.saucer.fill",
                        title: "",
                        color: FocusColor.color(for: appState.accentColorIndex)
                    )
                    .frame(width: 160, height: 160)

                    HStack(spacing: 15) {
                        Button(action: { if appState.pomodoroBreakDuration > 5 { appState.pomodoroBreakDuration -= 5 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button(action: { if appState.pomodoroBreakDuration < 60 { appState.pomodoroBreakDuration += 5 } }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 12) {
                Button(action: { appState.startPomodoro() }) {
                    Text("Start Focus Session")
                        .font(.headline)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(FocusColor.color(for: appState.accentColorIndex))
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var pomodoroActiveView: some View {
        VStack(spacing: 32) {
            let total = (appState.pomodoroStatus == .focus ? appState.pomodoroFocusDuration : appState.pomodoroBreakDuration) * 60
            
            VStack(spacing: 16) {
                Text(appState.pomodoroStatus == .focus ? "FOCUSING" : "BREAKING")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.secondary)

                ZStack {
                    PomodoroProgressView(
                        progress: appState.pomodoroRemaining / total,
                        iconName: appState.pomodoroStatus == .focus ? "leaf.fill" : "cup.and.saucer.fill",
                        title: "",
                        color: FocusColor.color(for: appState.accentColorIndex),
                        timeString: appState.timeString(time: appState.pomodoroRemaining)
                    )
                    .frame(width: 180, height: 180)
                }
                
                if let activeId = appState.activeRuleSetId,
                   let setName = appState.ruleSets.first(where: { $0.id == activeId })?.name,
                   appState.pomodoroStatus == .focus {
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
            
            HStack(spacing: 20) {
                Button(action: { appState.skipPomodoroPhase() }) {
                    Label("Skip", systemImage: "forward.end.fill")
                        .font(.headline)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .disabled(appState.isPomodoroLocked)
                
                Button(action: { 
                    if appState.isPomodoroLocked {
                        showPomodoroChallenge = true
                    } else {
                        appState.stopPomodoro()
                    }
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}