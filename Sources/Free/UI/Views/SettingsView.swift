import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showChallenge = false
    @State private var challengeInput = ""

    var body: some View {
        Form {
            Section {
                if appState.isBlocking && appState.isUnblockable {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unblockable Mode")
                                .font(.headline)
                            Text("Active and Locking Focus Mode.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Button("Disable...") {
                            showChallenge = true
                        }
                        .buttonStyle(AppPrimaryButtonStyle(color: .orange))
                    }
                } else {
                    Toggle(isOn: $appState.isUnblockable) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unblockable Mode")
                                .font(.headline)
                            Text("When active, you cannot disable Focus Mode.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            } header: {
                Text("Strict Mode")
            }

            Section {
                Toggle("Start week on Monday", isOn: $appState.weekStartsOnMonday)
                Toggle("Enable Calendar Integration", isOn: $appState.calendarIntegrationEnabled)
            } header: {
                Text("Calendar")
            }

            Section {
                HStack(spacing: 12) {
                    ForEach(0..<FocusColor.all.count, id: \.self) { index in
                        Circle()
                            .fill(FocusColor.all[index])
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: appState.accentColorIndex == index ? 2 : 0)
                                    .padding(-3)
                            )
                            .contentShape(Circle())
                            .onTapGesture {
                                appState.accentColorIndex = index
                            }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Appearance")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .alert("Emergency Unlock", isPresented: $showChallenge) {
            TextField("Type the phrase exactly", text: $challengeInput)
            Button("Unlock", role: .destructive) {
                if challengeInput == AppState.challengePhrase {
                    appState.isUnblockable = false
                }
                challengeInput = ""
            }
            Button("Cancel", role: .cancel) {
                challengeInput = ""
            }
        } message: {
            Text("To disable Unblockable Mode, you must type the following exactly:\n\n\"\(AppState.challengePhrase)\"")
        }
    }
}
