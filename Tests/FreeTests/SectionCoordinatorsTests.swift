import Foundation
import Testing

@testable import FreeLogic

struct SectionCoordinatorsTests {
    @Test("Focus interaction coordinator gates deferred and flush reloads")
    func focusInteractionReloadCoordinator() {
        #expect(
            FocusInteractionReloadCoordinator.shouldDeferObservedChange(
                section: .pomodoro,
                interactionDepth: 1
            )
        )
        #expect(
            !FocusInteractionReloadCoordinator.shouldDeferObservedChange(
                section: .all,
                interactionDepth: 1
            )
        )
        #expect(
            FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
                interactionDepth: 0,
                needsReloadAfterInteraction: true
            )
        )
        #expect(
            !FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
                interactionDepth: 1,
                needsReloadAfterInteraction: true
            )
        )
    }

    @Test("Schedules presentation coordinator derives title and week navigation")
    func schedulesSheetPresentationCoordinator() {
        #expect(
            SchedulesSheetPresentationCoordinator.windowTitle(viewMode: 1) == "Schedules · Calendar"
        )
        #expect(
            SchedulesSheetPresentationCoordinator.windowTitle(viewMode: 0) == "Schedules · List"
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .previous
            ) == 1
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .current
            ) == 0
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .next
            ) == 3
        )
    }
}
