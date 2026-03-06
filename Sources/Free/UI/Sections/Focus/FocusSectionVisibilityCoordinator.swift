import Foundation

enum FocusSectionVisibilityCoordinator {
    struct Visibility: Equatable {
        let shouldShowOverview: Bool
        let isWidgetContainerHidden: Bool
    }

    static func visibility(for section: FocusContentSection) -> Visibility {
        let shouldShowOverview = section == .all
        return Visibility(
            shouldShowOverview: shouldShowOverview,
            isWidgetContainerHidden: shouldShowOverview
        )
    }
}
