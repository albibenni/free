import AppKit
import Foundation

@MainActor
enum AppKitSystemBridgeLiveSystemRuntime {
    private static let hookLock = NSLock()
    private static var nativeWorkspaceOpenForTesting: ((URL) -> Bool)?
    private static var isRunningUnderXCTestForTesting: (() -> Bool)?

    static func setNativeWorkspaceOpenForTesting(_ impl: ((URL) -> Bool)?) {
        hookLock.lock(); defer { hookLock.unlock() }; nativeWorkspaceOpenForTesting = impl
    }

    static func setIsRunningUnderXCTestForTesting(_ impl: (() -> Bool)?) {
        hookLock.lock(); defer { hookLock.unlock() }; isRunningUnderXCTestForTesting = impl
    }

    static func resetForTesting() {
        hookLock.lock(); defer { hookLock.unlock() }
        nativeWorkspaceOpenForTesting = nil
        isRunningUnderXCTestForTesting = nil
    }

    static func nativeWorkspaceOpen(_ url: URL) -> Bool {
        hookLock.lock()
        let impl = nativeWorkspaceOpenForTesting
        let isRunningImpl = isRunningUnderXCTestForTesting
        hookLock.unlock()
        if let impl = impl {
            return impl(url)
        }
        let isXCTest =
            isRunningImpl?()
            ?? (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
        if isXCTest {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
