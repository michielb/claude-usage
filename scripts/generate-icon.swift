#!/usr/bin/env swift
// Generates AppIcon.iconset with all required sizes for macOS
// Run: swift scripts/generate-icon.swift

import AppKit

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let outputDir = "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outputDir)
try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Background: dark charcoal rounded rect
    let cornerRadius = s * 0.22
    let bgRect = NSRect(x: 0, y: 0, width: s, height: s)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(srgbRed: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).setFill()
    bgPath.fill()

    // "C" letter — centered, upper portion
    let fontSize = s * 0.48
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let cAttr: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let cStr = NSAttributedString(string: "C", attributes: cAttr)
    let cSize = cStr.size()
    let cX = (s - cSize.width) / 2
    let cY = s * 0.35
    cStr.draw(at: NSPoint(x: cX, y: cY))

    // Progress bar underneath the "C"
    let barHeight = s * 0.06
    let barWidth = s * 0.52
    let barX = (s - barWidth) / 2
    let barY = s * 0.24
    let barRadius = barHeight / 2
    let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)

    // Bar background
    let barBg = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)
    NSColor(white: 0.4, alpha: 0.6).setFill()
    barBg.fill()

    // Green fill (60%)
    let greenWidth = barWidth * 0.6
    let greenRect = NSRect(x: barX, y: barY, width: greenWidth, height: barHeight)
    let greenPath = NSBezierPath(roundedRect: greenRect, xRadius: barRadius, yRadius: barRadius)
    NSColor(srgbRed: 0.28, green: 0.70, blue: 0.38, alpha: 1.0).setFill()
    greenPath.fill()

    image.unlockFocus()
    return image
}

for entry in sizes {
    let image = renderIcon(size: entry.size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(entry.name)")
        continue
    }
    let path = "\(outputDir)/\(entry.name).png"
    try png.write(to: URL(fileURLWithPath: path))
    print("Generated \(path)")
}

print("\nNow run: iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns")
