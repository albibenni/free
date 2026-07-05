import Observation

@MainActor
@Observable
final class FreeShellState {
    var showSidebar = false
    var selectedSection: MainContentSection = .focus
    var showRules = false
    var showSchedules = false
}
