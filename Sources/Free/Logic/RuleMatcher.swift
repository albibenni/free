import Foundation

struct RuleMatcher {
    private static let internalSchemes: Set<String> = [
        "about", "arc", "chrome", "brave", "edge", "viva", "vivaldi", "opera", "file",
    ]

    static func isAllowed(_ url: String, rules: [String]) -> Bool {
        let cleanedUrl = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedUrl.isEmpty { return true }

        if isInternalBrowserUrl(cleanedUrl) { return true }

        let normalizedUrl = normalize(cleanedUrl)

        for rule in rules {
            let cleanedRule = rule.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedRule.isEmpty { continue }

            if cleanedRule.contains("*") {
                if cleanedRule.hasPrefix("*.") {
                    let baseDomain = String(cleanedRule.dropFirst(2))
                    if normalizedUrl == normalize(baseDomain) { return true }
                }

                let baseRule = normalize(cleanedRule.replacingOccurrences(of: "*", with: ""))
                if !baseRule.isEmpty
                    && (normalizedUrl == baseRule || normalizedUrl.hasPrefix(baseRule + "/")
                        || normalizedUrl.hasPrefix(baseRule + "?")
                        || normalizedUrl.hasPrefix(baseRule + "#"))
                {
                    return true
                }

                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", normalize(cleanedRule))
                if predicate.evaluate(with: normalizedUrl) { return true }

                if cleanedRule.contains("://") || cleanedRule.contains("www.") {
                    let fullPredicate = NSPredicate(format: "SELF LIKE[cd] %@", cleanedRule)
                    if fullPredicate.evaluate(with: cleanedUrl) { return true }
                }
            } else {
                let normalizedRule = normalize(cleanedRule)

                if normalizedUrl == normalizedRule || cleanedUrl == cleanedRule { return true }

                if normalizedUrl.hasPrefix(normalizedRule + "/")
                    ||

                    normalizedUrl.hasPrefix(normalizedRule + "?")
                    ||

                    normalizedUrl.hasPrefix(normalizedRule + "#")
                    ||

                    normalizedUrl.hasPrefix(normalizedRule + "&")
                {

                    return true

                }

                if normalizedUrl.hasSuffix("." + normalizedRule)
                    ||

                    normalizedUrl.contains("." + normalizedRule + "/")
                    ||

                    normalizedUrl.contains("." + normalizedRule + "?")
                    ||

                    normalizedUrl.contains("." + normalizedRule + "#")
                    ||

                    normalizedUrl.contains("." + normalizedRule + "&")
                {

                    return true

                }

            }
        }
        return false
    }

    private static func isInternalBrowserUrl(_ rawUrl: String) -> Bool {
        if rawUrl == "localhost:10000" || rawUrl.hasPrefix("localhost:10000/") { return true }

        guard let components = URLComponents(string: rawUrl) else { return false }

        if let scheme = components.scheme, internalSchemes.contains(scheme) {
            return true
        }

        if let host = components.host?.lowercased(),
            ["localhost", "127.0.0.1", "::1"].contains(host),
            components.port == 10000
        {
            return true
        }

        return false
    }

    static func normalize(_ s: String) -> String {
        var out = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let decoded = out.removingPercentEncoding {
            out = decoded
        }

        if out.hasPrefix("https://") { out = String(out.dropFirst(8)) }
        if out.hasPrefix("http://") { out = String(out.dropFirst(7)) }
        if out.hasPrefix("www.") { out = String(out.dropFirst(4)) }

        if !out.contains("?") {
            while out.hasSuffix("/") { out = String(out.dropLast()) }
        }
        return out
    }
}
