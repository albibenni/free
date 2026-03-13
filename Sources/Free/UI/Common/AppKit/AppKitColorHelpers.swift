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

func appKitAccentGradientColors(
    for accentColor: NSColor,
    topAlpha: CGFloat,
    bottomAlpha: CGFloat
) -> [NSColor] {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return [
            NSColor.systemPink.withAlphaComponent(topAlpha),
            NSColor.systemBlue.withAlphaComponent(bottomAlpha),
        ]
    }
    return [
        accentColor.withAlphaComponent(topAlpha),
        accentColor.withAlphaComponent(bottomAlpha),
    ]
}

func appKitAccentBorderColor(for accentColor: NSColor, alpha: CGFloat) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return NSColor.systemPurple.withAlphaComponent(alpha)
    }
    return accentColor.withAlphaComponent(alpha)
}

func appKitAccentForegroundColor(for accentColor: NSColor) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return NSColor.white.withAlphaComponent(0.95)
    }
    return accentColor
}
