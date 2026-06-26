import AppKit
import Foundation

@MainActor
enum FocusSectionWidgetFactory {
    struct BuildResult {
        let widgetView: NSView?
        let pomodoroSignature: FocusPomodoroWidgetSignature?
        let schedulesSignature: FocusSchedulesWidgetSignature?
        let allowedWebsitesSignature: FocusAllowedWebsitesWidgetSignature?
    }

    static func build(
        section: FocusContentSection,
        appState: AppState,
        shellState: FreeShellState,
        onPomodoroInteractionDidBegin: @escaping () -> Void,
        onPomodoroInteractionDidEnd: @escaping () -> Void
    ) -> BuildResult {
        switch section {
        case .pomodoro:
            return BuildResult(
                widgetView: FocusPomodoroWidgetView(
                    appState: appState,
                    onDialInteractionDidBegin: onPomodoroInteractionDidBegin,
                    onDialInteractionDidEnd: onPomodoroInteractionDidEnd
                ),
                pomodoroSignature: FocusPomodoroWidgetSignature(appState: appState),
                schedulesSignature: nil,
                allowedWebsitesSignature: nil
            )
        case .schedules:
            return BuildResult(
                widgetView: FocusSchedulesWidgetView(appState: appState, shellState: shellState),
                pomodoroSignature: nil,
                schedulesSignature: FocusSchedulesWidgetSignature(appState: appState),
                allowedWebsitesSignature: nil
            )
        case .allowedWebsites:
            return BuildResult(
                widgetView: FocusAllowedWebsitesWidgetView(appState: appState, shellState: shellState),
                pomodoroSignature: nil,
                schedulesSignature: nil,
                allowedWebsitesSignature: FocusAllowedWebsitesWidgetSignature(appState: appState)
            )
        case .all:
            return BuildResult(
                widgetView: nil,
                pomodoroSignature: nil,
                schedulesSignature: nil,
                allowedWebsitesSignature: nil
            )
        }
    }
}
