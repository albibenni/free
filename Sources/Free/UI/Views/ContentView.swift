import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showRules = false
    @State private var showSchedules = false

    init(initialShowSettings: Bool = false, initialShowRules: Bool = false, initialShowSchedules: Bool = false) {
        _showSettings = State(initialValue: initialShowSettings)
        _showRules = State(initialValue: initialShowRules)
        _showSchedules = State(initialValue: initialShowSchedules)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FocusView(showRules: $showRules, showSchedules: $showSchedules)

            Button(action: openSettings) {
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
        .frame(minWidth: 800, minHeight: 800)
        .sheet(isPresented: $showSettings) {
            Self.settingsSheet(showSettings: $showSettings)
        }
        .sheet(isPresented: $showRules) {
            Self.rulesSheet(showRules: $showRules)
        }
        .sheet(isPresented: $showSchedules) {
            Self.schedulesSheet(showSchedules: $showSchedules)
        }
        .tint(Self.tintColor(accentColorIndex: appState.accentColorIndex))
        .preferredColorScheme(Self.preferredColorScheme(for: appState.appearanceMode))
    }

    func openSettings() {
        showSettings = true
    }

    static func makeShowSettingsAction(showSettings: Binding<Bool>) -> () -> Void {
        { showSettings.wrappedValue = true }
    }

    static func settingsSheet(showSettings: Binding<Bool>) -> some View {
        SheetWrapper(title: "Settings", isPresented: showSettings) {
            SettingsView()
        }
        .frame(width: 400, height: 350)
    }

    static func rulesSheet(showRules: Binding<Bool>) -> some View {
        SheetWrapper(title: "Allowed Websites", isPresented: showRules) {
            RulesView()
        }
        .frame(width: 700, height: 650)
    }

    static func schedulesSheet(showSchedules: Binding<Bool>) -> some View {
        SheetWrapper(title: "Schedules", isPresented: showSchedules) {
            SchedulesView()
        }
        .frame(width: 750, height: 700)
    }

    static func tintColor(accentColorIndex: Int) -> Color {
        FocusColor.color(for: accentColorIndex)
    }

    static func preferredColorScheme(for mode: AppearanceMode) -> ColorScheme? {
        mode.colorScheme
    }
}
