import Foundation

enum FocusInteractionReloadCoordinator {
    static func shouldDeferObservedChange(
        section: FocusContentSection,
        interactionDepth: Int
    ) -> Bool {
        section == .pomodoro && interactionDepth > 0
    }

    static func shouldFlushDeferredReload(
        interactionDepth: Int,
        needsReloadAfterInteraction: Bool
    ) -> Bool {
        interactionDepth == 0 && needsReloadAfterInteraction
    }
}
