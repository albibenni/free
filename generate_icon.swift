import AppKit

let symbolName = "leaf.fill"
let iconSize: CGFloat = 1024
let iconSetDir = "AppIcon.iconset"

try? FileManager.default.removeItem(atPath: iconSetDir)
try? FileManager.default.createDirectory(atPath: iconSetDir, withIntermediateDirectories: true)

func createIcon(size: Int, scale: Int) {
    let actualSize = CGFloat(size * scale)
    let image = NSImage(size: NSSize(width: actualSize, height: actualSize))

    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: actualSize, height: actualSize)
    let path = NSBezierPath(
        roundedRect: rect.insetBy(dx: actualSize * 0.1, dy: actualSize * 0.1),
        xRadius: actualSize * 0.2, yRadius: actualSize * 0.2)
    NSColor.systemGreen.setFill()
    path.fill()

    let config = NSImage.SymbolConfiguration(pointSize: actualSize * 0.5, weight: .bold)
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let symbolRect = NSRect(
            x: actualSize * 0.25, y: actualSize * 0.25, width: actualSize * 0.5,
            height: actualSize * 0.5)
        NSColor.white.set()
        symbol.draw(in: symbolRect)
    }

    image.unlockFocus()

    if let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) {
        let pngData = bitmap.representation(using: .png, properties: [:])
        let fileName = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
        try? pngData?.write(to: URL(fileURLWithPath: "\(iconSetDir)/\(fileName)"))
    }
}

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    createIcon(size: size, scale: 1)
    createIcon(size: size, scale: 2)
}

print("Iconset created. Run: iconutil -c icns AppIcon.iconset")
