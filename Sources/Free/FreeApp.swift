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
        MenuBarExtra("Free", systemImage: "leaf.fill") {
            Button("Toggle Blocking") {
                appState.isBlocking.toggle()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
