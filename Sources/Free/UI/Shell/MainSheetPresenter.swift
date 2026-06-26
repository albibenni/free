import AppKit

@MainActor
protocol RulesSheetPresenting: AnyObject {
    func present(for parentWindow: NSWindow, selectedRuleSetId: UUID?)
    func dismiss()
}

extension AllowedWebsitesSheetController: RulesSheetPresenting {}

@MainActor
final class MainSheetPresenter {
    typealias RulesSheetFactory = (_ onClose: @escaping () -> Void) -> any RulesSheetPresenting

    private let appState: AppState
    private let onRulesDismissed: () -> Void
    private let makeRulesSheetController: RulesSheetFactory

    private var rulesSheetController: (any RulesSheetPresenting)?

    init(
        appState: AppState,
        onRulesDismissed: @escaping () -> Void,
        makeRulesSheetController: RulesSheetFactory? = nil
    ) {
        self.appState = appState
        self.onRulesDismissed = onRulesDismissed
        self.makeRulesSheetController = makeRulesSheetController
            ?? { [appState] onClose in
                AllowedWebsitesSheetController(
                    appState: appState,
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
}
