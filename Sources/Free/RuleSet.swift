import Foundation

struct RuleSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urls: [String]
    
    static func defaultSet() -> RuleSet {
        return RuleSet(
            name: "Default",
            urls: ["https://www.youtube.com/watch?v=gmuTjeQUbTM"]
        )
    }
}
