import AppKit

final class MainSheetPresenter {
    private let appState: AppState
    private let onRulesDismissed: () -> Void
    private let onSchedulesDismissed: () -> Void

    private var rulesSheetController: AllowedWebsitesSheetController?
    private var schedulesSheetController: FreeSheetWindowController?

    init(
        appState: AppState,
        onRulesDismissed: @escaping () -> Void,
        onSchedulesDismissed: @escaping () -> Void
    ) {
        self.appState = appState
        self.onRulesDismissed = onRulesDismissed
        self.onSchedulesDismissed = onSchedulesDismissed
    }

    func presentRules(from parentWindow: NSWindow?) {
        guard let parentWindow else { return }
        if let rulesSheetController {
            rulesSheetController.present(
                for: parentWindow,
                selectedRuleSetId: appState.activeRuleSetId
            )
            return
        }

        let controller = AllowedWebsitesSheetController(
            appState: appState
        ) { [weak self] in
            self?.rulesSheetController = nil
            self?.onRulesDismissed()
        }
        rulesSheetController = controller
        controller.present(
            for: parentWindow,
            selectedRuleSetId: appState.activeRuleSetId
        )
    }

    func dismissRules() {
        guard let controller = rulesSheetController else { return }
        rulesSheetController = nil
        controller.dismiss()
    }

    func presentSchedules(from parentWindow: NSWindow?) {
        guard let parentWindow else { return }
        if let attachedSheet = parentWindow.attachedSheet,
           attachedSheet !== schedulesSheetController?.window
        {
            parentWindow.endSheet(attachedSheet)
            attachedSheet.orderOut(nil)
        }
        if let schedulesSheetController {
            schedulesSheetController.present(for: parentWindow)
            return
        }

        let schedulesController = SchedulesSheetViewController(appState: appState) { [weak self] in
            self?.onSchedulesDismissed()
        }
        let controller = FreeSheetWindowController(
            contentViewController: schedulesController,
            contentSize: CGSize(width: 750, height: 700),
            presentsAsSheet: false,
            showsNativeCloseButton: true
        ) { [weak self] in
            self?.schedulesSheetController = nil
            self?.onSchedulesDismissed()
        }
        schedulesSheetController = controller
        controller.present(for: parentWindow)
    }

    func dismissSchedules() {
        guard let controller = schedulesSheetController else { return }
        schedulesSheetController = nil
        controller.dismiss()
    }
}
