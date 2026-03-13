import AppKit
import Foundation

enum AppKitSystemBridges {
    private static var _openURLImpl: ((URL) -> Void)?
    private static var _runModalImpl: ((NSAlert) -> NSApplication.ModalResponse)?
    private static var _isRunningInTestProcess: (() -> Bool)?
    private static var _nativeOpenURLImpl: ((URL) -> Bool)?
    private static var _nativeRunModalImpl: ((NSAlert) -> NSApplication.ModalResponse)?
    private static var _systemOpenURLExecutorOverride: ((URL) -> Bool)?
    private static var _systemRunModalExecutorOverride: ((NSAlert) -> NSApplication.ModalResponse)?
    private static var _systemOpenURLImpl: (URL) -> Bool = makeSystemOpenURLImpl()
    private static var _systemRunModalImpl: (NSAlert) -> NSApplication.ModalResponse = makeSystemRunModalImpl()

    static func openURL(_ url: URL) {
        (_openURLImpl ?? defaultOpenURLImpl)(url)
    }

    static func runModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        (_runModalImpl ?? defaultRunModalImpl)(alert)
    }

    static func setOpenURLForTesting(_ impl: ((URL) -> Void)?) {
        _openURLImpl = impl
    }

    static func setRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        _runModalImpl = impl
    }

    static func setIsRunningInTestProcessForTesting(_ impl: (() -> Bool)?) {
        _isRunningInTestProcess = impl
    }

    static func setNativeOpenURLForTesting(_ impl: ((URL) -> Bool)?) {
        _nativeOpenURLImpl = impl
    }

    static func setNativeRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        _nativeRunModalImpl = impl
    }

    static func setSystemOpenURLForTesting(_ impl: ((URL) -> Bool)?) {
        _systemOpenURLImpl = impl ?? makeSystemOpenURLImpl()
    }

    static func setSystemRunModalForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        _systemRunModalImpl = impl ?? makeSystemRunModalImpl()
    }

    static func setSystemOpenURLExecutorForTesting(_ impl: ((URL) -> Bool)?) {
        _systemOpenURLExecutorOverride = impl
    }

    static func setSystemRunModalExecutorForTesting(_ impl: ((NSAlert) -> NSApplication.ModalResponse)?) {
        _systemRunModalExecutorOverride = impl
    }

    static func resetForTesting() {
        _openURLImpl = nil
        _runModalImpl = nil
        _isRunningInTestProcess = nil
        _nativeOpenURLImpl = nil
        _nativeRunModalImpl = nil
        _systemOpenURLExecutorOverride = nil
        _systemRunModalExecutorOverride = nil
        _systemOpenURLImpl = makeSystemOpenURLImpl()
        _systemRunModalImpl = makeSystemRunModalImpl()
    }

    private static func defaultOpenURLImpl(_ url: URL) {
        if url.scheme == "x-free-test" || isRunningInTestProcess() {
            return
        }
        _ = nativeOpenURL(url)
    }

    private static func defaultRunModalImpl(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if isRunningInTestProcess() {
            return .alertFirstButtonReturn
        }
        return nativeRunModal(alert)
    }

    private static func isRunningInTestProcess() -> Bool {
        if let impl = _isRunningInTestProcess {
            return impl()
        }
        return AppDelegate.isRunningInTestProcess()
    }

    private static func makeSystemOpenURLImpl() -> (URL) -> Bool {
        { _systemOpenURLExecutor($0) }
    }

    private static func makeSystemRunModalImpl() -> (NSAlert) -> NSApplication.ModalResponse {
        { _systemRunModalExecutor($0) }
    }

    private static func _systemOpenURLExecutor(_ url: URL) -> Bool {
        if let impl = _systemOpenURLExecutorOverride {
            return impl(url)
        }
        return AppKitSystemBridgeLive.openURL(url)
    }

    private static func _systemRunModalExecutor(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let impl = _systemRunModalExecutorOverride {
            return impl(alert)
        }
        return AppKitSystemBridgeLive.runModal(alert)
    }

    private static func nativeOpenURL(_ url: URL) -> Bool {
        if let impl = _nativeOpenURLImpl {
            return impl(url)
        }
        return _systemOpenURLImpl(url)
    }

    private static func nativeRunModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let impl = _nativeRunModalImpl {
            return impl(alert)
        }
        return _systemRunModalImpl(alert)
    }
}
