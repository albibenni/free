import Combine

@MainActor
final class FreeShellState: ObservableObject {
    @Published var showSidebar = false
    @Published var selectedSection: MainContentSection = .focus
    @Published var showRules = false
    @Published var showSchedules = false
}
