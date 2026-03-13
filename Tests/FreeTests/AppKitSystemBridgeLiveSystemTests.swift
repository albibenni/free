import AppKit
import Foundation
import Testing
@testable import FreeLogic

@Suite(.serialized)
struct AppKitSystemBridgeLiveSystemTests {
    final class ModalTestAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertSecondButtonReturn
        }
    }

    @Test("AppKitSystemBridgeLiveSystem openURL short-circuits under tests")
    @MainActor
    func openURLShortCircuitsUnderTests() throws {
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
    func runModalShortCircuitsUnderTests() {
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
    func fallbackClosuresAreUsedOutsideTestRuntime() throws {
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
    func liveDelegatesUseInjectedDefaults() throws {
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
    func resetClearsDelegateOverrides() throws {
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
    func defaultWorkspaceFallbackExecutes() {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting(nil)
        let url = URL(fileURLWithPath: "/__free_coverage_nonexistent__/path")
        _ = AppKitSystemBridgeLiveSystem.liveWorkspaceOpen(url)
    }

    @Test("AppKitSystemBridgeLiveSystem default runModal fallback executes")
    @MainActor
    func defaultRunModalFallbackExecutes() {
        defer { AppKitSystemBridgeLiveSystem.resetForTesting() }

        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting(nil)
        #expect(AppKitSystemBridgeLiveSystem.liveRunModal(ModalTestAlert()) == .alertSecondButtonReturn)
    }
}
