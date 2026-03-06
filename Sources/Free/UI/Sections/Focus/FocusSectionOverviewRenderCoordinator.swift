import Foundation

enum FocusSectionOverviewRenderCoordinator {
    static let emptyStateText = "No active schedule, allow list, or pomodoro session."

    struct RenderModel: Equatable {
        let rows: [FocusSectionOverviewCoordinator.Row]
        let emptyStateText: String?
    }

    static func renderModel(appState: AppState) -> RenderModel {
        let rows = FocusSectionOverviewCoordinator.rows(appState: appState)
        return RenderModel(
            rows: rows,
            emptyStateText: rows.isEmpty ? emptyStateText : nil
        )
    }
}
