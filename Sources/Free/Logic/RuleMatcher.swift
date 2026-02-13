import Foundation

struct RuleMatcher {
    static func isAllowed(_ url: String, rules: [String]) -> Bool {
        let cleanedUrl = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedUrl.isEmpty { return true }
        
        let internalSchemes = ["about:", "arc:", "chrome:", "brave:", "edge:", "viva:", "opera:", "file:", "localhost:10000"]
        for scheme in internalSchemes {
            if cleanedUrl.contains(scheme) { return true }
        }

        let normalizedUrl = normalize(cleanedUrl)

        for rule in rules {
            let cleanedRule = rule.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedRule.isEmpty { continue }

            if cleanedRule.contains("*") {
                let baseRule = normalize(cleanedRule.replacingOccurrences(of: "*", with: ""))
                if normalizedUrl == baseRule || normalizedUrl.hasPrefix(baseRule + "/") || normalizedUrl.hasPrefix(baseRule + "?") {
                    return true
                }
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", cleanedRule)
                if predicate.evaluate(with: cleanedUrl) { return true }
            } else {
                let normalizedRule = normalize(cleanedRule)
                
                // Exact Match (Crucial for YouTube links)
                if normalizedUrl == normalizedRule || cleanedUrl == cleanedRule { return true }
                
                // Prefix Match
                if normalizedUrl.hasPrefix(normalizedRule + "/") || normalizedUrl.hasPrefix(normalizedRule + "?") {
                    return true
                }
                
                // Substring containment as last resort
                if normalizedUrl.contains(normalizedRule) { return true }
            }
        }
        return false
    }

    static func normalize(_ s: String) -> String {
        var out = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if out.hasPrefix("https://") { out = String(out.dropFirst(8)) }
        if out.hasPrefix("http://") { out = String(out.dropFirst(7)) }
        if out.hasPrefix("www.") { out = String(out.dropFirst(4)) }
        
        // Only strip trailing slash if NOT a YouTube/Query URL to preserve IDs
        if !out.contains("?") {
            while out.hasSuffix("/") { out = String(out.dropLast()) }
        }
        return out
    }
}
