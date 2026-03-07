import AppKit

final class WeeklyCalendarSurfaceNSView: NSView {
    private let headerView = WeeklyCalendarSurfaceHeaderNSView()
    private let scrollView = NSScrollView()
    private let documentView = WeeklyCalendarSurfaceDocumentNSView()
    private var configuration: WeeklyCalendarSurfaceConfiguration?
    private var didInitialScroll = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )
        layer?.masksToBounds = true

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView

        addSubview(headerView)
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with configuration: WeeklyCalendarSurfaceConfiguration) {
        self.configuration = configuration
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )
        headerView.configure(
            dayOrder: configuration.dayOrder,
            weekRange: configuration.weekRange,
            accentColor: configuration.accentColor,
            timeLabelWidth: configuration.timeLabelWidth,
            timeColumnGutter: configuration.timeColumnGutter
        )
        documentView.configure(with: configuration)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let configuration else { return }

        let headerHeight = max(configuration.dayHeaderHeight + 20, 56)
        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        scrollView.frame = CGRect(
            x: 0,
            y: headerHeight,
            width: bounds.width,
            height: max(bounds.height - headerHeight, 0)
        )

        let contentWidth = max(
            scrollView.contentSize.width,
            configuration.timeLabelWidth + configuration.timeColumnGutter + 7
        )
        let contentHeight = 24 * configuration.hourHeight
        let documentFrame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        let needsDocumentLayout = documentView.frame.size != documentFrame.size
        documentView.frame = documentFrame
        if needsDocumentLayout {
            documentView.applyCurrentLayout()
        }

        if !didInitialScroll {
            scrollToCurrentTime(hourHeight: configuration.hourHeight)
            didInitialScroll = true
        }
    }

    private func scrollToCurrentTime(hourHeight: CGFloat) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetHour = max(0, currentHour - 2)
        let point = CGPoint(x: 0, y: CGFloat(targetHour) * hourHeight)
        scrollView.contentView.scroll(to: point)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

extension WeeklyCalendarSurfaceNSView {
    var documentHeightForTesting: CGFloat { documentView.frame.height }
    var headerHeightForTesting: CGFloat { headerView.frame.height }
    var hasVerticalScrollerForTesting: Bool { scrollView.hasVerticalScroller }
    var didInitialScrollForTesting: Bool { didInitialScroll }
    var scheduleBlockCountForTesting: Int { documentView.scheduleBlockCountForTesting }
}
