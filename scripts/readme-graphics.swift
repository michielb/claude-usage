import AppKit
import SwiftUI

// Renders README graphics using the app's real rendering code.
// Usage: render <output-dir>

func savePNG(_ image: NSImage, scale: CGFloat, to path: String) {
    let w = Int(image.size.width * scale), h = Int(image.size.height * scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
        image.draw(in: NSRect(origin: .zero, size: image.size))
    }
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(w)x\(h)px, display width \(Int(image.size.width))pt)")
}

func savePNG(_ cg: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: cg)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(cg.width)x\(cg.height)px, display width \(cg.width / 2)pt)")
}

// Screenshot stand-in for DetailView: same tier rows (the app's real UsageTierView),
// but plain Text in place of Button/Toggle — ImageRenderer can't rasterize
// AppKit-backed controls offscreen and draws placeholder icons instead.
struct PanelShot: View {
    let service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fiveHour = service.usage?.fiveHour {
                UsageTierView(
                    title: "5-Hour Window",
                    utilization: fiveHour.utilization,
                    target: service.fiveHourTarget,
                    resetString: service.fiveHourResetString,
                    aheadString: service.fiveHourAheadString
                )
            }
            if let sevenDay = service.usage?.sevenDay {
                Divider()
                UsageTierView(
                    title: "7-Day Usage",
                    utilization: sevenDay.utilization,
                    target: service.sevenDayTarget,
                    resetString: service.sevenDayResetString,
                    aheadString: service.sevenDayAheadString
                )
            }
            ForEach(Array(service.modelLimitRows.enumerated()), id: \.offset) { _, row in
                Divider()
                UsageTierView(
                    title: row.title,
                    utilization: row.utilization,
                    target: row.target,
                    resetString: row.resetString,
                    aheadString: row.aheadString
                )
            }
            Divider()
            HStack(spacing: 8) {
                Text("Hide HUD")
                Text("Compact")
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundStyle(.blue)
                    Text("Login")
                }
            }
            .font(.caption)
            HStack {
                Text("Updated \(Date().formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Refresh").font(.caption)
                Text("Quit").font(.caption)
            }
            Text("v1.1.7")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 234)
    }
}

MainActor.assumeIsolated {
    let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

    // Mock usage data: 5h slightly over pace, 7d slightly over pace, Fable under pace.
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    func isoIn(_ s: TimeInterval) -> String { iso.string(from: Date().addingTimeInterval(s)) }
    let json = """
    {"five_hour": {"utilization": 52, "resets_at": "\(isoIn(2 * 3600 + 48 * 60))"},
     "seven_day": {"utilization": 62, "resets_at": "\(isoIn(3 * 86400 + 3600))"},
     "limits": [{"kind": "weekly_scoped", "percent": 31,
                 "resets_at": "\(isoIn(3 * 86400 + 3600))",
                 "scope": {"model": {"display_name": "Fable"}}}]}
    """

    let service = UsageService()
    service.usage = try! JSONDecoder().decode(UsageResponse.self, from: json.data(using: .utf8)!)
    service.state = .ready
    service.lastUpdated = Date()

    // 1. Menu bar strip: the exact NSImage the menu bar shows, on a dark menu-bar background.
    let segments = [
        BarSegment(utilization: service.fiveHourUtilization, target: service.fiveHourTarget, label: "5h"),
        BarSegment(utilization: service.sevenDayUtilization, target: service.sevenDayTarget, label: "7d"),
    ]
    let bar = ProgressBarRenderer.render(segments: segments)
    let pad: CGFloat = 14
    let stripH: CGFloat = 30
    let stripW = bar.size.width + pad * 2
    let strip = NSImage(size: NSSize(width: stripW, height: stripH), flipped: false) { rect in
        let bg = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).setFill()
        bg.fill()
        bar.draw(in: NSRect(x: pad, y: (rect.height - bar.size.height) / 2,
                            width: bar.size.width, height: bar.size.height))
        return true
    }
    savePNG(strip, scale: 2, to: outDir + "/menubar.png")

    // 2. Dropdown panel with all tiers and controls, dark.
    let panel = PanelShot(service: service)
        .background(Color(nsColor: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.14, alpha: 1)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .environment(\.colorScheme, .dark)
    let renderer = ImageRenderer(content: panel)
    renderer.scale = 2
    if let cg = renderer.cgImage {
        savePNG(cg, to: outDir + "/detail.png")
    } else {
        print("ERROR: ImageRenderer produced no image")
        exit(1)
    }
}
