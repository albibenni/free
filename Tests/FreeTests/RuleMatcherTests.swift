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
}
