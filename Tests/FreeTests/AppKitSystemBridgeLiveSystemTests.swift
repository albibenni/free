import AppKit
import Foundation
import Testing
@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AppKitSystemBridgeLiveSystemTests {
    final class ModalTestAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertSecondButtonReturn
        }
    }

    @Test("AppKitSystemBridgeLiveSystem openURL short-circuits under tests")
    @MainActor
    func openURLShortCircuitsUnderTests() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/system-short-circuit"))
        var called = false

        let result = AppKitSystemBridgeLiveSystem.openURL(url) { _ in
            called = true
            return true
        }

        #expect(result == false)
        #expect(called == false)
    }

    @Test("AppKitSystemBridgeLiveSystem runModal short-circuits under tests")
    @MainActor
    func runModalShortCircuitsUnderTests() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        var called = false

        let response = AppKitSystemBridgeLiveSystem.runModal(NSAlert()) { _ in
            called = true
            return .alertSecondButtonReturn
        }

        #expect(response == .alertFirstButtonReturn)
        #expect(called == false)
    }

    @Test("AppKitSystemBridgeLiveSystem fallback closures are used outside test runtime")
    @MainActor
    func fallbackClosuresAreUsedOutsideTestRuntime() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/system-pass-through"))
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }

        var openCalled = false
        let openResult = AppKitSystemBridgeLiveSystem.openURL(url) { incoming in
            openCalled = true
            return incoming == url
        }
        #expect(openCalled == true)
        #expect(openResult == true)

        var modalCalled = false
        let modalResult = AppKitSystemBridgeLiveSystem.runModal(NSAlert()) { _ in
            modalCalled = true
            return .alertSecondButtonReturn
        }
        #expect(modalCalled == true)
        #expect(modalResult == .alertSecondButtonReturn)
    }

    @Test("AppKitSystemBridgeLiveSystem live workspace and modal delegates use injected defaults")
    @MainActor
    func liveDelegatesUseInjectedDefaults() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/system-live"))
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting { incoming in incoming == url }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting { _ in .alertThirdButtonReturn }

        #expect(AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url) == true)
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(NSAlert()) == .alertThirdButtonReturn)
    }

    @Test("AppKitSystemBridgeLiveSystem reset clears delegate overrides")
    @MainActor
    func resetClearsDelegateOverrides() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/system-reset"))
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting { _ in true }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting { _ in .alertThirdButtonReturn }

        #expect(AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url) == true)
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(NSAlert()) == .alertThirdButtonReturn)

        AppKitSystemBridgeLiveSystem.resetForTesting()
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { true }
        #expect(AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url) == false)
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(NSAlert()) == .alertFirstButtonReturn)
    }

    @Test("AppKitSystemBridgeLiveSystem default workspace fallback executes")
    @MainActor
    func defaultWorkspaceFallbackExecutes() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystem.setNativeWorkspaceOpenForTesting { _ in false }
        let url = URL(fileURLWithPath: "/__free_coverage_nonexistent__/path")
        _ = AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url)
    }

    @Test("AppKitSystemBridgeLiveSystem default workspace native fallback path executes")
    @MainActor
    func defaultWorkspaceNativeFallbackPathExecutes() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setIsRunningUnderXCTestForTesting { true }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystem.setNativeWorkspaceOpenForTesting(nil)
        let url = URL(fileURLWithPath: "/tmp")
        #expect(AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url) == false)
    }

    @Test("AppKitSystemBridgeLiveSystem default runModal fallback executes")
    @MainActor
    func defaultRunModalFallbackExecutes() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting(nil)
        AppKitSystemBridgeLiveSystem.setNativeRunModalForTesting { _ in .alertSecondButtonReturn }
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(NSAlert()) == .alertSecondButtonReturn)
    }

    @Test("AppKitSystemBridgeLiveSystem default runModal native fallback path executes")
    @MainActor
    func defaultRunModalNativeFallbackPathExecutes() async throws {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting(nil)
        AppKitSystemBridgeLiveSystem.setNativeRunModalForTesting(nil)
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(ModalTestAlert()) == .alertSecondButtonReturn)
    }

    @Test("AppKitSystemBridgeLiveSystemRuntime uses injected native workspace opener")
    @MainActor
    func runtimeUsesInjectedNativeWorkspaceOpener() async throws {
        defer { AppKitSystemBridgeLiveSystemRuntime.resetForTesting() }

        var openedURL: URL?
        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting { url in
            openedURL = url
            return true
        }
        let url = URL(fileURLWithPath: "/__free_runtime_injected__/path")
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(url) == true)
        #expect(openedURL == url)
    }

    @Test("AppKitSystemBridgeLiveSystemRuntime returns false when XCTest runtime is forced")
    @MainActor
    func runtimeReturnsFalseWhenXCTestForced() async throws {
        defer { AppKitSystemBridgeLiveSystemRuntime.resetForTesting() }

        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting { true }
        let url = URL(fileURLWithPath: "/tmp")
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(url) == false)
    }

    @Test("AppKitSystemBridgeLiveSystemRuntime reset clears overrides")
    @MainActor
    func runtimeResetClearsOverrides() async throws {
        defer { AppKitSystemBridgeLiveSystemRuntime.resetForTesting() }

        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting { _ in true }
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting { false }
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(URL(fileURLWithPath: "/tmp")) == true)

        AppKitSystemBridgeLiveSystemRuntime.resetForTesting()
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting { true }
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(URL(fileURLWithPath: "/tmp")) == false)
    }

    @Test("AppKitSystemBridgeLiveSystemRuntime non-XCTest fallback executes native open path")
    @MainActor
    func runtimeNonXCTestFallbackExecutesNativeOpenPath() async throws {
        defer { AppKitSystemBridgeLiveSystemRuntime.resetForTesting() }

        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting { false }
        // Non-existent path is expected to return false and avoids opening Finder.
        let url = URL(fileURLWithPath: "/__free_runtime_nonexistent__/path")
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(url) == false)
    }

    @Test("AppKitSystemBridgeLiveSystemRuntime uses ProcessInfo XCTest fallback when hook is nil")
    @MainActor
    func runtimeUsesProcessInfoXCTestFallbackWhenHookNil() async throws {
        defer { AppKitSystemBridgeLiveSystemRuntime.resetForTesting() }

        AppKitSystemBridgeLiveSystemRuntime.setNativeWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystemRuntime.setIsRunningUnderXCTestForTesting(nil)
        // Non-existent path keeps this deterministic and side-effect free regardless of whether
        // XCTestConfigurationFilePath is present in this runner.
        let url = URL(fileURLWithPath: "/__free_runtime_processinfo_fallback__/missing")
        #expect(AppKitSystemBridgeLiveSystemRuntime.nativeWorkspaceOpen(url) == false)
    }
}
