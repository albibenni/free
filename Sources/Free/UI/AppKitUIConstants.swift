import AppKit

enum AppKitUIConstants {
    enum Typography {
        static let header = NSFont.systemFont(ofSize: 16, weight: .bold)
        static let sectionLabel = NSFont.systemFont(ofSize: 14, weight: .semibold)
        static let regular = NSFont.systemFont(ofSize: 12, weight: .regular)

        static let cardTitle = NSFont.systemFont(ofSize: 17, weight: .semibold)
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let buttonLabel = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let helperLabel = NSFont.systemFont(ofSize: 11, weight: .bold)
    }

    enum CornerRadius {
        static let card: CGFloat = 12
        static let control: CGFloat = 8
        static let badge: CGFloat = 4
    }

    enum Spacing {
        static let cardPadding: CGFloat = 16
        static let cardStack: CGFloat = 14
        static let sectionStack: CGFloat = 8
        static let compact: CGFloat = 4
    }
}
