import SwiftUI

@main
struct FreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar) // Modern look
        .commands {
            // Add custom menu commands if needed
        }

        // Menu Bar Icon
        MenuBarExtra {
            Text(appState.isBlocking ? "Focus Mode: Active" : "Focus Mode: Inactive")
            
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .disabled(appState.isBlocking)
        } label: {
            Image(systemName: "leaf.fill")
                // Use foregroundStyle for modern SwiftUI color support
                .foregroundStyle(appState.isBlocking ? .green : .primary)
        }
    }
}
