import AppKit

enum AppKitSystemBridgeLiveSystem {
    private static var isRunningInTestProcessForTesting: (() -> Bool)?
    private static var workspaceOpenForTesting: ((URL) -> Bool)?
    private static var runModalForTesting: ((NSAlert) -> NSApplication.ModalResponse)?

    static func openURL(_ url: URL, fallback: (URL) -> Bool) -> Bool {
        if isRunningInTestProcess() {
            return false
        }
        return fallback(url)
    }

    static func runModal(
        _ alert: NSAlert,
        fallback: (NSAlert) -> NSApplication.ModalResponse
    ) -> NSApplication.ModalResponse {
        if isRunningInTestProcess() {
            return .alertFirstButtonReturn
        }
        return fallback(alert)
    }

    static func setIsRunningInTestProcessForTesting(_ impl: (() -> Bool)?) {
        isRunningInTestProcessForTesting = impl
    }

    static func setWorkspaceOpenForTesting(_ impl: ((URL) -> Bool)?) {
        workspaceOpenForTesting = impl
    }

    static func setRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        runModalForTesting = impl
    }

    static func resetForTesting() {
        isRunningInTestProcessForTesting = nil
        workspaceOpenForTesting = nil
        runModalForTesting = nil
    }

    private static func isRunningInTestProcess() -> Bool {
        if let impl = isRunningInTestProcessForTesting {
            return impl()
        }
        return AppDelegate.isRunningInTestProcess()
    }

    static func liveWorkspaceOpen(_ url: URL) -> Bool {
        openURL(url, fallback: defaultWorkspaceOpen)
    }

    static func liveRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        runModal(alert, fallback: defaultRunModal)
    }

    private static func defaultWorkspaceOpen(_ url: URL) -> Bool {
        if let impl = workspaceOpenForTesting {
            return impl(url)
        }
        return NSWorkspace.shared.open(url)
    }

    private static func defaultRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let impl = runModalForTesting {
            return impl(alert)
        }
        return alert.runModal()
    }
}
