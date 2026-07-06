import Foundation

/// Single source of truth for "is this process a test runner?".
///
/// Covers the XCTest harness (environment markers, linked XCTestCase) and
/// SwiftPM's swift-testing helper (`swiftpm-testing-helper`), which links no
/// XCTest and sets no marker environment variables at all. This is a heuristic
/// to keep tests from touching real system state (modals, login items,
/// network listeners, app relocation) — it is not a security boundary.
enum TestProcessDetector {
    static func isRunningTests(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        processName: String = ProcessInfo.processInfo.processName,
        classLookup: (String) -> AnyClass? = NSClassFromString
    ) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES"] != nil { return true }
        if environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil { return true }
        if processName == "swiftpm-testing-helper" { return true }
        if processName.localizedCaseInsensitiveContains("xctest") { return true }
        return classLookup("XCTestCase") != nil
    }
}
