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
    @State private var showRules = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FocusView(showRules: $showRules)
            
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
            SheetWrapper(title: "Settings", isPresented: $showSettings) {
                SettingsView()
            }
            .frame(width: 400, height: 350)
        }
        .sheet(isPresented: $showRules) {
            SheetWrapper(title: "Allowed Websites", isPresented: $showRules) {
                RulesView()
            }
            .frame(width: 550, height: 650)
        }
    }
}

struct SheetWrapper<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: Content

    init(title: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            content
        }
    }
}

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
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

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var newRule: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(appState.allowedRules, id: \.self) { rule in
                    HStack {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(rule)
                            .font(.subheadline)
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
                    .padding(.vertical, 2)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.clear)

            HStack {
                TextField("Add URL to allow...", text: $newRule, onCommit: addRule)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 8) // Extra padding to clear rounded corners
                
                Button(action: addRule) {
                    Image(systemName: "plus")
                        .padding(.horizontal, 8)
                }
                .disabled(newRule.isEmpty)
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 8) // Extra padding to clear rounded corners
            }
            .padding(.bottom, 8)
        }
        .padding() // Main padding for the sheet content
    }

    func addRule() {
        let cleanedRule = newRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRule.isEmpty else { return }
        
        if !appState.allowedRules.contains(cleanedRule) {
            appState.allowedRules.append(cleanedRule)
        }
        
        DispatchQueue.main.async {
            self.newRule = ""
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showChallenge = false
    @State private var challengeInput = ""
    let challengePhrase = "I am choosing to break my focus and I acknowledge that this may impact my productivity."

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
                        .buttonStyle(.bordered)
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
                if challengeInput == challengePhrase {
                    appState.isUnblockable = false
                }
                challengeInput = ""
            }
            Button("Cancel", role: .cancel) { 
                challengeInput = ""
            }
        } message: {
            Text("To disable Unblockable Mode, you must type the following exactly:\n\n\"\(challengePhrase)\"")
        }
    }
}
