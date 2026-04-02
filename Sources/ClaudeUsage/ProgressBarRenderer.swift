import AppKit

struct BarSegment {
    let utilization: Double
    let target: Double
    let label: String
}

enum ProgressBarRenderer {
    static func render(segments: [BarSegment]) -> NSImage {
        let barWidth: CGFloat = 64
        let barHeight: CGFloat = 7
        let totalHeight: CGFloat = 18
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let spacing: CGFloat = 4
        let segmentGap: CGFloat = 8

        let greenColor = NSColor(srgbRed: 0.28, green: 0.70, blue: 0.38, alpha: 1.0)
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        // Calculate total width
        var totalWidth: CGFloat = 0
        var segmentWidths: [(percent: CGFloat, bar: CGFloat, label: CGFloat)] = []
        for (i, seg) in segments.enumerated() {
            let percentText = "\(Int(seg.utilization))%"
            let percentW = (percentText as NSString).size(withAttributes: textAttr).width
            let labelW = (seg.label as NSString).size(withAttributes: textAttr).width
            segmentWidths.append((percentW, barWidth, labelW))
            totalWidth += percentW + spacing + barWidth + spacing + labelW
            if i < segments.count - 1 {
                totalWidth += segmentGap
            }
        }

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            var x: CGFloat = 0

            for (i, seg) in segments.enumerated() {
                let percentText = "\(Int(seg.utilization))%"
                let widths = segmentWidths[i]

                // Percentage text
                let textHeight = (percentText as NSString).size(withAttributes: textAttr).height
                let textY = (rect.height - textHeight) / 2
                (percentText as NSString).draw(at: NSPoint(x: x, y: textY), withAttributes: textAttr)
                x += widths.percent + spacing

                // Bar
                let barY = (rect.height - barHeight) / 2
                let barRect = NSRect(x: x, y: barY, width: barWidth, height: barHeight)
                let radius: CGFloat = 3

                // Background track
                let bg = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
                NSColor(white: 0.5, alpha: 0.35).setFill()
                bg.fill()

                let util = min(max(seg.utilization, 0), 100) / 100.0
                let tgt = min(max(seg.target, 0), 100) / 100.0

                // Green fill
                let greenEnd = min(util, tgt)
                if greenEnd > 0 {
                    let greenRect = NSRect(x: barRect.minX, y: barRect.minY, width: barRect.width * CGFloat(greenEnd), height: barRect.height)
                    let greenPath = NSBezierPath(roundedRect: greenRect, xRadius: radius, yRadius: radius)
                    greenColor.setFill()
                    greenPath.fill()
                }

                // Red fill (excess beyond target)
                if util > tgt {
                    let redX = barRect.minX + barRect.width * CGFloat(tgt)
                    let redWidth = barRect.width * CGFloat(util - tgt)
                    let redRect = NSRect(x: redX, y: barRect.minY, width: redWidth, height: barRect.height)
                    let redPath = NSBezierPath(roundedRect: redRect, xRadius: radius, yRadius: radius)
                    NSColor.systemRed.setFill()
                    redPath.fill()
                }

                // Target marker (+)
                if tgt > 0 && tgt < 1 {
                    let markerX = barRect.minX + barRect.width * CGFloat(tgt)
                    let markerColor = NSColor.white.withAlphaComponent(0.9)
                    markerColor.setStroke()

                    let vLine = NSBezierPath()
                    vLine.move(to: NSPoint(x: markerX, y: barY - 2))
                    vLine.line(to: NSPoint(x: markerX, y: barY + barHeight + 2))
                    vLine.lineWidth = 1.5
                    vLine.stroke()

                    let crossWidth: CGFloat = 5
                    let hLine = NSBezierPath()
                    hLine.move(to: NSPoint(x: markerX - crossWidth / 2, y: barY + barHeight / 2))
                    hLine.line(to: NSPoint(x: markerX + crossWidth / 2, y: barY + barHeight / 2))
                    hLine.lineWidth = 1.5
                    hLine.stroke()
                }

                x += barWidth + spacing

                // Label
                let labelHeight = (seg.label as NSString).size(withAttributes: textAttr).height
                let labelY = (rect.height - labelHeight) / 2
                (seg.label as NSString).draw(at: NSPoint(x: x, y: labelY), withAttributes: textAttr)
                x += widths.label + segmentGap
            }

            return true
        }

        image.isTemplate = false
        return image
    }
}
