import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showRules = false
    @State private var showSchedules = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FocusView(showRules: $showRules, showSchedules: $showSchedules)

            Button(action: { showSettings = true }) {
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
            SheetWrapper(title: "Settings", isPresented: $showSettings) {
                SettingsView()
            }
            .frame(width: 400, height: 350)
        }
        .sheet(isPresented: $showRules) {
            SheetWrapper(title: "Allowed Websites", isPresented: $showRules) {
                RulesView()
            }
            .frame(width: 550, height: 650)
        }
        .sheet(isPresented: $showSchedules) {
            SheetWrapper(title: "Schedules", isPresented: $showSchedules) {
                SchedulesView()
            }
            .frame(width: 750, height: 700)
        }
        .tint(FocusColor.color(for: appState.accentColorIndex))
    }
}