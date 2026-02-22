import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    var appState: AppState { actionAppState ?? environmentAppState }
    @State private var showChallenge = false
    @State private var challengeInput = ""

    init(
        initialShowChallenge: Bool = false,
        initialChallengeInput: String = "",
        actionAppState: AppState? = nil
    ) {
        self.actionAppState = actionAppState
        _showChallenge = State(initialValue: initialShowChallenge)
        _challengeInput = State(initialValue: initialChallengeInput)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(UIConstants.Typography.header)
                .padding(.horizontal)
                .padding(.top, 8)

            Form {
                Section {
                    if shouldShowStrictDisableButton {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unblockable Mode")
                                    .font(UIConstants.Typography.sectionLabel)
                                Text("Active and Locking Focus Mode.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Button("Disable...", action: openChallenge)
                                .buttonStyle(AppPrimaryButtonStyle(color: .orange))
                        }
                    } else {
                        Toggle(isOn: $environmentAppState.isUnblockable) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unblockable Mode")
                                    .font(UIConstants.Typography.sectionLabel)
                                Text("When active, you cannot disable Focus Mode.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                } header: {
                    Text("Strict Mode")
                        .font(UIConstants.Typography.header)
                }

                Section {
                    Toggle("Start week on Monday", isOn: $environmentAppState.weekStartsOnMonday)
                    Toggle(
                        "Enable Calendar Integration",
                        isOn: $environmentAppState.calendarIntegrationEnabled)
                } header: {
                    Text("Calendar")
                        .font(UIConstants.Typography.header)
                }

                Section {
                    Picker("Theme", selection: $environmentAppState.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        ForEach(0..<FocusColor.all.count, id: \.self) { index in
                            Circle()
                                .fill(FocusColor.all[index])
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.primary,
                                            lineWidth: appState.accentColorIndex == index ? 2 : 0
                                        )
                                        .padding(-3)
                                )
                                .contentShape(Circle())
                                .onTapGesture(perform: selectAccentColorAction(index: index))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance")
                        .font(UIConstants.Typography.header)
                }

                Section {
                    HStack {
                        Text("Version")
                            .font(UIConstants.Typography.sectionLabel)
                        Spacer()
                        Text("1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                        .font(UIConstants.Typography.header)
                }
            }
            .formStyle(.grouped)
        }
        .alert("Emergency Unlock", isPresented: $showChallenge) {
            TextField("Type the phrase exactly", text: $challengeInput)
            Button("Unlock", role: .destructive, action: unlockWithChallenge)
            Button("Cancel", role: .cancel, action: cancelUnlock)
        } message: {
            Text(
                "To disable Unblockable Mode, you must type the following exactly:\n\n\"\(AppState.challengePhrase)\""
            )
        }
    }

    var shouldShowStrictDisableButton: Bool {
        appState.isBlocking && appState.isUnblockable
    }

    func openChallenge() {
        showChallenge = true
    }

    func selectAccentColorAction(index: Int) -> () -> Void {
        { appState.accentColorIndex = index }
    }

    func unlockWithChallenge() {
        _ = appState.disableUnblockableWithChallenge(phrase: challengeInput)
        challengeInput = ""
    }

    func cancelUnlock() {
        challengeInput = ""
    }

    var showChallengeForTesting: Bool { showChallenge }
    var challengeInputForTesting: String { challengeInput }
}
