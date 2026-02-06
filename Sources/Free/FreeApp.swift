import SwiftUI

@main
struct FreeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar) // Modern look
        .commands {
            // Add custom menu commands if needed
        }

        // Menu Bar Icon
        MenuBarExtra {
            Button("Toggle Blocking") {
                appState.isBlocking.toggle()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "leaf.fill")
                // Use foregroundStyle for modern SwiftUI color support
                .foregroundStyle(appState.isBlocking ? .green : .primary)
        }
    }
}
