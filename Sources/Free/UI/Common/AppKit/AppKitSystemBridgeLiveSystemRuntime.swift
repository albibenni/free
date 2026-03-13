import AppKit
import Foundation

enum AppKitSystemBridgeLiveSystemRuntime {
    private static var nativeWorkspaceOpenForTesting: ((URL) -> Bool)?
    private static var isRunningUnderXCTestForTesting: (() -> Bool)?

    static func setNativeWorkspaceOpenForTesting(_ impl: ((URL) -> Bool)?) {
        nativeWorkspaceOpenForTesting = impl
    }

    static func setIsRunningUnderXCTestForTesting(_ impl: (() -> Bool)?) {
        isRunningUnderXCTestForTesting = impl
    }

    static func resetForTesting() {
        nativeWorkspaceOpenForTesting = nil
        isRunningUnderXCTestForTesting = nil
    }

    static func nativeWorkspaceOpen(_ url: URL) -> Bool {
        if let impl = nativeWorkspaceOpenForTesting {
            return impl(url)
        }
        let isXCTest =
            isRunningUnderXCTestForTesting?()
            ?? (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
        if isXCTest {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
