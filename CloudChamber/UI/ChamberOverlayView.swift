import AppKit

final class ChamberOverlayView: NSView {
    var configuration = ChamberConfiguration.default {
        didSet { needsDisplay = true }
    }

    var statistics = SimulationStatistics() {
        didSet { needsDisplay = true }
    }

    var isRunning = true {
        didSet { needsDisplay = true }
    }

    private struct LegendEntry {
        let color: NSColor
        let label: String
        let isConversion: Bool
    }

    private static let conversionColor = NSColor(
        calibratedRed: 0.16,
        green: 0.47,
        blue: 0.33,
        alpha: 1
    )

    private static let legendEntries: [LegendEntry] = [
        LegendEntry(color: ParticleKind.alpha.color, label: ParticleKind.alpha.legendTitle, isConversion: false),
        LegendEntry(color: ParticleKind.betaMinus.color, label: ParticleKind.betaMinus.legendTitle, isConversion: false),
        LegendEntry(color: ParticleKind.betaPlus.color, label: ParticleKind.betaPlus.legendTitle, isConversion: false),
        LegendEntry(color: ParticleKind.muon.color, label: ParticleKind.muon.legendTitle, isConversion: false),
        LegendEntry(color: ParticleKind.proton.color, label: ParticleKind.proton.legendTitle, isConversion: false),
        LegendEntry(color: ParticleKind.deltaElectron.color, label: ParticleKind.deltaElectron.legendTitle, isConversion: false),
        LegendEntry(color: conversionColor, label: "γ → e⁺e⁻", isConversion: true)
    ]

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if configuration.showStatistics {
            drawStatisticsOverlay(in: context)
        }
        if configuration.showLegend {
            drawLegendOverlay(in: context)
        }
        drawCameraHint(in: context)
        if !isRunning {
            drawPausedBadge(in: context)
        }
    }

    // MARK: - Overlays

    private func drawStatisticsOverlay(in context: CGContext) {
        let dataFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        let titleFont = NSFont.systemFont(ofSize: 9, weight: .semibold)

        let countLine = [
            "α \(statistics.count(for: .alpha))",
            "β⁻ \(statistics.count(for: .betaMinus))",
            "β⁺ \(statistics.count(for: .betaPlus))",
            "μ \(statistics.count(for: .muon))",
            "p \(statistics.count(for: .proton))",
            "δ \(statistics.count(for: .deltaElectron))"
        ].joined(separator: "   ")

        let activityLine = "\(statistics.totalEvents) events   "
            + "\(statistics.visibleTracks) tracks   "
            + "\(statistics.activeParticles) active"

        let titleWidth = measureText("CHAMBER ACTIVITY", font: titleFont)
        let width = min(
            bounds.width - 28,
            max(titleWidth, max(
                measureText(countLine, font: dataFont),
                measureText(activityLine, font: dataFont)
            )) + 24
        )
        let rect = CGRect(x: 14, y: 14, width: width, height: 52)
        drawCard(in: rect, context: context)

        drawText(
            "CHAMBER ACTIVITY",
            at: CGPoint(x: rect.minX + 12, y: rect.minY + 8),
            font: titleFont,
            color: NSColor(calibratedWhite: 0.42, alpha: 0.95)
        )
        drawText(
            activityLine,
            at: CGPoint(x: rect.minX + 12, y: rect.minY + 22),
            font: dataFont,
            color: NSColor(calibratedWhite: 0.20, alpha: 1)
        )
        drawText(
            countLine,
            at: CGPoint(x: rect.minX + 12, y: rect.minY + 36),
            font: dataFont,
            color: NSColor(calibratedWhite: 0.36, alpha: 1)
        )
    }

    private func drawLegendOverlay(in context: CGContext) {
        let titleFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
        let rowFont = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        let rowHeight: CGFloat = 17
        let columns = 2
        let rows = Int(ceil(Double(Self.legendEntries.count) / Double(columns)))
        let cardWidth = min(bounds.width - 28, 300)
        let cardHeight = 30 + CGFloat(rows) * rowHeight + 4

        let rect = CGRect(
            x: 14,
            y: bounds.height - cardHeight - 14,
            width: cardWidth,
            height: cardHeight
        )
        drawCard(in: rect, context: context)

        drawText(
            "PARTICLES",
            at: CGPoint(x: rect.minX + 12, y: rect.minY + 9),
            font: titleFont,
            color: NSColor(calibratedWhite: 0.42, alpha: 0.95)
        )

        let columnGap: CGFloat = 14
        let columnWidth = (cardWidth - 24 - columnGap) / 2

        for (index, entry) in Self.legendEntries.enumerated() {
            let column = index / rows
            let row = index % rows
            let x = rect.minX + 12 + CGFloat(column) * (columnWidth + columnGap)
            let y = rect.minY + 28 + CGFloat(row) * rowHeight
            let centerY = y + rowHeight * 0.5

            if entry.isConversion {
                context.setStrokeColor(entry.color.withAlphaComponent(0.9).cgColor)
                context.setLineWidth(1)
                context.strokeEllipse(
                    in: CGRect(x: x + 3, y: centerY - 3, width: 6, height: 6)
                )
                context.move(to: CGPoint(x: x + 6, y: centerY - 6))
                context.addLine(to: CGPoint(x: x + 6, y: centerY + 6))
                context.move(to: CGPoint(x: x + 3, y: centerY))
                context.addLine(to: CGPoint(x: x + 9, y: centerY))
                context.strokePath()
            } else {
                context.setStrokeColor(entry.color.cgColor)
                context.setLineWidth(2.4)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: x, y: centerY))
                context.addLine(to: CGPoint(x: x + 15, y: centerY))
                context.strokePath()
            }

            drawText(
                entry.label,
                at: CGPoint(x: x + 22, y: y + 2),
                font: rowFont,
                color: NSColor(calibratedWhite: 0.25, alpha: 1)
            )
        }
    }

    private func drawCameraHint(in context: CGContext) {
        let font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        let text = "Drag to orbit  ·  Scroll to zoom"
        let textWidth = measureText(text, font: font)
        let width = min(bounds.width - 28, textWidth + 22)
        let rect = CGRect(
            x: bounds.width - width - 14,
            y: bounds.height - 38,
            width: width,
            height: 24
        )
        drawCard(in: rect, context: context)
        drawText(
            text,
            at: CGPoint(x: rect.minX + 11, y: rect.minY + 5),
            font: font,
            color: NSColor(calibratedWhite: 0.40, alpha: 1)
        )
    }

    private func drawPausedBadge(in context: CGContext) {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let textWidth = measureText("Paused", font: font)
        let rect = CGRect(
            x: bounds.width - textWidth - 38,
            y: 14,
            width: textWidth + 24,
            height: 26
        )
        drawCard(in: rect, context: context)

        context.setFillColor(NSColor(calibratedWhite: 0.42, alpha: 0.9).cgColor)
        context.fillEllipse(in: CGRect(x: rect.minX + 10, y: rect.midY - 2.5, width: 5, height: 5))

        drawText(
            "Paused",
            at: CGPoint(x: rect.minX + 21, y: rect.minY + 6),
            font: font,
            color: NSColor(calibratedWhite: 0.28, alpha: 1)
        )
    }

    private func drawCard(in rect: CGRect, context: CGContext) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: 8,
            cornerHeight: 8,
            transform: nil
        )
        context.addPath(path)
        context.setFillColor(NSColor.white.withAlphaComponent(0.88).cgColor)
        context.fillPath()

        context.addPath(path)
        context.setStrokeColor(NSColor(calibratedWhite: 0, alpha: 0.08).cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }

    // MARK: - Text

    private func measureText(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: NSColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}
