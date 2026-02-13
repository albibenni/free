import XCTest
@testable import FreeLogic

final class RuleMatcherTests: XCTestCase {
    
    func testNormalization() {
        XCTAssertEqual(RuleMatcher.normalize("https://www.google.com/"), "google.com")
        XCTAssertEqual(RuleMatcher.normalize("http://google.com"), "google.com")
        XCTAssertEqual(RuleMatcher.normalize("www.google.com"), "google.com")
        XCTAssertEqual(RuleMatcher.normalize("GOOGLE.COM"), "google.com")
    }
    
    func testExactMatch() {
        let rules = ["google.com"]
        XCTAssertTrue(RuleMatcher.isAllowed("https://google.com", rules: rules))
        XCTAssertTrue(RuleMatcher.isAllowed("https://www.google.com", rules: rules))
        XCTAssertFalse(RuleMatcher.isAllowed("https://facebook.com", rules: rules))
    }
    
    func testWildcardMatch() {
        let rules = ["https://www.youtube.com/watch*"]
        XCTAssertTrue(RuleMatcher.isAllowed("https://www.youtube.com/watch?v=123", rules: rules))
        XCTAssertFalse(RuleMatcher.isAllowed("https://www.youtube.com/", rules: rules))
    }
    
    func testInternalSchemesAlwaysAllowed() {
        XCTAssertTrue(RuleMatcher.isAllowed("about:blank", rules: []))
        XCTAssertTrue(RuleMatcher.isAllowed("chrome://settings", rules: []))
        XCTAssertTrue(RuleMatcher.isAllowed("http://localhost:10000", rules: []))
    }
    
    func testPrefixMatch() {
        let rules = ["github.com/apple"]
        XCTAssertTrue(RuleMatcher.isAllowed("https://github.com/apple/swift", rules: rules))
        XCTAssertFalse(RuleMatcher.isAllowed("https://github.com/google/swift", rules: rules))
    }
}
