import AppKit
import WebKit

@MainActor
final class AppKitCursorFluidOverlayView: NSView, WKNavigationDelegate {

    private let webView: WKWebView
    private var didFinishInitialLoad = false
    private var pendingAccentColor: NSColor = .systemGreen
    private var pendingRainbowAccent = false
    private var isAnimationActive = true
    private var lastAppliedAccentKey: String?
    private var lastAppliedAnimationState: Bool?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didResignActiveObserver: NSObjectProtocol?

    static func makeIfSupported() -> AppKitCursorFluidOverlayView? {
        AppKitCursorFluidOverlayView()
    }

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = false

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        setup()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    // Keep overlay fully click-through so underlying AppKit UI remains interactive.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        observeAppLifecycle()

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .clear
        webView.alphaValue = 0.5

        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        webView.loadHTMLString(AppKitFluid.html, baseURL: nil)
    }

    func setAccentColorIndex(_ index: Int) {
        pendingRainbowAccent = FocusColor.isRainbowAccentIndex(index)
        pendingAccentColor = pendingRainbowAccent ? .systemPink : FocusColor.nsColor(for: index)
        applyAccentIfPossible()
    }

    func setAnimationActive(_ isActive: Bool) {
        isAnimationActive = isActive
        applyAnimationStateIfPossible()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishInitialLoad = true
        applyAccentIfPossible()
        applyAnimationStateIfPossible()
    }

    private func applyAccentIfPossible() {
        guard didFinishInitialLoad else { return }
        let srgb = pendingAccentColor.usingColorSpace(.deviceRGB)
            ?? NSColor(deviceRed: 0.20, green: 0.80, blue: 0.30, alpha: 1.0)
        let r = max(0, min(1, srgb.redComponent))
        let g = max(0, min(1, srgb.greenComponent))
        let b = max(0, min(1, srgb.blueComponent))
        let accentKey = String(
            format: "%.4f-%.4f-%.4f-%@",
            Double(r),
            Double(g),
            Double(b),
            pendingRainbowAccent ? "1" : "0"
        )
        guard accentKey != lastAppliedAccentKey else { return }
        lastAppliedAccentKey = accentKey

        let script = String(
            format: "window.setFluidAccent(%.6f, %.6f, %.6f, %@);",
            Double(r),
            Double(g),
            Double(b),
            pendingRainbowAccent ? "true" : "false"
        )
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func applyAnimationStateIfPossible() {
        guard didFinishInitialLoad else { return }
        guard lastAppliedAnimationState != isAnimationActive else { return }
        lastAppliedAnimationState = isAnimationActive
        webView.evaluateJavaScript(
            "window.setFluidRunning(\(isAnimationActive ? "true" : "false"));",
            completionHandler: nil
        )
    }

    private func observeAppLifecycle() {
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setAnimationActive(true)
            }
        }
        didResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setAnimationActive(false)
            }
        }
        isAnimationActive = NSApplication.shared.isActive
    }

    isolated deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let didResignActiveObserver {
            NotificationCenter.default.removeObserver(didResignActiveObserver)
        }
    }
}

extension AppKitCursorFluidOverlayView {
    func setPendingAccentForTesting(color: NSColor, rainbow: Bool, didFinishInitialLoad: Bool) {
        pendingAccentColor = color
        pendingRainbowAccent = rainbow
        self.didFinishInitialLoad = didFinishInitialLoad
    }

    func applyAccentIfPossibleForTesting() {
        applyAccentIfPossible()
    }

    func setAnimationActiveForTesting(_ isActive: Bool, didFinishInitialLoad: Bool) {
        isAnimationActive = isActive
        self.didFinishInitialLoad = didFinishInitialLoad
    }

    func applyAnimationStateIfPossibleForTesting() {
        applyAnimationStateIfPossible()
    }
}
