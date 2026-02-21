import SwiftUI

enum FreeAppSceneFactory {
    static func quitAction() -> () -> Void {
        FreeAppRuntime.quitApplication
    }

    @SceneBuilder
    static func make(
        appState: AppState,
        menuStatusText: String,
        isQuitDisabled: Bool,
        menuIconColor: Color
    ) -> some Scene {
#if SWIFT_PACKAGE
        MenuBarExtra {
            Text(menuStatusText)
            Divider()
            Button("Quit", action: quitAction())
                .disabled(isQuitDisabled)
        } label: {
            Image(systemName: "leaf.fill")
                .foregroundStyle(menuIconColor)
        }
#else
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
            .windowStyle(.hiddenTitleBar)
            .commands {}

        MenuBarExtra {
            Text(menuStatusText)
            Divider()
            Button("Quit", action: quitAction())
                .disabled(isQuitDisabled)
        } label: {
            Image(systemName: "leaf.fill")
                .foregroundStyle(menuIconColor)
        }
#endif
    }
}
