import SwiftUI

enum FreeAppSceneFactory {
    @SceneBuilder
    static func make(
        appState: AppState,
        menuStatusText: String,
        isQuitDisabled: Bool,
        menuIconColor: Color
    ) -> some Scene {
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
            Button("Quit", action: FreeAppRuntime.quitApplication)
                .disabled(isQuitDisabled)
        } label: {
            Image(systemName: "leaf.fill")
                .foregroundStyle(menuIconColor)
        }
    }
}
