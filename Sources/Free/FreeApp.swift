import SwiftUI

#if !SWIFT_PACKAGE
@main
#endif
struct FreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState

    init() {
        let defaults = UserDefaults.standard
        let state = AppState(defaults: defaults)
        _appState = StateObject(wrappedValue: state)
    }

    init(appState: AppState) {
        _appState = StateObject(wrappedValue: appState)
    }

    var menuStatusText: String {
        appState.isBlocking ? "Focus Mode: Active" : "Focus Mode: Inactive"
    }

    var isQuitDisabled: Bool {
        appState.isBlocking
    }

    var menuIconColor: Color {
        appState.isBlocking ? .green : .primary
    }

    var body: some Scene {
        FreeAppSceneFactory.make(
            appState: appState,
            menuStatusText: menuStatusText,
            isQuitDisabled: isQuitDisabled,
            menuIconColor: menuIconColor
        )
    }
}
