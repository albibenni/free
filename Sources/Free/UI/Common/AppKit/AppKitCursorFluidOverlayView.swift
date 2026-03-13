import AppKit
import WebKit

@MainActor
final class AppKitCursorFluidOverlayView: NSView, WKNavigationDelegate {

    private let webView: WKWebView
    private var didFinishInitialLoad = false
    private var pendingAccentColor: NSColor = .systemGreen
    private var pendingRainbowAccent = false

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

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.alphaValue = 0.92

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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishInitialLoad = true
        applyAccentIfPossible()
    }

    private func applyAccentIfPossible() {
        guard didFinishInitialLoad else { return }
        let srgb = pendingAccentColor.usingColorSpace(.deviceRGB) ?? pendingAccentColor
        let r = max(0, min(1, srgb.redComponent))
        let g = max(0, min(1, srgb.greenComponent))
        let b = max(0, min(1, srgb.blueComponent))
        let script = String(
            format: "window.setFluidAccent(%.6f, %.6f, %.6f, %@);",
            Double(r),
            Double(g),
            Double(b),
            pendingRainbowAccent ? "true" : "false"
        )
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}
