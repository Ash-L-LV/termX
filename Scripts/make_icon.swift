import AppKit

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: Int(size),
                                 pixelsHigh: Int(size),
                                 bitsPerSample: 8,
                                 samplesPerPixel: 4,
                                 hasAlpha: true,
                                 isPlanar: false,
                                 colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0,
                                 bitsPerPixel: 0) else {
    fatalError("no bitmap")
}
let graphicsContext = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer { NSGraphicsContext.restoreGraphicsState() }
let context = graphicsContext.cgContext

// ── Background: dark slate gradient with a soft blue glow ──
let backgroundColors = [
    NSColor(srgbRed: 0.16, green: 0.21, blue: 0.34, alpha: 1),
    NSColor(srgbRed: 0.05, green: 0.07, blue: 0.13, alpha: 1),
]
let background = NSGradient(colors: backgroundColors)!
background.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

let glowColors = [
    NSColor(srgbRed: 0.30, green: 0.50, blue: 0.95, alpha: 0.28),
    NSColor(srgbRed: 0.30, green: 0.50, blue: 0.95, alpha: 0.0),
]
let glow = NSGradient(colors: glowColors)!
glow.draw(fromCenter: NSPoint(x: 300, y: 880),
          radius: 0,
          toCenter: NSPoint(x: 300, y: 880),
          radius: 620,
          options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])

// ── Terminal window ──
let windowRect = NSRect(x: 138, y: 172, width: 748, height: 632)
let windowPath = NSBezierPath(roundedRect: windowRect, xRadius: 48, yRadius: 48)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 56
shadow.shadowOffset = NSSize(width: 0, height: -22)
shadow.set()

let windowColors = [
    NSColor(srgbRed: 0.16, green: 0.19, blue: 0.27, alpha: 0.98),
    NSColor(srgbRed: 0.06, green: 0.08, blue: 0.13, alpha: 0.98),
]
let windowGradient = NSGradient(colors: windowColors)!
windowGradient.draw(in: windowPath, angle: 90)

NSGraphicsContext.current?.cgContext.saveGState()
windowPath.addClip()
NSColor(white: 1, alpha: 0.055).setFill()
NSRect(x: windowRect.minX, y: windowRect.maxY - 104, width: windowRect.width, height: 104).fill()
NSGraphicsContext.current?.cgContext.restoreGState()

NSColor(white: 1, alpha: 0.18).setStroke()
windowPath.lineWidth = 3
windowPath.stroke()

// ── Traffic lights ──
let trafficColors = [
    NSColor(srgbRed: 1.00, green: 0.37, blue: 0.34, alpha: 1),
    NSColor(srgbRed: 0.99, green: 0.74, blue: 0.18, alpha: 1),
    NSColor(srgbRed: 0.16, green: 0.78, blue: 0.25, alpha: 1),
]
var lightX = windowRect.minX + 54
let lightY = windowRect.maxY - 66
for color in trafficColors {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: lightX, y: lightY, width: 34, height: 34)).fill()
    lightX += 46
}

// ── Prompt text + block cursor ──
let dimFont = NSFont(name: "Menlo", size: 29)!
let promptFont = NSFont(name: "Menlo", size: 50)!

let line1 = "Last login: Tue Aug  4 21:30:00 on ttys000"
let line1Attributes: [NSAttributedString.Key: Any] = [
    .font: dimFont,
    .foregroundColor: NSColor(white: 0.72, alpha: 0.9),
]
(line1 as NSString).draw(at: NSPoint(x: windowRect.minX + 54, y: windowRect.maxY - 176),
                         withAttributes: line1Attributes)

let line2 = "~ %"
let line2Attributes: [NSAttributedString.Key: Any] = [
    .font: promptFont,
    .foregroundColor: NSColor(white: 0.97, alpha: 1),
]
let line2Size = (line2 as NSString).size(withAttributes: line2Attributes)
let line2Origin = NSPoint(x: windowRect.minX + 54, y: windowRect.maxY - 268)
(line2 as NSString).draw(at: line2Origin, withAttributes: line2Attributes)

let cursorRect = NSRect(x: line2Origin.x + line2Size.width + 12,
                        y: line2Origin.y - 4,
                        width: 32,
                        height: 68)
NSColor(srgbRed: 0.42, green: 0.92, blue: 0.55, alpha: 1).setFill()
NSBezierPath(roundedRect: cursorRect, xRadius: 6, yRadius: 6).fill()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try! png.write(to: output)
print("wrote \(output.path)")
