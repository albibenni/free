import Testing
@testable import FreeLogic

struct RuleMatcherTests {

    @Test("URL normalization logic")
    func normalization() {
        #expect(RuleMatcher.normalize("https://www.google.com/") == "google.com")
        #expect(RuleMatcher.normalize("http://google.com") == "google.com")
        #expect(RuleMatcher.normalize("www.google.com") == "google.com")
        #expect(RuleMatcher.normalize("GOOGLE.COM") == "google.com")
    }

    @Test("Exact URL matching")
    func exactMatch() {
        let rules = ["google.com"]
        #expect(RuleMatcher.isAllowed("https://google.com", rules: rules))
        #expect(RuleMatcher.isAllowed("https://www.google.com", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://facebook.com", rules: rules))
    }

    @Test("Wildcard URL matching")
    func wildcardMatch() {
        let rules = ["https://www.youtube.com/watch*"]
        #expect(RuleMatcher.isAllowed("https://www.youtube.com/watch?v=123", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://www.youtube.com/", rules: rules))
    }

    @Test("Internal browser schemes are always allowed")
    func internalSchemesAlwaysAllowed() {
        #expect(RuleMatcher.isAllowed("about:blank", rules: []))
        #expect(RuleMatcher.isAllowed("chrome://settings", rules: []))
        #expect(RuleMatcher.isAllowed("http://localhost:10000", rules: []))
    }

    @Test("Raw localhost block-page URLs are treated as internal")
    func localhostBlockPageVariants() {
        #expect(RuleMatcher.isAllowed("localhost:10000", rules: []))
        #expect(RuleMatcher.isAllowed("localhost:10000/focus", rules: []))
    }

    @Test("Invalid URLComponents input does not bypass allow checks")
    func invalidURLComponentsInput() {
        #expect(!RuleMatcher.isAllowed("http://%", rules: []))
    }

    @Test("Internal scheme tokens inside query/path do not bypass blocking")
    func internalSchemeBypassProtection() {
        let rules = ["github.com"]

        #expect(
            !RuleMatcher.isAllowed(
                "https://facebook.com/login?next=http://localhost:10000",
                rules: rules
            )
        )
        #expect(
            !RuleMatcher.isAllowed(
                "https://facebook.com/about:blank/profile",
                rules: rules
            )
        )
    }

    @Test("Prefix-based matching")
    func prefixMatch() {
        let rules = ["github.com/apple"]
        #expect(RuleMatcher.isAllowed("https://github.com/apple/swift", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://github.com/google/swift", rules: rules))
    }

    @Test("Subdomain matching logic")
    func subdomainMatching() {
        let rules = ["google.com"]
        // Core domain
        #expect(RuleMatcher.isAllowed("https://google.com", rules: rules))
        // Subdomain (should be allowed if parent domain is in rules)
        #expect(RuleMatcher.isAllowed("https://mail.google.com", rules: rules))
        #expect(RuleMatcher.isAllowed("https://docs.google.com/document/123", rules: rules))
    }

    @Test("Trailing slash and path normalization")
    func pathVariations() {
        let rules = ["example.com/work"]
        #expect(RuleMatcher.isAllowed("https://example.com/work/", rules: rules))
        #expect(RuleMatcher.isAllowed("https://example.com/work?user=1", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://example.com/working", rules: rules))
    }

    @Test("Handling empty rules and invalid URLs")
    func emptyAndInvalid() {
        #expect(RuleMatcher.isAllowed("", rules: ["google.com"]))
        #expect(!RuleMatcher.isAllowed("https://google.com", rules: []))
        #expect(RuleMatcher.isAllowed("about:blank", rules: []))
    }

    @Test("Complex subdomain and path matching")
    func complexMatching() {
        let rules = ["dev.example.co.uk/docs"]

        #expect(RuleMatcher.isAllowed("https://dev.example.co.uk/docs/api", rules: rules))
        #expect(RuleMatcher.isAllowed("http://www.dev.example.co.uk/docs", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://example.co.uk/docs", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://dev.example.co.uk/documentation", rules: rules))
    }

    @Test("Query parameters and fragments")
    func queryAndFragments() {
        let rules = ["youtube.com/watch?v=123"]

        #expect(RuleMatcher.isAllowed("https://www.youtube.com/watch?v=123", rules: rules))
        #expect(RuleMatcher.isAllowed("https://youtube.com/watch?v=123#t=10s", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://youtube.com/watch?v=456", rules: rules))
    }

    @Test("Multiple trailing slashes")
    func trailingSlashes() {
        let rules = ["example.com/work"]

        #expect(RuleMatcher.isAllowed("https://example.com/work///", rules: rules))
        #expect(RuleMatcher.isAllowed("https://example.com/work", rules: rules))
    }

    @Test("Advanced Wildcard patterns")
    func advancedWildcards() {
        // Prefix wildcard (handled by NSPredicate logic in RuleMatcher)
        let rules = ["*.google.com"]
        #expect(RuleMatcher.isAllowed("https://mail.google.com", rules: rules))
        #expect(RuleMatcher.isAllowed("https://google.com", rules: rules))

        // Middle wildcard
        let rules2 = ["github.com/*/settings"]
        #expect(RuleMatcher.isAllowed("https://github.com/apple/settings", rules: rules2))
        #expect(!RuleMatcher.isAllowed("https://github.com/apple/main", rules: rules2))
    }

    @Test("Case insensitivity exhaustive check")
    func caseInsensitivity() {
        let rules = ["GitHub.com/Apple"]
        #expect(RuleMatcher.isAllowed("https://GITHUB.COM/apple/Swift", rules: rules))
        #expect(RuleMatcher.isAllowed("https://github.com/APPLE", rules: rules))
    }

    @Test("Fragment and Query interaction in subdomain matching")
    func subdomainDelimiters() {
        let rules = ["example.com"]
        // Verify # and ? work as delimiters for subdomain-based rules
        #expect(RuleMatcher.isAllowed("https://sub.example.com#section", rules: rules))
        #expect(RuleMatcher.isAllowed("https://sub.example.com?query=1", rules: rules))
    }

    @Test("Internal scheme variety")
    func internalSchemes() {
        #expect(RuleMatcher.isAllowed("arc://extensions", rules: []))
        #expect(RuleMatcher.isAllowed("edge://history", rules: []))
        #expect(RuleMatcher.isAllowed("file:///Users/test/doc.pdf", rules: []))
    }

    @Test("YouTube specific matching edge cases")
    func youtubeEdgeCases() {
        let rules = ["youtube.com/watch?v=abc"]

        // Desktop
        #expect(RuleMatcher.isAllowed("https://www.youtube.com/watch?v=abc", rules: rules))
        // Mobile
        #expect(RuleMatcher.isAllowed("https://m.youtube.com/watch?v=abc", rules: rules))
        // Attribution / Features
        #expect(RuleMatcher.isAllowed("https://youtube.com/watch?v=abc&feature=emb_imp_woyt", rules: rules))
        // Shorts (Should NOT match a watch link unless rule uses wildcard)
        #expect(!RuleMatcher.isAllowed("https://youtube.com/shorts/abc", rules: rules))

        // Rule for Shorts
        let shortsRule = ["youtube.com/shorts/*"]
        #expect(RuleMatcher.isAllowed("https://www.youtube.com/shorts/123", rules: shortsRule))
    }

    @Test("Negative: Malformed URLs and Rules")
    func malformedRuleLogic() {
        // Just text, not a URL
        #expect(!RuleMatcher.isAllowed("just-some-text", rules: ["google.com"]))
        
        // Invalid protocol
        #expect(!RuleMatcher.isAllowed("ftp://google.com", rules: ["google.com"]))
        
        // Rule is just whitespace (should be ignored)
        #expect(!RuleMatcher.isAllowed("https://google.com", rules: ["   "]))
        
        // Rule is just a wildcard (blocks everything)
        #expect(RuleMatcher.isAllowed("https://google.com", rules: ["*"]))
    }

    @Test("Negative: RuleMatcher extreme edge cases")
    func ruleMatcherExtremeEdges() {
        // 1. URL is just protocol
        #expect(!RuleMatcher.isAllowed("https://", rules: ["google.com"]))
        
        // 2. Rule is just special characters (no domain)
        #expect(!RuleMatcher.isAllowed("https://google.com", rules: ["./?"]))
        
        // 3. Rule is empty string (already tested in emptyAndInvalid but verifying consistency)
        #expect(!RuleMatcher.isAllowed("https://google.com", rules: [""]))
    }

    @Test("Advanced URL formats: Ports and IPs")
    func advancedUrlFormats() {
        // Port matching
        let portRules = ["localhost:3000"]
        #expect(RuleMatcher.isAllowed("http://localhost:3000/dashboard", rules: portRules))
        #expect(!RuleMatcher.isAllowed("http://localhost:4000", rules: portRules))
        
        // IP Address matching
        let ipRules = ["127.0.0.1"]
        #expect(RuleMatcher.isAllowed("http://127.0.0.1/index.html", rules: ipRules))
        
        // IPv6 (Standard format)
        let ipv6Rules = ["http://[::1]"]
        #expect(RuleMatcher.isAllowed("http://[::1]/test", rules: ipv6Rules))
    }

    @Test("Percent encoding and special characters")
    func encodedUrls() {
        let rules = ["example.com/my page"]
        #expect(RuleMatcher.isAllowed("https://example.com/my%20page", rules: rules))
        
        let rules2 = ["example.com/tag/swift++"]
        #expect(RuleMatcher.isAllowed("https://example.com/tag/swift++", rules: rules2))
    }

    @Test("Multiple wildcards in one rule")
    func multiWildcards() {
        let rules = ["*google*"]
        #expect(RuleMatcher.isAllowed("https://google.it", rules: rules))
        #expect(RuleMatcher.isAllowed("https://sub.google.com/search", rules: rules))
        #expect(!RuleMatcher.isAllowed("https://yahoo.com", rules: rules))
    }

    @Test("Wildcard full-url fallback handles www patterns on full cleaned URL")
    func wildcardFullUrlFallback() {
        let rules = ["*www.*.example.com"]
        #expect(RuleMatcher.isAllowed("https://www.docs.example.com", rules: rules))
    }
}
