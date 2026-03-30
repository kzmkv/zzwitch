import Cocoa

func makeAppIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        // Blue rounded square
        NSColor(red: 0.12, green: 0.32, blue: 0.88, alpha: 1).setFill()
        let radius = size * 0.18
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        // White bold W
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: size * 0.62),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: "W", attributes: attrs)
        let s = str.size()
        str.draw(at: NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2))
        return true
    }
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to render PNG for \(path)\n", stderr); exit(1)
    }
    do { try png.write(to: URL(fileURLWithPath: path)) }
    catch { fputs("Failed to write \(path): \(error)\n", stderr); exit(1) }
}

let iconsetDir = "AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// (displaySize, scale) pairs per Apple's iconset spec
let specs: [(Int, Int)] = [
    (16,1),(16,2),(32,1),(32,2),
    (128,1),(128,2),(256,1),(256,2),(512,1),(512,2)
]
for (display, scale) in specs {
    let actual = CGFloat(display * scale)
    let name = scale == 1
        ? "icon_\(display)x\(display).png"
        : "icon_\(display)x\(display)@\(scale)x.png"
    savePNG(makeAppIcon(size: actual), to: "\(iconsetDir)/\(name)")
}
print("Iconset written to \(iconsetDir)/")
