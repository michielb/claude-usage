import AppKit

enum ProgressBarRenderer {
    static func render(
        utilization: Double,
        target: Double,
        timeLeft: String
    ) -> NSImage {
        let barWidth: CGFloat = 80
        let barHeight: CGFloat = 7
        let totalHeight: CGFloat = 18
        let percentText = "\(Int(utilization))%"
        let suffixText = timeLeft

        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)

        let percentAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let suffixAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let percentSize = (percentText as NSString).size(withAttributes: percentAttr)
        let suffixSize = (suffixText as NSString).size(withAttributes: suffixAttr)

        let spacing: CGFloat = 4
        let totalWidth = percentSize.width + spacing + barWidth + spacing + suffixSize.width

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            var x: CGFloat = 0

            // Draw percentage text
            let percentY = (rect.height - percentSize.height) / 2
            (percentText as NSString).draw(at: NSPoint(x: x, y: percentY), withAttributes: percentAttr)
            x += percentSize.width + spacing

            // Draw bar
            let barY = (rect.height - barHeight) / 2
            let barRect = NSRect(x: x, y: barY, width: barWidth, height: barHeight)
            let radius: CGFloat = 3

            // Background track
            let bg = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
            NSColor(white: 0.5, alpha: 0.35).setFill()
            bg.fill()

            let util = min(max(utilization, 0), 100) / 100.0
            let tgt = min(max(target, 0), 100) / 100.0

            // Green fill
            let greenEnd = min(util, tgt)
            if greenEnd > 0 {
                let greenRect = NSRect(x: barRect.minX, y: barRect.minY, width: barRect.width * CGFloat(greenEnd), height: barRect.height)
                let greenPath = NSBezierPath(roundedRect: greenRect, xRadius: radius, yRadius: radius)
                NSColor(srgbRed: 0.28, green: 0.70, blue: 0.38, alpha: 1.0).setFill()
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

            // Draw "5h" suffix
            let suffixY = (rect.height - suffixSize.height) / 2
            (suffixText as NSString).draw(at: NSPoint(x: x, y: suffixY), withAttributes: suffixAttr)

            return true
        }

        image.isTemplate = false
        return image
    }
}
