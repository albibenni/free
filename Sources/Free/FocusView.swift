import SwiftUI

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @Binding var showSchedules: Bool
    @State private var showCustomTimer = false
    @State private var customMinutesString = ""
    
    // Pomodoro Challenge
    @State private var showPomodoroChallenge = false
    @State private var pomodoroChallengeInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Permission Warning
            if !appState.isTrusted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("Accessibility Permission Needed")
                        .foregroundColor(.white)
                        .bold()
                    Spacer()
                    Button("Grant") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                    .foregroundColor(.black)
                    .padding(6)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }

            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.largeTitle)
                    .foregroundColor(appState.isBlocking && !appState.isPaused ? .green : .gray)
                VStack(alignment: .leading) {
                    Text("Focus Mode")
                        .font(.title2)
                        .bold()
                    Text(appState.isBlocking ? (appState.isPaused ? "Paused" : "Active") : "Inactive")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isBlocking },
                    set: { _ in appState.toggleBlocking() }
                ))
                    .toggleStyle(.switch)
                    .disabled(appState.isBlocking && appState.isUnblockable)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            if appState.isBlocking && appState.isUnblockable {
                Text("Unblockable mode is active. You cannot disable Focus Mode.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            // Pause / Break Dashboard
            if appState.isBlocking {
                if appState.isPaused {
                    VStack(spacing: 10) {
                        Text("On Break")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(appState.timeString(time: appState.pauseRemaining))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)

                        Button(action: { appState.cancelPause() }) {
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
                } else {
                    VStack(alignment: .leading) {
                        Text("Take a break:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("5m") { appState.startPause(minutes: 5) }
                            Button("15m") { appState.startPause(minutes: 15) }
                            Button("30m") { appState.startPause(minutes: 30) }
                            Button("Custom") { showCustomTimerInput() }
                        }
                    }
                }
            }

            // Pomodoro Widget
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.red)
                    Text("Pomodoro Mode")
                        .font(.headline)
                }

                if appState.pomodoroStatus == .none {
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            // Focus Clock
                            VStack(spacing: 12) {
                                PomodoroTimerView(
                                    durationMinutes: $appState.pomodoroFocusDuration,
                                    maxMinutes: 120,
                                    iconName: "tree.fill",
                                    title: "FOCUS",
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

                            // Break Clock
                            VStack(spacing: 12) {
                                PomodoroTimerView(
                                    durationMinutes: $appState.pomodoroBreakDuration,
                                    maxMinutes: 60,
                                    iconName: "cup.and.saucer.fill",
                                    title: "BREAK",
                                    color: .orange
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
                            
                            Toggle("Strict Mode", isOn: $appState.pomodoroDisableCalendar)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: appState.pomodoroStatus == .focus ? "tree.fill" : "cup.and.saucer.fill")
                                    .foregroundColor(appState.pomodoroStatus == .focus ? FocusColor.color(for: appState.accentColorIndex) : .orange)
                                Text(appState.pomodoroStatus == .focus ? "Focus Session" : "Break Time")
                                    .font(.headline)
                            }
                            
                            Text(appState.timeString(time: appState.pomodoroRemaining))
                                .font(.system(.title3, design: .monospaced))
                                .bold()
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { appState.skipPomodoroPhase() }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.isPomodoroLocked)
                            
                            Button(action: { 
                                if appState.isPomodoroLocked {
                                    showPomodoroChallenge = true
                                } else {
                                    appState.stopPomodoro()
                                }
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .alert("Emergency Unlock", isPresented: $showPomodoroChallenge) {
                TextField("Type the phrase exactly", text: $pomodoroChallengeInput)
                Button("Stop Pomodoro", role: .destructive) {
                    if pomodoroChallengeInput == AppState.challengePhrase {
                        // Bypass lock to stop
                        appState.pomodoroDisableCalendar = false
                        appState.stopPomodoro()
                    }
                    pomodoroChallengeInput = ""
                }
                Button("Cancel", role: .cancel) {
                    pomodoroChallengeInput = ""
                }
            } message: {
                Text("To stop a Strict Pomodoro session, you must type the following exactly:\n\n\"\(AppState.challengePhrase)\"")
            }

            // Schedules Widget (Card)
            Button(action: { showSchedules = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("Focus Schedules")
                            .font(.headline)
                        Spacer()
                        Text("\(appState.schedules.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if appState.schedules.isEmpty {
                        Text("No schedules set. Click to automate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.schedules.prefix(2)) { schedule in
                                HStack {
                                    Circle()
                                        .fill(schedule.isEnabled ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)
                                    Text(schedule.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if appState.schedules.count > 2 {
                                Text("and \(appState.schedules.count - 2) more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Rules Widget (Card)
            Button(action: { showRules = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Allowed Websites")
                            .font(.headline)
                        Spacer()
                        Text("\(appState.allowedRules.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if appState.allowedRules.isEmpty {
                        Text("No websites allowed. Click to add.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.allowedRules.prefix(3), id: \.self) { rule in
                                Text("• \(rule)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if appState.allowedRules.count > 3 {
                                Text("and \(appState.allowedRules.count - 3) more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .alert("Custom Break", isPresented: $showCustomTimer) {
            TextField("Minutes", text: $customMinutesString)
            Button("Start") {
                if let minutes = Double(customMinutesString) {
                    appState.startPause(minutes: minutes)
                }
                customMinutesString = ""
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter duration in minutes:")
        }
    }

    func showCustomTimerInput() {
        showCustomTimer = true
    }
}
