import NetworkExtension
import Network
import FreeLogic
import os

/// v2 blocking engine: a system-extension content filter that returns an
/// allow/drop verdict per network flow, using the same `RuleMatcher` and the
/// rules the main app publishes into the shared App Group.
///
/// Replaces the v1 AppleScript polling engine (`BrowserMonitor`) — no polling,
/// no per-browser scripting, works system-wide, and is App-Sandbox-compatible.
final class FilterDataProvider: NEFilterDataProvider {
    private let log = Logger(subsystem: "com.benni.Free.ContentFilter", category: "filter")

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        // Empty rule list + defaultAction .filterData routes every flow to
        // handleNewFlow, where the allow/drop verdict is decided.
        let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
        apply(settings) { error in
            if let error { self.log.error("startFilter failed: \(error.localizedDescription, privacy: .public)") }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let snapshot = SharedRuleStore.snapshot()
        guard snapshot.isBlocking else { return .allow() }

        guard let host = Self.hostname(for: flow) else { return .allow() }

        // Reuse the existing matcher: a hostname the rules allow → allow, else drop.
        if RuleMatcher.isAllowed(host, rules: snapshot.allowedRules) {
            return .allow()
        }
        return .drop()
    }

    private static func hostname(for flow: NEFilterFlow) -> String? {
        // macOS content filters see socket flows (no browser flows as on iOS).
        if let url = flow.url {
            return url.host ?? url.absoluteString
        }
        if let socketFlow = flow as? NEFilterSocketFlow,
           let endpoint = socketFlow.remoteFlowEndpoint,
           case let .hostPort(host, _) = endpoint {
            return "\(host)"
        }
        return nil
    }
}
