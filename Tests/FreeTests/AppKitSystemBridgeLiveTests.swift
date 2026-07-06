import AppKit
import Foundation
import Testing
@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AppKitSystemBridgeLiveTests {
    @Test("AppKitSystemBridgeLive openURL returns false during test runtime")
    @MainActor
    func openURLReturnsFalseWhenTesting() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/testing"))
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { true }

        #expect(AppKitSystemBridgeLive.openURL(url) == false)
    }

    @Test("AppKitSystemBridgeLive openURL uses workspace bridge outside test runtime")
    @MainActor
    func openURLUsesWorkspaceBridgeWhenNotTesting() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        let expected = try #require(URL(string: "https://example.com/workspace"))
        var received: URL?
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setWorkspaceOpenForTesting { url in
            received = url
            return true
        }

        #expect(AppKitSystemBridgeLive.openURL(expected) == true)
        #expect(received == expected)
    }

    @Test("AppKitSystemBridgeLive runModal returns first button during test runtime")
    @MainActor
    func runModalReturnsFirstButtonWhenTesting() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { true }

        #expect(AppKitSystemBridgeLive.runModal(NSAlert()) == .alertFirstButtonReturn)
    }

    @Test("AppKitSystemBridgeLive runModal uses alert bridge outside test runtime")
    @MainActor
    func runModalUsesAlertBridgeWhenNotTesting() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setAlertRunModalForTesting { _ in .alertThirdButtonReturn }

        #expect(AppKitSystemBridgeLive.runModal(NSAlert()) == .alertThirdButtonReturn)
    }

    @Test("AppKitSystemBridgeLive resetForTesting clears overrides")
    @MainActor
    func resetForTestingClearsOverrides() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/reset"))
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setWorkspaceOpenForTesting { _ in true }
        #expect(AppKitSystemBridgeLive.openURL(url) == true)

        AppKitSystemBridgeLive.resetForTesting()
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { true }
        #expect(AppKitSystemBridgeLive.openURL(url) == false)
    }

    @Test("AppKitSystemBridgeLive uses default detector path under tests")
    @MainActor
    func usesDefaultDetectorPath() async throws {
        defer { AppKitSystemBridgeLive.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/default-detector"))
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting(nil)
        #expect(AppKitSystemBridgeLive.openURL(url) == false)
    }

    @Test("AppKitSystemBridgeLive uses default workspace fallback safely")
    @MainActor
    func usesDefaultWorkspaceFallbackSafely() async throws {
        defer {
            AppKitSystemBridgeLive.resetForTesting()
            AppKitSystemBridgeLiveSystem.resetForTesting()
        }

        let url = try #require(URL(string: "https://example.com/default-workspace"))
        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting { _ in false }
        #expect(AppKitSystemBridgeLive.openURL(url) == false)
    }

    @Test("AppKitSystemBridgeLive uses default runModal fallback safely")
    @MainActor
    func usesDefaultRunModalFallbackSafely() async throws {
        defer {
            AppKitSystemBridgeLive.resetForTesting()
            AppKitSystemBridgeLiveSystem.resetForTesting()
        }

        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setAlertRunModalForTesting(nil)
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting { _ in .alertFirstButtonReturn }
        #expect(AppKitSystemBridgeLive.runModal(NSAlert()) == .alertFirstButtonReturn)
    }

    @Test("AppKitSystemBridgeLive live workspace fallback delegates to system bridge")
    @MainActor
    func liveWorkspaceFallbackDelegatesToSystemBridge() async throws {
        defer {
            AppKitSystemBridgeLive.resetForTesting()
            AppKitSystemBridgeLiveSystem.resetForTesting()
        }

        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setWorkspaceOpenForTesting(nil)
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setWorkspaceOpenForTesting { _ in true }
        let url = URL(fileURLWithPath: "/__free_coverage_safe__/path")
        #expect(AppKitSystemBridgeLive.openURL(url) == true)
    }

    @Test("AppKitSystemBridgeLive live runModal fallback delegates to system bridge")
    @MainActor
    func liveRunModalFallbackDelegatesToSystemBridge() async throws {
        defer {
            AppKitSystemBridgeLive.resetForTesting()
            AppKitSystemBridgeLiveSystem.resetForTesting()
        }

        AppKitSystemBridgeLive.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLive.setAlertRunModalForTesting(nil)
        AppKitSystemBridgeLiveSystem.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridgeLiveSystem.setRunModalForTesting { _ in .alertSecondButtonReturn }
        #expect(AppKitSystemBridgeLive.runModal(NSAlert()) == .alertSecondButtonReturn)
    }
}
