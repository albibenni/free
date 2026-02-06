import SwiftUI

class AppState: ObservableObject {
    @Published var isBlocking = false
    @Published var isTrusted = false
    @Published var allowedRules: [String] = [
        "https://www.youtube.com/watch?v=gmuTjeQUbTM" // Example rule
    ]
    
    private var monitor: BrowserMonitor?
    
    init() {
        self.monitor = BrowserMonitor(appState: self)
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var newRule: String = ""

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
                Image(systemName: "shield.check.fill")
                    .font(.largeTitle)
                    .foregroundColor(appState.isBlocking ? .green : .gray)
                VStack(alignment: .leading) {
                    Text("Focus Mode")
                        .font(.title2)
                        .bold()
                    Text(appState.isBlocking ? "Active" : "Inactive")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $appState.isBlocking)
                    .toggleStyle(.switch)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

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
