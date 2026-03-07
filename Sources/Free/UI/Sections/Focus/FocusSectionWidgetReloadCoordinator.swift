import AppKit

enum FocusSectionWidgetReloadCoordinator {
    enum WidgetKind {
        case none
        case pomodoro
        case schedules
        case allowedWebsites
        case other
    }

    struct Signatures {
        var pomodoro: FocusPomodoroWidgetSignature?
        var schedules: FocusSchedulesWidgetSignature?
        var allowedWebsites: FocusAllowedWebsitesWidgetSignature?
    }

    enum Operation {
        case reusePomodoro(FocusSectionWidgetCoordinator.PomodoroReuseAction)
        case keepExisting
        case rebuild(FocusSectionWidgetFactory.BuildResult)
    }

    struct Decision {
        let operation: Operation
        let signatures: Signatures
    }

    static func widgetKind(for widgetView: NSView?) -> WidgetKind {
        guard let widgetView else { return .none }
        if widgetView is FocusPomodoroWidgetView { return .pomodoro }
        if widgetView is FocusSchedulesWidgetView { return .schedules }
        if widgetView is FocusAllowedWebsitesWidgetView { return .allowedWebsites }
        return .other
    }

    static func decide(
        section: FocusContentSection,
        appState: AppState,
        shellState: FreeShellState,
        currentWidgetKind: WidgetKind,
        currentSignatures: Signatures,
        onPomodoroInteractionDidBegin: @escaping () -> Void,
        onPomodoroInteractionDidEnd: @escaping () -> Void
    ) -> Decision {
        var signatures = currentSignatures

        if section == .pomodoro, currentWidgetKind == .pomodoro {
            let nextSignature = FocusPomodoroWidgetSignature(appState: appState)
            let action = FocusSectionWidgetCoordinator.pomodoroReuseAction(
                current: signatures.pomodoro,
                next: nextSignature
            )
            signatures.pomodoro = nextSignature
            signatures.schedules = nil
            signatures.allowedWebsites = nil
            return Decision(
                operation: .reusePomodoro(action),
                signatures: signatures
            )
        } else if section != .pomodoro {
            signatures.pomodoro = nil
        }

        if section == .schedules, currentWidgetKind == .schedules {
            let nextSignature = FocusSchedulesWidgetSignature(appState: appState)
            if signatures.schedules == nextSignature {
                signatures.schedules = nextSignature
                signatures.allowedWebsites = nil
                return Decision(
                    operation: .keepExisting,
                    signatures: signatures
                )
            }
            signatures.schedules = nextSignature
        } else if section != .schedules {
            signatures.schedules = nil
        }

        if section == .allowedWebsites, currentWidgetKind == .allowedWebsites {
            let nextSignature = FocusAllowedWebsitesWidgetSignature(appState: appState)
            if signatures.allowedWebsites == nextSignature {
                signatures.allowedWebsites = nextSignature
                signatures.schedules = nil
                return Decision(
                    operation: .keepExisting,
                    signatures: signatures
                )
            }
            signatures.allowedWebsites = nextSignature
        } else if section != .allowedWebsites {
            signatures.allowedWebsites = nil
        }

        let buildResult = FocusSectionWidgetFactory.build(
            section: section,
            appState: appState,
            shellState: shellState,
            onPomodoroInteractionDidBegin: onPomodoroInteractionDidBegin,
            onPomodoroInteractionDidEnd: onPomodoroInteractionDidEnd
        )
        signatures.pomodoro = buildResult.pomodoroSignature
        signatures.schedules = buildResult.schedulesSignature
        signatures.allowedWebsites = buildResult.allowedWebsitesSignature

        return Decision(
            operation: .rebuild(buildResult),
            signatures: signatures
        )
    }
}
