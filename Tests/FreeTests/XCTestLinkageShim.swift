// Linking XCTest makes SwiftPM host this suite in the xctest harness, where
// XCTestConfigurationFilePath and NSClassFromString("XCTestCase") are available.
// The production code's test-process detection (AppDelegate.isRunningInTestProcess
// and the per-view-controller copies) relies on those markers to suppress real
// modals, login-item registration, and app relocation during tests. Without this
// import the suite runs in swiftpm-testing-helper, every heuristic reports
// "not a test", and UI tests hang on real NSAlert.runModal() calls.
import XCTest
