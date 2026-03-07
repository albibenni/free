import AppKit

func appKitSymbolImage(
    named symbolName: String,
    pointSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor? = nil
) -> NSImage? {
    guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return nil
    }

    var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    if let color {
        configuration = configuration.applying(.init(paletteColors: [color]))
    }
    return baseImage.withSymbolConfiguration(configuration) ?? baseImage
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
