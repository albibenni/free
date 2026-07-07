import Foundation

/// Status of the v2 content-filter system extension, surfaced in the UI so the
/// user knows whether the thing that actually enforces blocking is running.
/// v1 uses the Accessibility engine instead and never sets this.
public enum FilterStatus: Equatable, Sendable {
    case installing      // activation request submitted
    case needsApproval   // waiting for the user to approve in System Settings
    case active          // extension activated + NEFilterManager enabled
    case failed(String)  // activation failed (e.g. the macOS Tahoe sysextd bug)
}
