#!/usr/bin/env swift
// generate_icon.swift — Draws the CloudChamber app icon at all required sizes
// Run: swift scripts/generate_icon.swift
// Outputs PNG files into CloudChamber/Resources/Assets.xcassets/AppIcon.appiconset/

import AppKit
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Drawing

/// Draw into an exact-pixel bitmap context so the PNG is always `px × px` regardless of display scale.
func drawIcon(size: CGFloat) -> NSImage {
    let px  = Int(size)
    let cs  = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: px, height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return NSImage(size: NSSize(width: size, height: size)) }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let pad  = size * 0.04
    let r    = (size / 2) - pad          // outer circle radius
    let cx   = size / 2
    let cy   = size / 2
    let s    = size / 512               // scale factor relative to 512 pt master

    // ── Background: deep indigo radial gradient ─────────────────────────────
    let bgInner = CGColor(red: 0.05, green: 0.07, blue: 0.22, alpha: 1)
    let bgOuter = CGColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 1)
    let bgGrad  = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [bgInner, bgOuter] as CFArray,
        locations: [0, 1]
    )!

    // Clip to rounded-rect (macOS icon shape: squircle approx with cornerRadius ≈ 22.5 %)
    let cornerRadius = size * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    ctx.drawRadialGradient(
        bgGrad,
        startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: r * 1.4,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // ── Glass vessel outline ────────────────────────────────────────────────
    let vesselR = r * 0.82
    ctx.setStrokeColor(CGColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 0.35))
    ctx.setLineWidth(s * 4)
    ctx.strokeEllipse(in: CGRect(x: cx - vesselR, y: cy - vesselR,
                                  width: vesselR * 2, height: vesselR * 2))

    // ── Mist layers (soft white arcs) ───────────────────────────────────────
    for i in 0..<6 {
        let yOff  = cy - vesselR * 0.55 + CGFloat(i) * vesselR * 0.22
        let alpha = 0.025 + Double(i) * 0.012
        let halfW = vesselR * (0.9 - CGFloat(i) * 0.06)
        let mistRect = CGRect(x: cx - halfW, y: yOff - s * 4, width: halfW * 2, height: s * 8)
        ctx.setFillColor(CGColor(red: 0.8, green: 0.88, blue: 1.0, alpha: alpha))
        ctx.fillEllipse(in: mistRect)
    }

    // ── Cold plate (dark band at bottom) ────────────────────────────────────
    let coldY  = cy - vesselR * 0.6
    let coldH  = s * 18
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 0.85))
    let coldRect = CGRect(x: cx - vesselR * 0.85, y: coldY - coldH / 2,
                          width: vesselR * 1.70, height: coldH)
    ctx.fill(coldRect)

    // ── Helper: draw a glowing curved track ─────────────────────────────────
    func drawTrack(points: [CGPoint], color: CGColor, width: CGFloat, glow: CGFloat) {
        guard points.count >= 2 else { return }

        // glow pass
        let glowColor = color.copy(alpha: 0.18)!
        ctx.setStrokeColor(glowColor)
        ctx.setLineWidth(width + glow)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: points[0])
        for p in points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()

        // mid glow
        let midColor = color.copy(alpha: 0.45)!
        ctx.setStrokeColor(midColor)
        ctx.setLineWidth(width + glow * 0.35)
        ctx.beginPath()
        ctx.move(to: points[0])
        for p in points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()

        // core
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.beginPath()
        ctx.move(to: points[0])
        for p in points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()
    }

    // ── Alpha track (gold, thick, gentle curve) ─────────────────────────────
    let alphaColor = CGColor(red: 1.0, green: 0.75, blue: 0.15, alpha: 1)
    var alphaPoints: [CGPoint] = []
    let alphaSteps = 32
    for i in 0...alphaSteps {
        let t = CGFloat(i) / CGFloat(alphaSteps)
        let angle = (CGFloat.pi * 0.55) + t * CGFloat.pi * 0.38
        let curveR = vesselR * (0.62 - t * 0.12)
        alphaPoints.append(CGPoint(
            x: cx + cos(angle) * curveR,
            y: cy + sin(angle) * curveR * 0.80
        ))
    }
    drawTrack(points: alphaPoints, color: alphaColor, width: s * 5.5, glow: s * 14)

    // ── Beta track (cyan, thin, tight spiral) ───────────────────────────────
    let betaColor = CGColor(red: 0.25, green: 0.92, blue: 1.0, alpha: 1)
    var betaPoints: [CGPoint] = []
    let betaSteps = 56
    for i in 0...betaSteps {
        let t = CGFloat(i) / CGFloat(betaSteps)
        let angle = CGFloat.pi * 1.15 + t * CGFloat.pi * 1.05
        let curveR = vesselR * (0.28 + t * 0.44)
        betaPoints.append(CGPoint(
            x: cx + cos(angle) * curveR,
            y: cy + sin(angle) * curveR * 0.72
        ))
    }
    drawTrack(points: betaPoints, color: betaColor, width: s * 2.5, glow: s * 9)

    // ── Muon track (magenta, nearly straight, long) ─────────────────────────
    let muonColor = CGColor(red: 1.0, green: 0.30, blue: 0.85, alpha: 1)
    let muonPoints: [CGPoint] = [
        CGPoint(x: cx - vesselR * 0.65, y: cy + vesselR * 0.72),
        CGPoint(x: cx - vesselR * 0.60, y: cy + vesselR * 0.45),
        CGPoint(x: cx - vesselR * 0.54, y: cy + vesselR * 0.00),
        CGPoint(x: cx - vesselR * 0.50, y: cy - vesselR * 0.42),
        CGPoint(x: cx - vesselR * 0.47, y: cy - vesselR * 0.72),
    ]
    drawTrack(points: muonPoints, color: muonColor, width: s * 3, glow: s * 11)

    // ── Source glow (tiny sphere at bottom centre) ──────────────────────────
    let srcY  = cy - vesselR * 0.54
    let srcR  = s * 14
    let srcGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.9, green: 1.0, blue: 0.6, alpha: 0.9),
            CGColor(red: 0.4, green: 0.9, blue: 0.3, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        srcGrad,
        startCenter: CGPoint(x: cx, y: srcY), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: srcY), endRadius: srcR,
        options: []
    )

    // ── Rim highlight (top arc) ──────────────────────────────────────────────
    let rimGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.14),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        rimGrad,
        start: CGPoint(x: cx, y: size),
        end:   CGPoint(x: cx, y: cy),
        options: []
    )
    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else {
        return NSImage(size: NSSize(width: size, height: size))
    }
    return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
}

// MARK: - Export

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",   128),
    ("icon_128x128@2x",256),
    ("icon_256x256",   256),
    ("icon_256x256@2x",512),
    ("icon_512x512",   512),
    ("icon_512x512@2x",1024),
]

let outDir = URL(fileURLWithPath: "CloudChamber/Resources/Assets.xcassets/AppIcon.appiconset")

for (name, px) in sizes {
    let image = drawIcon(size: CGFloat(px))
    let dest  = outDir.appendingPathComponent("\(name).png")

    // Use CGImage representation so no Retina scale multiplier is applied
    guard
        let cgImage  = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let dest2    = CGImageDestinationCreateWithURL(dest as CFURL, "public.png" as CFString, 1, nil)
    else {
        print("❌ Failed to generate \(name).png")
        continue
    }
    CGImageDestinationAddImage(dest2, cgImage, nil)
    guard CGImageDestinationFinalize(dest2) else {
        print("❌ CGImageDestinationFinalize failed for \(name).png")
        continue
    }
    print("✅ \(name).png  (\(px)×\(px))")
}

print("\nDone. Rebuild the project to pick up the new icons.")
