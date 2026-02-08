import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if UserDefaults.standard.bool(forKey: "IsBlocking") {
            // Show alert explaining why
            let alert = NSAlert()
            alert.messageText = "Focus Mode is Active"
            alert.informativeText = "You must disable Focus Mode before quitting the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
struct FreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            Button(appState.isBlocking ? "Turn Off Focus" : "Turn On Focus") {
                appState.toggleBlocking()
            }
            .disabled(appState.isBlocking && appState.isUnblockable)
            
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
