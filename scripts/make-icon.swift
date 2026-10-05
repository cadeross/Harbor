import AppKit

// Renders the Harbor app icon: a white sailboat on a sea-glass gradient.
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let inset = rect.insetBy(dx: 100, dy: 100)
    let shape = NSBezierPath(roundedRect: inset, xRadius: 185, yRadius: 185)
    NSGradient(colors: [
        NSColor(srgbRed: 0.33, green: 0.78, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.42, blue: 0.86, alpha: 1),
    ])!.draw(in: shape, angle: -90)

    // A soft highlight across the top, for the glassy look.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), .clear])!
        .draw(in: NSRect(x: inset.minX, y: inset.midY, width: inset.width, height: inset.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let boat = NSImage(systemSymbolName: "sailboat.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let s = boat.size
        boat.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2 + 20, width: s.width, height: s.height))
    }
    return true
}
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
