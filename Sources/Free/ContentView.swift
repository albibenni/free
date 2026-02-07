import SwiftUI

class AppState: ObservableObject {
    @Published var isBlocking = false {
        didSet {
            UserDefaults.standard.set(isBlocking, forKey: "IsBlocking")
            if !isBlocking { cancelPause() } // Reset pause if user manually turns off
        }
    }
    @Published var isUnblockable = false {
        didSet {
            UserDefaults.standard.set(isUnblockable, forKey: "IsUnblockable")
        }
    }
    @Published var isTrusted = false
    @Published var allowedRules: [String] = [] {
        didSet {
            UserDefaults.standard.set(allowedRules, forKey: "AllowedRules")
        }
    }
    
    // Pause / Timer Logic
    @Published var isPaused = false
    @Published var pauseRemaining: TimeInterval = 0
    private var pauseTimer: Timer?
    
    private var monitor: BrowserMonitor?
    
    init() {
        self.isBlocking = UserDefaults.standard.bool(forKey: "IsBlocking")
        self.isUnblockable = UserDefaults.standard.bool(forKey: "IsUnblockable")
        self.allowedRules = UserDefaults.standard.stringArray(forKey: "AllowedRules") ?? [
            "https://www.youtube.com/watch?v=gmuTjeQUbTM"
        ]
        self.monitor = BrowserMonitor(appState: self)
    }
    
    func startPause(minutes: Double) {
        guard isBlocking else { return }
        isPaused = true
        pauseRemaining = minutes * 60
        
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pauseRemaining > 0 {
                self.pauseRemaining -= 1
            } else {
                self.cancelPause()
            }
        }
    }

    func cancelPause() {
        isPaused = false
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
    
    func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FocusView()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(minWidth: 450, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showSettings = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                SettingsView()
            }
            .frame(width: 400, height: 350)
        }
    }
}

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @State private var newRule: String = ""
    @State private var showCustomTimer = false
    @State private var customMinutesString = ""

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
                Toggle("", isOn: $appState.isBlocking)
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

            Divider()

            // Rules Section
            Text("Allowed Websites")
                .font(.headline)
            
            Text("Everything is blocked EXCEPT these rules:")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(appState.allowedRules, id: \.self) { rule in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text(rule)
                        Spacer()
                        Button(action: {
                            if let index = appState.allowedRules.firstIndex(of: rule) {
                                appState.allowedRules.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            Divider()

            // Add Rule
            HStack {
                TextField("Enter URL to allow (e.g. google.com)", text: $newRule, onCommit: addRule)
                    .textFieldStyle(.roundedBorder)
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
                .disabled(newRule.isEmpty)
            }
            .padding(.bottom, 10)
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

    func addRule() {
        let cleanedRule = newRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRule.isEmpty else { return }
        
        if !appState.allowedRules.contains(cleanedRule) {
            appState.allowedRules.append(cleanedRule)
        }
        
        // Explicitly clear on main thread to ensure UI update
        DispatchQueue.main.async {
            self.newRule = ""
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
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
                .disabled(appState.isBlocking && appState.isUnblockable)
                
                if appState.isBlocking && appState.isUnblockable {
                    Text("You cannot disable Unblockable Mode while Focus Mode is active.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            } header: {
                Text("Strict Mode")
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
    }
}
