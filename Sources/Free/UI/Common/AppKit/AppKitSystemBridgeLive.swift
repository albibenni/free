import AppKit

@MainActor
enum AppKitSystemBridgeLive {
    private static var isRunningInTestProcessImpl: (() -> Bool)?
    private static var workspaceOpenImpl: ((URL) -> Bool)?
    private static var alertRunModalImpl: ((NSAlert) -> NSApplication.ModalResponse)?

    static func openURL(_ url: URL) -> Bool {
        if isRunningInTestProcess() {
            return false
        }
        return openURLInWorkspace(url)
    }

    static func runModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if isRunningInTestProcess() {
            return .alertFirstButtonReturn
        }
        return runModalOnAlert(alert)
    }

    static func setIsRunningInTestProcessForTesting(_ impl: (() -> Bool)?) {
        isRunningInTestProcessImpl = impl
    }

    static func setWorkspaceOpenForTesting(_ impl: ((URL) -> Bool)?) {
        workspaceOpenImpl = impl
    }

    static func setAlertRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        alertRunModalImpl = impl
    }

    static func resetForTesting() {
        isRunningInTestProcessImpl = nil
        workspaceOpenImpl = nil
        alertRunModalImpl = nil
    }

    private static func isRunningInTestProcess() -> Bool {
        if let impl = isRunningInTestProcessImpl {
            return impl()
        }
        return AppDelegate.isRunningInTestProcess()
    }

    private static func openURLInWorkspace(_ url: URL) -> Bool {
        if let impl = workspaceOpenImpl {
            return impl(url)
        }
        return AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url)
    }

    private static func runModalOnAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let impl = alertRunModalImpl {
            return impl(alert)
        }
        return AppKitSystemBridgeLiveSystem.liveRunModal(alert)
    }
}
