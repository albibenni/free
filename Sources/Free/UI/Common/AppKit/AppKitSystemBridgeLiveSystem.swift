import AppKit

@MainActor
enum AppKitSystemBridgeLiveSystem {
    private static var isRunningInTestProcessForTesting: (() -> Bool)?
    private static var workspaceOpenForTesting: ((URL) -> Bool)?
    private static var runModalForTesting: ((NSAlert) -> NSApplication.ModalResponse)?
    private static var nativeRunModalForTesting: ((NSAlert) -> NSApplication.ModalResponse)?

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

    static func setIsRunningUnderXCTestForTesting(_ impl: (() -> Bool)?) {
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting(impl)
    }

    static func setRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        runModalForTesting = impl
    }

    static func setNativeWorkspaceOpenForTesting(_ impl: ((URL) -> Bool)?) {
        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting(impl)
    }

    static func setNativeRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        nativeRunModalForTesting = impl
    }

    static func resetForTesting() {
        isRunningInTestProcessForTesting = nil
        workspaceOpenForTesting = nil
        runModalForTesting = nil
        nativeRunModalForTesting = nil
        AppKitSystemBridgeLiveSystemRuntime.resetForTesting()
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
        return defaultNativeWorkspaceOpen(url)
    }

    private static func defaultRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let impl = runModalForTesting {
            return impl(alert)
        }
        if let nativeRunModal = nativeRunModalForTesting {
            return nativeRunModal(alert)
        }
        return alert.runModal()
    }

    private static func defaultNativeWorkspaceOpen(_ url: URL) -> Bool {
        AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(url)
    }
}
