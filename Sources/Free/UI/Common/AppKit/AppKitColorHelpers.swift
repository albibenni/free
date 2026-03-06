import AppKit

func resolvedAppKitCGColor(_ color: NSColor, appearance: NSAppearance?) -> CGColor {
    guard let appearance else { return color.cgColor }
    var resolvedColor = color.cgColor
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = color.cgColor
    }
    return resolvedColor
}

func resolvedAppKitCGColor(
    _ colorProvider: @escaping () -> NSColor?,
    appearance: NSAppearance?
) -> CGColor? {
    guard let appearance else { return colorProvider()?.cgColor }
    var resolvedColor: CGColor?
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = colorProvider()?.cgColor
    }
    return resolvedColor
}
