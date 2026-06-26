import AppKit
import Foundation
import Testing
@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AppKitSystemBridgesTests {
    @Test("AppKitSystemBridges uses injected openURL implementation")
    @MainActor
    func openURLUsesInjectedImplementation() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        var opened: [URL] = []
        AppKitSystemBridges.setOpenURLForTesting { opened.append($0) }
        let url = try #require(URL(string: "https://example.com/bridge"))
        AppKitSystemBridges.openURL(url)
        #expect(opened == [url])
    }

    @Test("AppKitSystemBridges default openURL implementation is test-safe")
    @MainActor
    func openURLDefaultImplementationCoverage() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setOpenURLForTesting(nil)
        let testURL = try #require(URL(string: "x-free-test://noop"))
        AppKitSystemBridges.openURL(testURL)
    }

    @Test("AppKitSystemBridges uses injected runModal implementation")
    @MainActor
    func runModalUsesInjectedImplementation() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting { _ in .alertSecondButtonReturn }
        let response = AppKitSystemBridges.runModal(NSAlert())
        #expect(response == .alertSecondButtonReturn)
    }

    @Test("AppKitSystemBridges default runModal implementation is test-safe")
    @MainActor
    func runModalDefaultImplementationCoverage() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting(nil)
        let response = AppKitSystemBridges.runModal(NSAlert())
        #expect(response == .alertFirstButtonReturn)
    }

    @Test("AppKitSystemBridges default openURL calls native bridge outside test runtime")
    @MainActor
    func defaultOpenURLUsesNativeBridgeWhenNotTesting() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        let expected = try #require(URL(string: "https://example.com/native"))
        var received: URL?
        AppKitSystemBridges.setOpenURLForTesting(nil)
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridges.setNativeOpenURLForTesting { url in
            received = url
            return true
        }

        AppKitSystemBridges.openURL(expected)
        #expect(received == expected)
    }

    @Test("AppKitSystemBridges default runModal calls native bridge outside test runtime")
    @MainActor
    func defaultRunModalUsesNativeBridgeWhenNotTesting() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting(nil)
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }
        AppKitSystemBridges.setNativeRunModalForTesting { _ in .alertSecondButtonReturn }

        let response = AppKitSystemBridges.runModal(NSAlert())
        #expect(response == .alertSecondButtonReturn)
    }

    @Test("AppKitSystemBridges openURL native fallback uses system bridge")
    @MainActor
    func openURLNativeFallbackUsesSystemBridge() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        let expected = try #require(URL(string: "https://example.com/system"))
        var received: URL?
        AppKitSystemBridges.setOpenURLForTesting(nil)
        AppKitSystemBridges.setNativeOpenURLForTesting(nil)
        AppKitSystemBridges.setSystemOpenURLForTesting(nil)
        AppKitSystemBridges.setSystemOpenURLExecutorForTesting { url in
            received = url
            return true
        }
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }

        AppKitSystemBridges.openURL(expected)
        #expect(received == expected)
    }

    @Test("AppKitSystemBridges runModal native fallback uses system bridge")
    @MainActor
    func runModalNativeFallbackUsesSystemBridge() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting(nil)
        AppKitSystemBridges.setNativeRunModalForTesting(nil)
        AppKitSystemBridges.setSystemRunModalForTesting(nil)
        AppKitSystemBridges.setSystemRunModalExecutorForTesting { _ in .alertThirdButtonReturn }
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }

        let response = AppKitSystemBridges.runModal(NSAlert())
        #expect(response == .alertThirdButtonReturn)
    }

    @Test("AppKitSystemBridges openURL can run with live system executor in tests")
    @MainActor
    func openURLFallbackUsesLiveExecutorSafelyInTests() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        let url = try #require(URL(string: "https://example.com/live"))
        AppKitSystemBridges.setOpenURLForTesting(nil)
        AppKitSystemBridges.setNativeOpenURLForTesting(nil)
        AppKitSystemBridges.setSystemOpenURLExecutorForTesting(nil)
        AppKitSystemBridges.setSystemOpenURLForTesting(nil)
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }

        AppKitSystemBridges.openURL(url)
    }

    @Test("AppKitSystemBridges runModal can run with live system executor in tests")
    @MainActor
    func runModalFallbackUsesLiveExecutorSafelyInTests() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting(nil)
        AppKitSystemBridges.setNativeRunModalForTesting(nil)
        AppKitSystemBridges.setSystemRunModalExecutorForTesting(nil)
        AppKitSystemBridges.setSystemRunModalForTesting(nil)
        AppKitSystemBridges.setIsRunningInTestProcessForTesting { false }

        let response = AppKitSystemBridges.runModal(NSAlert())
        #expect(response == .alertFirstButtonReturn)
    }

    @Test("AppKitSystemBridges resetForTesting clears custom hooks")
    @MainActor
    func resetForTestingClearsHooks() async throws {
        defer { AppKitSystemBridges.resetForTesting() }

        AppKitSystemBridges.setRunModalForTesting { _ in .alertThirdButtonReturn }
        #expect(AppKitSystemBridges.runModal(NSAlert()) == .alertThirdButtonReturn)

        AppKitSystemBridges.resetForTesting()
        #expect(AppKitSystemBridges.runModal(NSAlert()) == .alertFirstButtonReturn)
    }
}
