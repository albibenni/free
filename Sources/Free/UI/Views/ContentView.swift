import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var showRules = false
    @State private var showSchedules = false

    init(
        initialShowSidebar: Bool = false,
        initialShowSettings: Bool = false,
        initialShowRules: Bool = false,
        initialShowSchedules: Bool = false
    ) {
        _showSidebar = State(initialValue: initialShowSidebar)
        _showSettings = State(initialValue: initialShowSettings)
        _showRules = State(initialValue: initialShowRules)
        _showSchedules = State(initialValue: initialShowSchedules)
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
            FocusView(showRules: $showRules, showSchedules: $showSchedules)
        }
        .frame(minWidth: 900, minHeight: 800)
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
        .onAppear {
            applyMacOSAppearance(appState.appearanceMode)
        }
        .onChange(of: appState.appearanceMode) { _, mode in
            applyMacOSAppearance(mode)
        }
    }

    @ViewBuilder
    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: toggleSettingsSidebar) {
                    Image(systemName: showSidebar ? "sidebar.left" : "sidebar.right")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.secondary)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if showSidebar {
                    Text("Menu")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(12)

            if showSidebar {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: openRules) {
                        Label("Rules", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button(action: openSettings) {
                        Label("Settings", systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(12)
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                Spacer()
            }
        }
        .frame(width: showSidebar ? 180 : 56)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: showSidebar)
    }

    func openSettings() {
        showSettings = true
    }

    func openRules() {
        showRules = true
    }

    func toggleSettingsSidebar() {
        showSidebar.toggle()
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

    static func nsAppearance(for mode: AppearanceMode) -> NSAppearance? {
        switch mode {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    func applyMacOSAppearance(_ mode: AppearanceMode) {
        NSApp?.appearance = Self.nsAppearance(for: mode)
    }

    var isSidebarVisibleForTesting: Bool { showSidebar }
    var showSettingsForTesting: Bool { showSettings }
    var showRulesForTesting: Bool { showRules }
}
