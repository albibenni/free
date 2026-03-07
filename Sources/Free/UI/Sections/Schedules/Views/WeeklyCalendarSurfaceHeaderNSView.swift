import AppKit

final class WeeklyCalendarSurfaceHeaderNSView: NSView {
    private var dayOrder: [Int] = []
    private var weekRange: [Date] = []
    private var accentColor: NSColor = .controlAccentColor
    private var timeLabelWidth: CGFloat = 50
    private var timeColumnGutter: CGFloat = 10

    override var isFlipped: Bool { true }

    func configure(
        dayOrder: [Int],
        weekRange: [Date],
        accentColor: NSColor,
        timeLabelWidth: CGFloat,
        timeColumnGutter: CGFloat
    ) {
        self.dayOrder = dayOrder
        self.weekRange = weekRange
        self.accentColor = accentColor
        self.timeLabelWidth = timeLabelWidth
        self.timeColumnGutter = timeColumnGutter
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        let calendarX = timeLabelWidth + timeColumnGutter
        let columnWidth = max((bounds.width - calendarX) / 7, 1)
        let calendar = Calendar.current

        let weekdayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        let todayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.white,
        ]

        for (index, day) in dayOrder.enumerated() {
            let columnRect = CGRect(
                x: calendarX + CGFloat(index) * columnWidth,
                y: 0,
                width: columnWidth,
                height: bounds.height
            )

            let weekdayText = WeeklyCalendarSupport.dayName(for: day) as NSString
            let weekdaySize = weekdayText.size(withAttributes: weekdayAttributes)
            weekdayText.draw(
                at: CGPoint(
                    x: columnRect.midX - weekdaySize.width / 2,
                    y: 10
                ),
                withAttributes: weekdayAttributes
            )

            guard let date = weekRange.first(where: {
                calendar.component(.weekday, from: $0) == day
            }) else {
                continue
            }

            let dayString = "\(calendar.component(.day, from: date))" as NSString
            let isToday = calendar.isDateInToday(date)
            let badgeRect = CGRect(
                x: columnRect.midX - 14,
                y: 26,
                width: 28,
                height: 28
            )
            if isToday {
                let badgePath = NSBezierPath(ovalIn: badgeRect)
                accentColor.setFill()
                badgePath.fill()
            }

            let attributes = isToday ? todayAttributes : dayAttributes
            let daySize = dayString.size(withAttributes: attributes)
            dayString.draw(
                at: CGPoint(
                    x: badgeRect.midX - daySize.width / 2,
                    y: badgeRect.midY - daySize.height / 2
                ),
                withAttributes: attributes
            )
        }
    }
}
