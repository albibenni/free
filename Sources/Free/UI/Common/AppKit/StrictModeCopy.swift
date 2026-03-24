import Foundation

enum StrictModeCopy {
    static let active = "Strict mode is active."

    static func active(withSuffix suffix: String?) -> String {
        guard let suffix else { return active }
        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuffix.isEmpty else { return active }
        return "\(active) \(trimmedSuffix)"
    }
}
