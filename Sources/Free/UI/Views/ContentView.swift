import SwiftUI

enum MainContentSection: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case schedules = "Schedules"
    case allowedWebsites = "Allowed Websites"
    case pomodoro = "Pomodoro"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus:
            return "leaf.fill"
        case .schedules:
            return "calendar"
        case .allowedWebsites:
            return "lock.fill"
        case .pomodoro:
            return "timer"
        case .settings:
            return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSidebar = false
    @State private var selectedSection: MainContentSection = .focus
    @State private var showRules = false
    @State private var showSchedules = false

    init(
        initialShowSidebar: Bool = false,
        initialSection: MainContentSection = .focus,
        initialShowRules: Bool = false,
        initialShowSchedules: Bool = false
    ) {
        _showSidebar = State(initialValue: initialShowSidebar)
        _selectedSection = State(initialValue: initialSection)
        _showRules = State(initialValue: initialShowRules)
        _showSchedules = State(initialValue: initialShowSchedules)
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
            mainContent
        }
        .frame(minWidth: 900, minHeight: 800)
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
    private var mainContent: some View {
        switch selectedSection {
        case .settings:
            SettingsView()
        case .focus, .schedules, .allowedWebsites, .pomodoro:
            FocusView(
                showRules: $showRules,
                showSchedules: $showSchedules,
                section: focusSection(for: selectedSection)
            )
            .id(selectedSection.id)
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
                    ForEach(MainContentSection.allCases) { section in
                        sidebarItemButton(section)
                    }

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

    @ViewBuilder
    private func sidebarItemButton(_ section: MainContentSection) -> some View {
        Button(action: { selectedSection = section }) {
            Label(section.rawValue, systemImage: section.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selectedSection == section
                        ? Color.primary.opacity(0.12)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func focusSection(for section: MainContentSection) -> FocusContentSection {
        switch section {
        case .focus:
            return .all
        case .pomodoro:
            return .pomodoro
        case .schedules:
            return .schedules
        case .allowedWebsites:
            return .allowedWebsites
        case .settings:
            return .all
        }
    }

    func openSettings() {
        selectedSection = .settings
    }

    func openRules() {
        showRules = true
    }

    func toggleSettingsSidebar() {
        showSidebar.toggle()
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
    var showRulesForTesting: Bool { showRules }
    var selectedSectionForTesting: MainContentSection { selectedSection }
}
