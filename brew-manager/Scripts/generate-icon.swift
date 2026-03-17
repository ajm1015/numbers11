#!/usr/bin/env swift

import AppKit
import CoreGraphics

// MARK: - Aero Glass Bottle-Crate Icon Generator
// Draws a stylized crate with glass bottles — Windows Aero aesthetic
// with glossy reflections, translucency, and depth

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fprint("Failed to get graphics context")
    exit(1)
}

// Colors — Midnight theme palette
let accentBlue = NSColor(red: 0.431, green: 0.620, blue: 1.0, alpha: 1.0)      // #6E9EFF
let accentCyan = NSColor(red: 0.306, green: 0.804, blue: 0.769, alpha: 1.0)     // #4ECDC4
let bgDark = NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)         // #0D1117
let surfaceDark = NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)    // #161B22
let borderColor = NSColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1.0)    // #30363D
let glassWhite = NSColor(white: 1.0, alpha: 0.15)
let glassHighlight = NSColor(white: 1.0, alpha: 0.35)
let glassShadow = NSColor(white: 0.0, alpha: 0.4)

// MARK: - Background (rounded square with Aero gradient)

let cornerRadius: CGFloat = 220
let bgRect = CGRect(x: 20, y: 20, width: size - 40, height: size - 40)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// Multi-stop gradient background
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1.0).cgColor,
    ] as CFArray,
    locations: [0.0, 0.5, 1.0]
)!
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: size/2, y: size), end: CGPoint(x: size/2, y: 0), options: [])
ctx.restoreGState()

// Subtle border
ctx.saveGState()
ctx.addPath(bgPath)
ctx.setStrokeColor(borderColor.cgColor)
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// MARK: - Crate

let crateX: CGFloat = 160
let crateY: CGFloat = 120
let crateW: CGFloat = 704
let crateH: CGFloat = 380
let crateCorner: CGFloat = 24

// Crate body — wooden/dark surface
let crateRect = CGRect(x: crateX, y: crateY, width: crateW, height: crateH)
let cratePath = CGPath(roundedRect: crateRect, cornerWidth: crateCorner, cornerHeight: crateCorner, transform: nil)

ctx.saveGState()
ctx.addPath(cratePath)
ctx.clip()

let crateGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1.0).cgColor,
        NSColor(red: 0.10, green: 0.07, blue: 0.05, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.05, blue: 0.04, alpha: 1.0).cgColor,
    ] as CFArray,
    locations: [0.0, 0.6, 1.0]
)!
ctx.drawLinearGradient(crateGradient, start: CGPoint(x: crateX, y: crateY + crateH), end: CGPoint(x: crateX, y: crateY), options: [])
ctx.restoreGState()

// Crate slats (horizontal lines)
for i in 1..<5 {
    let y = crateY + CGFloat(i) * crateH / 5
    ctx.saveGState()
    ctx.move(to: CGPoint(x: crateX + 20, y: y))
    ctx.addLine(to: CGPoint(x: crateX + crateW - 20, y: y))
    ctx.setStrokeColor(NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 0.6).cgColor)
    ctx.setLineWidth(2)
    ctx.strokePath()
    ctx.restoreGState()
}

// Crate border with Aero glow
ctx.saveGState()
ctx.addPath(cratePath)
ctx.setStrokeColor(NSColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 0.8).cgColor)
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// Crate inner highlight (Aero glass edge)
let crateInnerRect = crateRect.insetBy(dx: 4, dy: 4)
let crateInnerPath = CGPath(roundedRect: crateInnerRect, cornerWidth: crateCorner - 4, cornerHeight: crateCorner - 4, transform: nil)
ctx.saveGState()
ctx.addPath(crateInnerPath)
ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.06).cgColor)
ctx.setLineWidth(1.5)
ctx.strokePath()
ctx.restoreGState()

// MARK: - Bottles

func drawBottle(ctx: CGContext, centerX: CGFloat, bottleColor: NSColor, glowColor: NSColor) {
    let bodyW: CGFloat = 110
    let bodyH: CGFloat = 300
    let neckW: CGFloat = 40
    let neckH: CGFloat = 160
    let capH: CGFloat = 30

    let bodyBottom: CGFloat = crateY + 40
    let bodyTop = bodyBottom + bodyH
    let neckTop = bodyTop + neckH
    let capTop = neckTop + capH

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor(white: 0.0, alpha: 0.5).cgColor)

    // Bottle body — Aero glass gradient
    let bodyRect = CGRect(x: centerX - bodyW/2, y: bodyBottom, width: bodyW, height: bodyH)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 16, cornerHeight: 16, transform: nil)

    ctx.addPath(bodyPath)
    ctx.clip()

    let bottleGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            bottleColor.withAlphaComponent(0.9).cgColor,
            bottleColor.withAlphaComponent(0.7).cgColor,
            bottleColor.withAlphaComponent(0.5).cgColor,
            bottleColor.withAlphaComponent(0.7).cgColor,
        ] as CFArray,
        locations: [0.0, 0.3, 0.6, 1.0]
    )!
    ctx.drawLinearGradient(bottleGradient, start: CGPoint(x: centerX - bodyW/2, y: bodyBottom), end: CGPoint(x: centerX + bodyW/2, y: bodyBottom), options: [])
    ctx.restoreGState()

    // Bottle body border
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(bottleColor.withAlphaComponent(0.4).cgColor)
    ctx.setLineWidth(2)
    ctx.strokePath()
    ctx.restoreGState()

    // Glass reflection stripe (Aero signature)
    ctx.saveGState()
    let reflectRect = CGRect(x: centerX - bodyW/2 + 14, y: bodyBottom + 20, width: 18, height: bodyH - 40)
    let reflectPath = CGPath(roundedRect: reflectRect, cornerWidth: 9, cornerHeight: 9, transform: nil)
    ctx.addPath(reflectPath)
    ctx.clip()
    let reflectGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(white: 1.0, alpha: 0.25).cgColor,
            NSColor(white: 1.0, alpha: 0.05).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(reflectGradient, start: CGPoint(x: reflectRect.minX, y: reflectRect.maxY), end: CGPoint(x: reflectRect.maxX, y: reflectRect.minY), options: [])
    ctx.restoreGState()

    // Neck
    ctx.saveGState()
    let neckRect = CGRect(x: centerX - neckW/2, y: bodyTop - 10, width: neckW, height: neckH + 10)
    let neckPath = CGPath(roundedRect: neckRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
    ctx.addPath(neckPath)
    ctx.clip()
    let neckGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            bottleColor.withAlphaComponent(0.8).cgColor,
            bottleColor.withAlphaComponent(0.5).cgColor,
            bottleColor.withAlphaComponent(0.7).cgColor,
        ] as CFArray,
        locations: [0.0, 0.5, 1.0]
    )!
    ctx.drawLinearGradient(neckGradient, start: CGPoint(x: centerX - neckW/2, y: bodyTop), end: CGPoint(x: centerX + neckW/2, y: bodyTop), options: [])
    ctx.restoreGState()

    // Neck border
    ctx.saveGState()
    ctx.addPath(neckPath)
    ctx.setStrokeColor(bottleColor.withAlphaComponent(0.3).cgColor)
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    ctx.restoreGState()

    // Neck reflection
    ctx.saveGState()
    let neckReflect = CGRect(x: centerX - neckW/2 + 6, y: bodyTop + 10, width: 6, height: neckH - 30)
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.18).cgColor)
    ctx.fill(neckReflect)
    ctx.restoreGState()

    // Cap
    ctx.saveGState()
    let capRect = CGRect(x: centerX - neckW/2 - 4, y: neckTop, width: neckW + 8, height: capH)
    let capPath = CGPath(roundedRect: capRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
    ctx.addPath(capPath)
    ctx.setFillColor(NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.addPath(capPath)
    ctx.setStrokeColor(NSColor(white: 0.6, alpha: 1.0).cgColor)
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    ctx.restoreGState()

    // Cap highlight
    ctx.saveGState()
    let capHighlight = CGRect(x: centerX - neckW/2, y: neckTop + capH * 0.5, width: neckW, height: capH * 0.4)
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.3).cgColor)
    ctx.fill(capHighlight)
    ctx.restoreGState()

    // Glow underneath (Aero ambient lighting)
    ctx.saveGState()
    let glowRect = CGRect(x: centerX - bodyW/2 - 20, y: bodyBottom - 10, width: bodyW + 40, height: 30)
    let glowPath = CGPath(ellipseIn: glowRect, transform: nil)
    ctx.addPath(glowPath)
    ctx.clip()
    let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            glowColor.withAlphaComponent(0.3).cgColor,
            glowColor.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(glowGradient, startCenter: CGPoint(x: centerX, y: bodyBottom), startRadius: 0, endCenter: CGPoint(x: centerX, y: bodyBottom), endRadius: bodyW/2 + 20, options: [])
    ctx.restoreGState()
}

// Draw 3 bottles — blue, cyan, purple
let bottlePositions: [(CGFloat, NSColor, NSColor)] = [
    (size * 0.30, accentBlue, accentBlue),
    (size * 0.50, accentCyan, accentCyan),
    (size * 0.70, NSColor(red: 0.737, green: 0.549, blue: 1.0, alpha: 1.0), NSColor(red: 0.737, green: 0.549, blue: 1.0, alpha: 1.0)),  // #BC8CFF
]

for (cx, color, glow) in bottlePositions {
    drawBottle(ctx: ctx, centerX: cx, bottleColor: color, glowColor: glow)
}

// MARK: - Label on crate front

let labelRect = CGRect(x: size/2 - 140, y: crateY + 30, width: 280, height: 60)
let labelPath = CGPath(roundedRect: labelRect, cornerWidth: 8, cornerHeight: 8, transform: nil)

ctx.saveGState()
ctx.addPath(labelPath)
ctx.setFillColor(NSColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 0.85).cgColor)
ctx.fillPath()
ctx.addPath(labelPath)
ctx.setStrokeColor(accentBlue.withAlphaComponent(0.4).cgColor)
ctx.setLineWidth(1.5)
ctx.strokePath()
ctx.restoreGState()

// "BREW" text on label
let labelText = "BREW" as NSString
let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 32, weight: .bold),
    .foregroundColor: accentBlue.withAlphaComponent(0.9),
    .kern: 8.0,
]
let textSize = labelText.size(withAttributes: labelAttrs)
let textPoint = NSPoint(
    x: labelRect.midX - textSize.width / 2,
    y: labelRect.midY - textSize.height / 2
)
labelText.draw(at: textPoint, withAttributes: labelAttrs)

// MARK: - Top Aero gloss overlay (signature glass shine across entire icon)

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let glossRect = CGRect(x: 20, y: size * 0.52, width: size - 40, height: size * 0.48 - 20)
let glossGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(white: 1.0, alpha: 0.08).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor,
    ] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(glossGradient, start: CGPoint(x: size/2, y: size), end: CGPoint(x: size/2, y: size * 0.5), options: [])
ctx.restoreGState()

image.unlockFocus()

// MARK: - Export

func fprint(_ msg: String) {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fprint("Failed to export PNG")
    exit(1)
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let outputPath = "\(outputDir)/AppIcon-1024.png"

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print(outputPath)
} catch {
    fprint("Failed to write: \(error)")
    exit(1)
}
