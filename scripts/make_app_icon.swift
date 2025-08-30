// make_app_icon.swift
//
// Generates the CloudChamber app icon set (AppIcon.appiconset) at every size
// macOS expects: 16–1024 px. The artwork is drawn with Core Graphics in a fixed
// 1024×1024 design space and rendered per size so small icons stay crisp.
//
// Usage: swift scripts/make_app_icon.swift

import AppKit
import Foundation

// MARK: - Output paths

let scriptPath = #filePath
let scriptDir = scriptPath.hasPrefix("/")
    ? (scriptPath as NSString).deletingLastPathComponent
    : FileManager.default.currentDirectoryPath + "/" + (scriptPath as NSString).deletingLastPathComponent
let repoRoot = (scriptDir as NSString).deletingLastPathComponent
let assetsRoot = repoRoot + "/CloudChamber/Resources/Assets.xcassets"
let iconSetDir = assetsRoot + "/AppIcon.appiconset"

try? FileManager.default.createDirectory(atPath: iconSetDir, withIntermediateDirectories: true)

func writeJSON(_ text: String, to path: String) throws {
    try text.data(using: .utf8)!.write(to: URL(fileURLWithPath: path))
}

// MARK: - Small drawing helpers

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

/// sRGB color from 0–255 components, with optional alpha.
func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Gradient with (location, color) stops sharing one colorspace.
func makeGrad(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    var comps: [CGFloat] = []
    var locs: [CGFloat] = []
    for (location, color) in stops {
        comps.append(contentsOf: color.components!)
        locs.append(location)
    }
    return CGGradient(colorSpace: srgb, colorComponents: comps, locations: locs, count: stops.count)!
}

/// Scale a design-space width to pixel space, with a floor so thin lines
/// stay visible on the smallest icons.
func smin(_ designWidth: CGFloat, _ scale: CGFloat, _ floor: CGFloat = 0.75) -> CGFloat {
    max(designWidth * scale, floor)
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
    CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
}

/// Big-Sur-style squircle (superellipse n≈5) so the icon shape matches the
/// macOS dock look instead of a plain rounded rect.
func squircle(in box: CGRect, n: CGFloat = 5.0) -> CGPath {
    let path = CGMutablePath()
    let a = box.width / 2
    let cx = box.midX
    let cy = box.midY
    let steps = 300
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * CGFloat.pi * 2
        let ct = cos(t)
        let st = sin(t)
        let x = cx + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n)
        let y = cy + a * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// Build a glow track from flat point lists: [start, c1, c2, end, c1, c2, end…].
func curve(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    p.move(to: pts[0])
    var i = 1
    while i + 2 < pts.count {
        p.addCurve(to: pts[i + 2], control1: pts[i], control2: pts[i + 1])
        i += 3
    }
    return p
}

func quad(_ start: CGPoint, _ ctrl: CGPoint, _ end: CGPoint) -> CGPath {
    let p = CGMutablePath()
    p.move(to: start)
    p.addQuadCurve(to: end, control: ctrl)
    return p
}

/// Cylinder body silhouette (glass walls), half-ellipse bottom, flat top where
/// the lid ellipse covers the junction.
func glassBody() -> CGPath {
    let left: CGFloat = 322
    let right: CGFloat = 702
    let top: CGFloat = 700
    let bottomCy: CGFloat = 278
    let ry: CGFloat = 46
    let k: CGFloat = 0.5523 * ry
    let bottom = bottomCy - ry

    let p = CGMutablePath()
    p.move(to: CGPoint(x: left, y: top))
    p.addLine(to: CGPoint(x: right, y: top))
    p.addLine(to: CGPoint(x: right, y: bottomCy))
    p.addCurve(to: CGPoint(x: 512, y: bottom), control1: CGPoint(x: right, y: bottomCy - k), control2: CGPoint(x: 512 + 190 * 0.5523, y: bottom))
    p.addCurve(to: CGPoint(x: left, y: bottomCy), control1: CGPoint(x: 512 - 190 * 0.5523, y: bottom), control2: CGPoint(x: left, y: bottomCy - k))
    p.closeSubpath()
    return p
}

/// Rounded-rect helper.
func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

/// Draw a luminous particle track: wide blurred halo, medium halo, solid core,
/// and a hot white center line.
private let clearShadow = { (ctx: CGContext) in ctx.setShadow(offset: .zero, blur: 0, color: nil) }

func glowStroke(_ ctx: CGContext, _ path: CGPath, scale k: CGFloat,
                coreWidth: CGFloat, core: CGColor, halo: CGColor, blur: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    ctx.setShadow(offset: .zero, blur: smin(blur * 2.4, k, 1.4), color: halo.copy(alpha: 0.55)!)
    ctx.setStrokeColor(halo.copy(alpha: 0.16)!)
    ctx.setLineWidth(smin(coreWidth * 7, k, 1.2))
    ctx.strokePath()

    ctx.setShadow(offset: .zero, blur: smin(blur, k, 1.2), color: halo.copy(alpha: 0.6)!)
    ctx.setStrokeColor(halo.copy(alpha: 0.5)!)
    ctx.setLineWidth(smin(coreWidth * 2.6, k, 1.0))
    ctx.strokePath()

    clearShadow(ctx)
    ctx.setStrokeColor(core)
    ctx.setLineWidth(smin(coreWidth, k))
    ctx.strokePath()

    ctx.setStrokeColor(C(255, 255, 255, 0.6))
    ctx.setLineWidth(smin(coreWidth * 0.4, k, 0.4))
    ctx.strokePath()
    ctx.restoreGState()
}

func radialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat,
                inner: CGColor, outer: CGColor) {
    let g = makeGrad([(0, inner), (1, outer)])
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius, options: [])
}

// MARK: - Icon artwork (1024×1024 design space)

func drawIcon(_ ctx: CGContext, pixels size: CGFloat) {
    let k = size / 1024

    let box = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = squircle(in: box)

    // 1. Dock shadow — baked into the canvas, as Apple's macOS icon template does.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12 * k), blur: 46 * k, color: C(0, 0, 0, 0.42))
    ctx.setFillColor(C(0, 0, 0, 1))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    // Everything else is clipped to the squircle.
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip(using: .evenOdd)

    // 2. Background gradient.
    let bg = makeGrad([(0, C(19, 66, 102)), (0.5, C(11, 40, 66)), (1, C(5, 14, 26))])
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Cool light from the top-left corner.
    radialGlow(ctx, center: CGPoint(x: 430, y: 870), radius: 460, inner: C(120, 190, 235, 0.14), outer: C(120, 190, 235, 0))
    // Cyan vapor pool above the cold plate.
    radialGlow(ctx, center: CGPoint(x: 512, y: 210), radius: 270, inner: C(60, 205, 255, 0.26), outer: C(60, 205, 255, 0))

    // 3. Ground shadow and brushed-aluminum plinth.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: smin(26, k, 1), color: C(0, 0, 0, 0.5))
    ctx.setFillColor(C(0, 0, 0, 0.4))
    ctx.addEllipse(in: ellipse(512, 152, 300, 26))
    ctx.fillPath()
    ctx.restoreGState()

    let plinth = roundedRect(258, 148, 508, 88, 22)
    ctx.saveGState()
    ctx.addPath(plinth)
    ctx.clip()
    let metal = makeGrad([(0, C(225, 230, 238)), (0.18, C(178, 190, 204)), (0.5, C(152, 165, 181)),
                          (0.82, C(174, 188, 202)), (1, C(208, 216, 226))])
    ctx.drawLinearGradient(metal, start: CGPoint(x: 258, y: 0), end: CGPoint(x: 766, y: 0), options: [])
    let plinthShade = makeGrad([(0, C(0, 0, 0, 0)), (1, C(0, 0, 0, 0.28))])
    ctx.drawLinearGradient(plinthShade, start: CGPoint(x: 0, y: 194), end: CGPoint(x: 0, y: 148), options: [])
    ctx.restoreGState()

    // Plinth top highlight line and bolts.
    ctx.setStrokeColor(C(255, 255, 255, 0.55))
    ctx.setLineWidth(smin(2, k, 0.6))
    ctx.addLines(between: [CGPoint(x: 270, y: 232), CGPoint(x: 754, y: 232)])
    ctx.strokePath()
    for bx in [CGFloat(296), 412, 612, 728] {
        radialGlow(ctx, center: CGPoint(x: bx, y: 192), radius: 7,
                   inner: C(130, 142, 158), outer: C(52, 62, 76))
        ctx.setStrokeColor(C(15, 22, 32, 0.55))
        ctx.setLineWidth(smin(1.6, k, 0.5))
        ctx.addEllipse(in: ellipse(bx, 192, 7, 7))
        ctx.strokePath()
    }

    // 4. Glass chamber.
    let glass = glassBody()

    // Glass fill.
    ctx.saveGState()
    ctx.addPath(glass)
    ctx.clip()
    let glassFill = makeGrad([(0, C(255, 255, 255, 0.13)), (1, C(160, 220, 245, 0.05))])
    ctx.drawLinearGradient(glassFill, start: CGPoint(x: 0, y: 700), end: CGPoint(x: 0, y: 250), options: [])

    // Left glass sheen band.
    ctx.saveGState()
    ctx.move(to: CGPoint(x: 356, y: 700))
    ctx.addLine(to: CGPoint(x: 396, y: 700))
    ctx.addLine(to: CGPoint(x: 416, y: 300))
    ctx.addLine(to: CGPoint(x: 366, y: 300))
    ctx.closePath()
    ctx.clip()
    let sheen = makeGrad([(0, C(255, 255, 255, 0.15)), (1, C(255, 255, 255, 0.02))])
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 700), end: CGPoint(x: 0, y: 300), options: [])
    ctx.restoreGState()

    // Cold plate slab.
    let slab = makeGrad([(0, C(13, 25, 38)), (1, C(4, 9, 16))])
    ctx.drawLinearGradient(slab, start: CGPoint(x: 0, y: 278), end: CGPoint(x: 0, y: 206), options: [CGGradientDrawingOptions(rawValue: 0)])
    ctx.setFillColor(C(3, 7, 12, 1))
    ctx.addEllipse(in: ellipse(512, 206, 190, 40))
    ctx.fillPath()
    let plateTop = makeGrad([(0, C(24, 44, 62)), (1, C(9, 19, 30))])
    ctx.drawRadialGradient(plateTop, startCenter: CGPoint(x: 512, y: 258), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 258), endRadius: 190, options: [])
    ctx.addEllipse(in: ellipse(512, 258, 190, 44))
    ctx.fillPath()
    ctx.setStrokeColor(C(120, 195, 240, 0.35))
    ctx.setLineWidth(smin(2.2, k, 0.6))
    ctx.addEllipse(in: ellipse(512, 258, 190, 44))
    ctx.strokePath()

    // Mist.
    for (mx, my, rx, _, a) in [(430.0, 380.0, 150.0, 46.0, 0.10), (560.0, 470.0, 120.0, 40.0, 0.08),
                                (500.0, 560.0, 150.0, 44.0, 0.06)] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
        radialGlow(ctx, center: CGPoint(x: mx, y: my), radius: rx,
                   inner: C(255, 255, 255, a), outer: C(255, 255, 255, 0))
    }

    // Glowing source on the cold plate.
    radialGlow(ctx, center: CGPoint(x: 512, y: 290), radius: 64, inner: C(150, 235, 255, 0.7), outer: C(60, 210, 255, 0))
    radialGlow(ctx, center: CGPoint(x: 512, y: 290), radius: 18, inner: C(255, 255, 255, 0.95), outer: C(180, 240, 255, 0))
    ctx.setFillColor(C(255, 255, 255, 1))
    ctx.addEllipse(in: ellipse(512, 290, 4.5, 4.5))
    ctx.fillPath()

    // 5. Tracks inside the vessel.
    let beta = curve([
        .init(x: 496, y: 292), .init(x: 452, y: 336), .init(x: 392, y: 388), .init(x: 416, y: 446),
        .init(x: 444, y: 512), .init(x: 552, y: 520), .init(x: 594, y: 582),
        .init(x: 640, y: 632), .init(x: 560, y: 672), .init(x: 486, y: 646),
    ])
    glowStroke(ctx, beta, scale: k, coreWidth: 9, core: C(57, 227, 255), halo: C(57, 227, 255, 0.55), blur: 26)

    let alpha = curve([
        .init(x: 528, y: 292), .init(x: 540, y: 350), .init(x: 548, y: 415), .init(x: 540, y: 480),
        .init(x: 532, y: 546), .init(x: 546, y: 610), .init(x: 566, y: 662),
    ])
    glowStroke(ctx, alpha, scale: k, coreWidth: 7, core: C(255, 110, 158), halo: C(255, 110, 158, 0.5), blur: 22)

    // Delta rays off the primary tracks.
    for d in [quad(.init(x: 430, y: 452), .init(x: 398, y: 460), .init(x: 366, y: 448)),
              quad(.init(x: 538, y: 548), .init(x: 520, y: 572), .init(x: 498, y: 586)),
              quad(.init(x: 540, y: 420), .init(x: 562, y: 424), .init(x: 588, y: 414))] {
        glowStroke(ctx, d, scale: k, coreWidth: 3, core: C(190, 245, 255, 0.95), halo: C(190, 245, 255, 0.4), blur: 10)
    }

    // Gamma conversion: glowing vertex with an e-/e+ pair curving apart.
    radialGlow(ctx, center: CGPoint(x: 620, y: 542), radius: 46, inner: C(192, 139, 255, 0.8), outer: C(192, 139, 255, 0))
    glowStroke(ctx, curve([.init(x: 618, y: 540), .init(x: 604, y: 522), .init(x: 592, y: 492), .init(x: 524, y: 470)]),
               scale: k, coreWidth: 4.5, core: C(90, 230, 255), halo: C(90, 230, 255, 0.5), blur: 14)
    glowStroke(ctx, curve([.init(x: 622, y: 544), .init(x: 656, y: 560), .init(x: 684, y: 586), .init(x: 690, y: 640)]),
               scale: k, coreWidth: 4.5, core: C(255, 130, 180), halo: C(255, 130, 180, 0.5), blur: 14)
    ctx.setFillColor(C(235, 215, 255, 1))
    ctx.addEllipse(in: ellipse(620, 542, 6, 6))
    ctx.fillPath()

    ctx.restoreGState() // glass clip

    // 6. Glass outline, lid, and valve.
    ctx.setStrokeColor(C(205, 235, 255, 0.4))
    ctx.setLineWidth(smin(5, k, 0.8))
    ctx.addPath(glass)
    ctx.strokePath()

    // Bright left rim.
    ctx.setStrokeColor(C(255, 255, 255, 0.5))
    ctx.setLineWidth(smin(2.5, k, 0.7))
    ctx.addLines(between: [CGPoint(x: 322, y: 698), CGPoint(x: 322, y: 262)])
    ctx.strokePath()

    // Lid ellipse and inner opening.
    let lidFill = makeGrad([(0, C(255, 255, 255, 0.17)), (1, C(255, 255, 255, 0.05))])
    ctx.saveGState()
    ctx.addEllipse(in: ellipse(512, 700, 190, 48))
    ctx.clip()
    ctx.drawLinearGradient(lidFill, start: CGPoint(x: 0, y: 748), end: CGPoint(x: 0, y: 652), options: [])
    ctx.restoreGState()
    ctx.setStrokeColor(C(205, 235, 255, 0.45))
    ctx.setLineWidth(smin(4, k, 0.8))
    ctx.addEllipse(in: ellipse(512, 700, 190, 48))
    ctx.strokePath()
    ctx.setStrokeColor(C(255, 255, 255, 0.28))
    ctx.setLineWidth(smin(2, k, 0.6))
    ctx.addEllipse(in: ellipse(512, 700, 138, 30))
    ctx.strokePath()

    // Valve stub on the lid.
    let valve = roundedRect(494, 748, 36, 42, 10)
    ctx.saveGState()
    ctx.addPath(valve)
    ctx.clip()
    let valveMetal = makeGrad([(0, C(140, 152, 168)), (1, C(58, 68, 80))])
    ctx.drawLinearGradient(valveMetal, start: CGPoint(x: 494, y: 0), end: CGPoint(x: 530, y: 0), options: [])
    ctx.restoreGState()
    radialGlow(ctx, center: CGPoint(x: 512, y: 790), radius: 9, inner: C(190, 205, 220), outer: C(70, 82, 98))
    ctx.setStrokeColor(C(20, 28, 40, 0.6))
    ctx.setLineWidth(smin(1.6, k, 0.5))
    ctx.addEllipse(in: ellipse(512, 790, 9, 9))
    ctx.strokePath()

    // 7. Muon crossing the glass from outside the chamber.
    let muon = curve([
        .init(x: 330, y: 902), .init(x: 330, y: 760), .init(x: 352, y: 560), .init(x: 372, y: 352),
        .init(x: 380, y: 320), .init(x: 396, y: 302), .init(x: 404, y: 306),
    ])
    glowStroke(ctx, muon, scale: k, coreWidth: 7, core: C(196, 255, 106), halo: C(150, 255, 90, 0.5), blur: 20)

    // 8. Atmosphere: vignette and top sheen.
    radialGlow(ctx, center: CGPoint(x: 512, y: 500), radius: 600, inner: C(0, 0, 0, 0.28), outer: C(0, 0, 0, 0))
    let topSheen = makeGrad([(0, C(255, 255, 255, 0.1)), (1, C(255, 255, 255, 0))])
    ctx.drawLinearGradient(topSheen, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 620), options: [])

    ctx.restoreGState() // squircle clip

    // 9. Edge treatment.
    ctx.setStrokeColor(C(0, 0, 0, 0.35))
    ctx.setLineWidth(smin(2.6, k, 0.7))
    ctx.addPath(squirclePath)
    ctx.strokePath()
    ctx.setStrokeColor(C(255, 255, 255, 0.1))
    ctx.setLineWidth(smin(1.1, k, 0.4))
    ctx.addPath(squirclePath)
    ctx.strokePath()
}

// MARK: - Render every required size

func render(_ size: CGFloat) -> Data? {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                        bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawIcon(ctx, pixels: size)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])
}

let entries: [(pixels: CGFloat, name: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for entry in entries {
    let data = render(entry.pixels)
    try data!.write(to: URL(fileURLWithPath: iconSetDir + "/" + entry.name))
    print("wrote \(entry.name) (\(Int(entry.pixels)) px)")
}

try writeJSON("""
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""", to: iconSetDir + "/Contents.json")

let rootJSON = """
{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
if !FileManager.default.fileExists(atPath: assetsRoot + "/Contents.json") {
    try writeJSON(rootJSON, to: assetsRoot + "/Contents.json")
}

print("done: \(assetsRoot)")
