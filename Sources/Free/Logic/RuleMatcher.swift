import Foundation

struct RuleMatcher {
    private static let internalSchemes: Set<String> = [
        "about", "arc", "chrome", "brave", "edge", "viva", "vivaldi", "opera", "file",
    ]


    static func isAllowed(_ url: String, rules: [String], localPort: UInt16? = nil) -> Bool {
        let cleanedUrl = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedUrl.isEmpty { return true }

        if isInternalBrowserUrl(cleanedUrl, localPort: localPort) { return true }

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

                let regexPattern = NSRegularExpression.escapedPattern(for: normalize(cleanedRule))
                    .replacingOccurrences(of: "\\*", with: ".*")
                    .replacingOccurrences(of: "\\?", with: ".")
                if let regex = try? Regex("^" + regexPattern + "$").ignoresCase() {
                    if normalizedUrl.contains(regex) { return true }
                }

                if cleanedRule.contains("://") || cleanedRule.contains("www.") {
                    let regexPattern = NSRegularExpression.escapedPattern(for: cleanedRule)
                        .replacingOccurrences(of: "\\*", with: ".*")
                        .replacingOccurrences(of: "\\?", with: ".")
                    if let regex = try? Regex("^" + regexPattern + "$").ignoresCase() {
                        if cleanedUrl.contains(regex) { return true }
                    }
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

    private static func isInternalBrowserUrl(_ rawUrl: String, localPort: UInt16?) -> Bool {
        let port = localPort ?? 10000
        if rawUrl == "localhost:\(port)" || rawUrl.hasPrefix("localhost:\(port)/") { return true }

        guard let components = URLComponents(string: rawUrl) else { return false }

        if let scheme = components.scheme, internalSchemes.contains(scheme) {
            return true
        }

        if let host = components.host?.lowercased(),
            ["localhost", "127.0.0.1", "::1"].contains(host),
            components.port == Int(port)
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
