import AppKit

func resolvedAppKitCGColor(_ color: NSColor, appearance: NSAppearance?) -> CGColor {
    guard let appearance else { return color.cgColor }
    var resolvedColor = color.cgColor
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = color.cgColor
    }
    return resolvedColor
}

func appKitEmphasizedUnfocusColor(_ color: NSColor) -> NSColor {
    let warmed = color.blended(withFraction: 0.22, of: .systemOrange) ?? color
    guard let rgb = warmed.usingColorSpace(.deviceRGB) else { return warmed }

    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

    return NSColor(
        calibratedHue: hue,
        saturation: min(1, saturation * 1.18 + 0.08),
        brightness: min(1, brightness * 1.06 + 0.03),
        alpha: alpha
    )
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
