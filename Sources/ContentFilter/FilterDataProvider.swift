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

    override func startFilter(completionHandler: @escaping @Sendable (Error?) -> Void) {
        // Empty rule list + defaultAction .filterData routes every flow to
        // handleNewFlow, where the allow/drop verdict is decided.
        let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
        let log = self.log  // Logger is Sendable; avoids capturing non-Sendable self.
        apply(settings) { error in
            if let error { log.error("startFilter failed: \(error.localizedDescription, privacy: .public)") }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping @Sendable () -> Void) {
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let snapshot = SharedRuleStore.snapshot()
        guard snapshot.isBlocking else {
            log.debug("flow allowed (not blocking)")
            return .allow()
        }

        guard let host = Self.hostname(for: flow) else {
            // DIAGNOSTIC: no hostname resolvable (likely a raw IP / QUIC flow).
            log.notice("flow: NO HOST resolvable → allowing")
            return .allow()
        }

        let allowed = RuleMatcher.isAllowed(host, rules: snapshot.allowedRules)
        log.notice("flow host=\(host, privacy: .public) blocking=true allowed=\(allowed) → \(allowed ? "ALLOW" : "DROP")")
        return allowed ? .allow() : .drop()
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
