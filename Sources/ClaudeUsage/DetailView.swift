import SwiftUI
import ServiceManagement

struct DetailView: View {
    let service: UsageService
    var hud: HUDController? = nil
    var settings: AppSettings? = nil
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if service.state != .ready && service.state != .loading && service.state != .noSession {
                errorBanner
            }

            if service.state == .noSession {
                VStack(spacing: 4) {
                    Text("No active session")
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text("Usage resets when you send a message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
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

            // Controls
            if hud != nil || settings != nil {
                HStack(spacing: 8) {
                    if let hud = hud {
                        Button(hud.isVisible ? "Hide HUD" : "Show HUD") {
                            hud.toggle()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    if let settings = settings {
                        Button(settings.isCompactMode ? "Full Bar" : "Compact") {
                            settings.isCompactMode.toggle()
                            if settings.isCompactMode {
                                hud?.forceShow()
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    Toggle("Login", isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }
            }

            // Footer
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

            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .frame(width: 234)
    }

    @ViewBuilder
    private var errorBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch service.state {
            case .noCredentials:
                Label("No credentials found", systemImage: "key.slash")
                    .font(.caption.bold())
                Text("Run **claude** in Terminal to sign in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .invalidCredentials:
                Label("Invalid credentials", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text("Try signing out/in to Claude Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .httpError(let code):
                Label("HTTP \(code)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                if code == 401 {
                    Text("Token expired — run **claude** to re-auth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .networkError:
                Label("Connection error", systemImage: "wifi.slash")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text("Check your internet connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading, .ready, .noSession:
                EmptyView()
            }
        }
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
                    Rectangle()
                        .fill(.quaternary)

                    // Green portion
                    let greenEnd = target != nil ? min(utilization, target!) : utilization
                    if greenEnd > 0 {
                        Rectangle()
                            .fill(.green)
                            .frame(width: geo.size.width * CGFloat(greenEnd / 100))
                    }

                    // Red portion (over target)
                    if let target = target, utilization > target {
                        Rectangle()
                            .fill(Color(red: 0.824, green: 0.110, blue: 0.341))
                            .frame(width: geo.size.width * CGFloat((min(utilization, 100) - target) / 100))
                            .offset(x: geo.size.width * CGFloat(target / 100))
                    }

                }
            }
            .frame(height: 10)
            .overlay {
                // Target marker (extends beyond bar)
                if let target = target, target > 0, target < 100 {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.primary.opacity(0.6))
                            .frame(width: 1.5, height: 16)
                            .offset(x: geo.size.width * CGFloat(target / 100), y: -3)
                    }
                }
            }
            .padding(.vertical, 3) // room for marker to extend beyond bar

            if let resetString = resetString {
                Text("Resets in \(resetString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
