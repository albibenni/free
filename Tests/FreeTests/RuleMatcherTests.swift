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
}
