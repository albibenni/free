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
        // Match macOS "Multicolor" feel: subtle cool-spectrum tint, not full rainbow bars.
        return [
            NSColor.systemBlue.withAlphaComponent(topAlpha),
            NSColor.systemTeal.withAlphaComponent((topAlpha + bottomAlpha) * 0.5),
            NSColor.systemIndigo.withAlphaComponent(bottomAlpha),
        ]
    }
    return [
        accentColor.withAlphaComponent(topAlpha),
        accentColor.withAlphaComponent(bottomAlpha),
    ]
}

func appKitAccentBorderColor(for accentColor: NSColor, alpha: CGFloat) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return NSColor.systemBlue.withAlphaComponent(max(0.18, alpha))
    }
    return accentColor.withAlphaComponent(alpha)
}

func appKitAccentForegroundColor(for accentColor: NSColor) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return NSColor.white.withAlphaComponent(0.95)
    }
    return accentColor
}

func appKitAccentToggleOnColor(for accentColor: NSColor, isEnabled: Bool) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        // Native macOS toggles are green when ON, independent from accent selection.
        return (isEnabled ? NSColor.systemGreen : NSColor.systemGreen.withAlphaComponent(0.35))
    }
    return isEnabled ? accentColor : accentColor.withAlphaComponent(0.35)
}

func appKitAccentGradient(for accentColor: NSColor, alpha: CGFloat) -> NSGradient? {
    guard FocusColor.isRainbowAccentColor(accentColor) else { return nil }
    let colors = [
        NSColor.systemBlue.withAlphaComponent(alpha),
        NSColor.systemTeal.withAlphaComponent(alpha),
        NSColor.systemIndigo.withAlphaComponent(alpha),
    ]
    return NSGradient(colors: colors)
}

func appKitAccentPrimaryColor(for accentColor: NSColor) -> NSColor {
    if FocusColor.isRainbowAccentColor(accentColor) {
        return .systemBlue
    }
    return accentColor
}
