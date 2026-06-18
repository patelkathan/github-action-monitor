#!/usr/bin/swift
// Generates Resources/AppIcon.icns from a programmatic Core Graphics drawing.
// Run via `make icon` (invokes this with the system Swift interpreter).

import AppKit
import CoreGraphics

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let fm = FileManager.default

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectRoot = scriptDir.deletingLastPathComponent()
let resourcesDir = projectRoot.appendingPathComponent("Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")

try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22

    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
        NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.06, alpha: 1.0)
    ])
    gradient?.draw(in: bgPath, angle: -90)

    // Bolt glyph, centered, scaled to ~55% of the canvas.
    let boltScale = CGFloat(size) * 0.55
    let boltOriginX = (CGFloat(size) - boltScale) / 2
    let boltOriginY = (CGFloat(size) - boltScale) / 2

    let bolt = NSBezierPath()
    let p: (CGFloat, CGFloat) -> NSPoint = { x, y in
        NSPoint(x: boltOriginX + x * boltScale, y: boltOriginY + y * boltScale)
    }
    bolt.move(to: p(0.58, 1.0))
    bolt.line(to: p(0.12, 0.45))
    bolt.line(to: p(0.42, 0.45))
    bolt.line(to: p(0.30, 0.0))
    bolt.line(to: p(0.88, 0.58))
    bolt.line(to: p(0.55, 0.58))
    bolt.line(to: p(0.58, 1.0))
    bolt.close()

    let boltGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.78, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.85, alpha: 1.0)
    ])
    boltGradient?.draw(in: bolt, angle: -90)

    image.unlockFocus()
    return image
}

struct IconSpec {
    let pixelSize: Int
    let fileName: String
}

let specs: [IconSpec] = sizes.flatMap { size -> [IconSpec] in
    if size == 1024 {
        return [IconSpec(pixelSize: size, fileName: "icon_512x512@2x.png")]
    }
    let pointSize = size
    var entries = [IconSpec(pixelSize: pointSize, fileName: "icon_\(pointSize)x\(pointSize).png")]
    if pointSize * 2 <= 1024, pointSize != 512 {
        entries.append(IconSpec(pixelSize: pointSize * 2, fileName: "icon_\(pointSize)x\(pointSize)@2x.png"))
    }
    return entries
}

for spec in specs {
    let image = drawIcon(size: spec.pixelSize)
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        continue
    }
    let outURL = iconsetDir.appendingPathComponent(spec.fileName)
    try pngData.write(to: outURL)
}

print("Wrote iconset to \(iconsetDir.path)")

let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Generated \(icnsURL.path)")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
    exit(process.terminationStatus)
}
