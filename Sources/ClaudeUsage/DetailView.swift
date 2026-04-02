import SwiftUI

struct DetailView: View {
    let service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = service.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                }
            }

            if let fiveHour = service.usage?.fiveHour {
                UsageTierView(
                    title: "5-Hour Window",
                    utilization: fiveHour.utilization,
                    target: service.fiveHourTarget,
                    resetString: service.fiveHourResetString
                )
            }

            if let sevenDay = service.usage?.sevenDay {
                Divider()
                UsageTierView(
                    title: "7-Day Usage",
                    utilization: sevenDay.utilization,
                    target: service.sevenDayTarget,
                    resetString: service.sevenDayResetString
                )
            }

            if let sonnet = service.usage?.sevenDaySonnet {
                UsageTierView(
                    title: "7-Day Sonnet",
                    utilization: sonnet.utilization,
                    target: nil,
                    resetString: nil
                )
            }

            if let opus = service.usage?.sevenDayOpus {
                UsageTierView(
                    title: "7-Day Opus",
                    utilization: opus.utilization,
                    target: nil,
                    resetString: nil
                )
            }

            Divider()

            HStack {
                if let lastUpdated = service.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    service.refresh()
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

struct UsageTierView: View {
    let title: String
    let utilization: Double
    let target: Double?
    let resetString: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontDesign(.rounded)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)

                    // Green portion
                    let greenEnd = target != nil ? min(utilization, target!) : utilization
                    if greenEnd > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .frame(width: geo.size.width * CGFloat(greenEnd / 100))
                    }

                    // Red portion (over target)
                    if let target = target, utilization > target {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red)
                            .frame(width: geo.size.width * CGFloat((min(utilization, 100) - target) / 100))
                            .offset(x: geo.size.width * CGFloat(target / 100))
                    }

                    // Target marker
                    if let target = target, target > 0, target < 100 {
                        Rectangle()
                            .fill(.primary.opacity(0.6))
                            .frame(width: 1.5)
                            .offset(x: geo.size.width * CGFloat(target / 100))
                    }
                }
            }
            .frame(height: 10)

            if let resetString = resetString {
                Text("Resets in \(resetString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
