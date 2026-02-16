import SwiftUI

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @Binding var showSchedules: Bool
    
    // Pomodoro Challenge (Owned by FocusView to coordinate with widget)
    @State private var showPomodoroChallenge = false
    @State private var pomodoroChallengeInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionWarning
            headerView
            
            if appState.isBlocking && appState.isUnblockable {
                Text("Unblockable mode is active. You cannot disable Focus Mode.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            pauseDashboard
            PomodoroWidget(
                showPomodoroChallenge: $showPomodoroChallenge,
                pomodoroChallengeInput: $pomodoroChallengeInput
            )
            SchedulesWidget(showSchedules: $showSchedules)
            AllowedWebsitesWidget(showRules: $showRules)

            Spacer()
        }
        .padding()
    }

    // MARK: - Subviews
    
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
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.largeTitle)
                .foregroundColor(appState.isBlocking && !appState.isPaused ? .green : .gray)
            VStack(alignment: .leading) {
                Text("Focus Mode")
                    .font(.title2)
                    .bold()
                HStack(spacing: 4) {
                    Text(appState.isBlocking ? (appState.isPaused ? "Paused" : "Active") : "Inactive")
                    if appState.isBlocking && !appState.isPaused {
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
            }
        }
    }
}
