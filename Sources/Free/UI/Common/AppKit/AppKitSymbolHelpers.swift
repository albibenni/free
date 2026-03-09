import AppKit

private func applySymbolPaletteColor(
    to configuration: NSImage.SymbolConfiguration,
    color: NSColor
) -> NSImage.SymbolConfiguration {
    configuration.applying(
        NSImage.SymbolConfiguration(paletteColors: [color])
    )
}

func appKitSymbolImage(
    named symbolName: String,
    pointSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor?
) -> NSImage? {
    guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return nil
    }

    var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    if let color {
        configuration = applySymbolPaletteColor(to: configuration, color: color)
    }
    return baseImage.withSymbolConfiguration(configuration)
}

func appKitSymbolImage(
    named symbolName: String,
    pointSize: CGFloat,
    weight: NSFont.Weight
) -> NSImage? {
    appKitSymbolImage(
        named: symbolName,
        pointSize: pointSize,
        weight: weight,
        color: nil
    )
}

func appKitSymbolImage(
    spec: AppKitUISymbolSpec,
    color: NSColor? = nil
) -> NSImage? {
    appKitSymbolImage(
        named: spec.name,
        pointSize: spec.pointSize,
        weight: spec.weight,
        color: color
    )
}

func resolvedAppKitControlSymbolName(_ symbol: String) -> String {
    switch symbol {
    case "+":
        return AppKitUISymbols.Name.plusFilled
    case "-":
        return AppKitUISymbols.Name.minus
    default:
        return symbol
    }
}
