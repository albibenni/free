import AppKit

protocol RulesSheetPresenting: AnyObject {
    func present(for parentWindow: NSWindow, selectedRuleSetId: UUID?)
    func dismiss()
}

extension AllowedWebsitesSheetController: RulesSheetPresenting {}

protocol SchedulesSheetPresenting: AnyObject {
    var window: NSWindow? { get }
    func present(for parentWindow: NSWindow)
    func dismiss()
}

extension FreeSheetWindowController: SchedulesSheetPresenting {}

final class MainSheetPresenter {
    typealias RulesSheetFactory = (_ onClose: @escaping () -> Void) -> any RulesSheetPresenting
    typealias SchedulesSheetFactory = (_ onClose: @escaping () -> Void) -> any SchedulesSheetPresenting

    private let appState: AppState
    private let onRulesDismissed: () -> Void
    private let onSchedulesDismissed: () -> Void
    private let makeRulesSheetController: RulesSheetFactory
    private let makeSchedulesSheetController: SchedulesSheetFactory

    private var rulesSheetController: (any RulesSheetPresenting)?
    private var schedulesSheetController: (any SchedulesSheetPresenting)?

    init(
        appState: AppState,
        onRulesDismissed: @escaping () -> Void,
        onSchedulesDismissed: @escaping () -> Void,
        makeRulesSheetController: RulesSheetFactory? = nil,
        makeSchedulesSheetController: SchedulesSheetFactory? = nil
    ) {
        self.appState = appState
        self.onRulesDismissed = onRulesDismissed
        self.onSchedulesDismissed = onSchedulesDismissed
        self.makeRulesSheetController = makeRulesSheetController
            ?? { [appState] onClose in
                AllowedWebsitesSheetController(
                    appState: appState,
                    onClose: onClose
                )
            }
        self.makeSchedulesSheetController = makeSchedulesSheetController
            ?? { [appState] onClose in
                let schedulesController = SchedulesSheetViewController(appState: appState) {
                    onClose()
                }
                return FreeSheetWindowController(
                    contentViewController: schedulesController,
                    contentSize: CGSize(width: 750, height: 700),
                    presentsAsSheet: false,
                    showsNativeCloseButton: true,
                    onClose: onClose
                )
            }
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

        let controller = makeRulesSheetController { [weak self] in
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

        let controller = makeSchedulesSheetController { [weak self] in
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
