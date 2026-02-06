import SwiftUI

class AppState: ObservableObject {
    @Published var isBlocking = false {
        didSet {
            UserDefaults.standard.set(isBlocking, forKey: "IsBlocking")
            if !isBlocking { cancelPause() } // Reset pause if user manually turns off
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
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
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
                ForEach(Array(appState.allowedRules.enumerated()), id: \.element) { index, rule in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text(rule)
                        Spacer()
                        Button(action: {
                            appState.allowedRules.remove(at: index)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle()) // Clickable icon only
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            // Add Rule
            HStack {
                TextField("Enter URL to allow (e.g. google.com)", text: $newRule, onCommit: addRule)
                    .textFieldStyle(.roundedBorder)
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
                .disabled(newRule.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
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
        guard !newRule.isEmpty else { return }
        // Prevent duplicates
        if !appState.allowedRules.contains(newRule) {
            appState.allowedRules.append(newRule)
        }
        newRule = ""
    }
}
