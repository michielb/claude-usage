import Foundation
import AppKit

enum ServiceState: Equatable {
    case loading        // starting up, no data yet
    case ready          // showing live usage data
    case noSession      // signed in, but no active usage window yet
    case needsSignIn    // no Claude credentials in the keychain — user must act
    case authExpired    // credentials present but rejected/expired — user must act
    case reconnecting   // temporary hiccup (offline, server busy, throttled) — retrying quietly
}

/// A ready-to-render row for a model-scoped weekly limit (e.g. Fable).
struct ModelLimitRow {
    let title: String
    let utilization: Double
    let target: Double
    let resetString: String
    let aheadString: String?
}

@MainActor
@Observable
final class UsageService {
    var usage: UsageResponse?
    var lastError: String?
    var lastUpdated: Date?
    var state: ServiceState = .loading

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    var fiveHourUtilization: Double {
        usage?.fiveHour?.utilization ?? 0
    }

    var sevenDayUtilization: Double {
        usage?.sevenDay?.utilization ?? 0
    }

    var fiveHourTarget: Double {
        paceTarget(resetDate: usage?.fiveHour?.resetDate, window: 5 * 3600)
    }

    var sevenDayTarget: Double {
        paceTarget(resetDate: usage?.sevenDay?.resetDate, window: 7 * 24 * 3600)
    }

    /// Model-scoped weekly limits (e.g. Fable), surfaced the same way as the
    /// 7-day tier — with the same pace marker and "Ahead by" readout.
    var modelLimitRows: [ModelLimitRow] {
        let week: TimeInterval = 7 * 24 * 3600
        return (usage?.limits ?? [])
            .filter { $0.kind == "weekly_scoped" }
            .compactMap { limit in
                guard let percent = limit.percent else { return nil }
                let target = paceTarget(resetDate: limit.resetDate, window: week)
                let name = limit.scope?.model?.displayName ?? "Model"
                return ModelLimitRow(
                    title: "7-Day \(name)",
                    utilization: percent,
                    target: target,
                    resetString: formatReset(limit.resetDate),
                    aheadString: aheadString(utilization: percent, target: target, window: week)
                )
            }
    }

    var fiveHourResetString: String {
        formatReset(usage?.fiveHour?.resetDate)
    }

    var sevenDayResetString: String {
        formatReset(usage?.sevenDay?.resetDate)
    }

    /// How far your usage runs ahead of the steady-pace line, expressed in time.
    /// nil when you're on or under pace (nothing to report).
    var fiveHourAheadString: String? {
        aheadString(utilization: fiveHourUtilization, target: fiveHourTarget, window: 5 * 3600)
    }

    var sevenDayAheadString: String? {
        aheadString(utilization: sevenDayUtilization, target: sevenDayTarget, window: 7 * 24 * 3600)
    }

    init() {
        startPolling()
        observeWake()
    }

    func refresh() {
        Task { await fetchUsage() }
    }

    private func startPolling() {
        Task { await fetchUsage() }
        timer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func fetchUsage() async {
        let token: String
        do {
            token = try getOAuthToken()
        } catch UsageError.noCredentials {
            state = .needsSignIn
            lastError = nil
            return
        } catch UsageError.invalidCredentials {
            state = .authExpired
            lastError = nil
            return
        } catch {
            // Reading the keychain itself failed — treat as a temporary hiccup.
            state = .reconnecting
            lastError = "Couldn't read credentials — retrying"
            return
        }

        // Retry transient conditions quietly instead of flashing an error at the
        // user. Only genuinely actionable problems (bad auth) surface immediately.
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let status = http?.statusCode ?? 0

                switch status {
                case 200:
                    handleSuccess(data)
                    return

                case 401, 403:
                    // The token is genuinely rejected — this needs the user to act.
                    state = .authExpired
                    lastError = nil
                    return

                case 429:
                    // Not a usage-limit the user can act on: the endpoint has
                    // nothing to report yet (e.g. no window has started) or is
                    // asking us to slow down. Retry quietly, then settle calmly.
                    if attempt < maxAttempts {
                        state = usage == nil ? .loading : .ready
                        try? await Task.sleep(nanoseconds: retryDelayNanos(http, attempt))
                        continue
                    }
                    // Still 429: if we have no data, we're simply waiting for a
                    // window to start; otherwise keep the last-known usage.
                    state = usage == nil ? .noSession : .ready
                    lastError = nil
                    return

                default:
                    // 5xx or anything unexpected: temporary. Retry, then keep
                    // whatever data we already have on screen.
                    if attempt < maxAttempts {
                        state = usage == nil ? .reconnecting : .ready
                        try? await Task.sleep(nanoseconds: retryDelayNanos(http, attempt))
                        continue
                    }
                    state = .reconnecting
                    lastError = "Claude servers are busy — retrying"
                    return
                }
            } catch {
                // Network-level failure (offline, DNS, timeout).
                if attempt < maxAttempts {
                    state = usage == nil ? .reconnecting : .ready
                    try? await Task.sleep(nanoseconds: retryDelayNanos(nil, attempt))
                    continue
                }
                state = .reconnecting
                lastError = "No connection to Claude — retrying"
                return
            }
        }
    }

    private func handleSuccess(_ data: Data) {
        let decoded: UsageResponse
        do {
            decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            // Log the raw response so we can diagnose unexpected shapes
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[ClaudeUsage] Decode failed: \(error)")
            print("[ClaudeUsage] Raw response: \(raw)")
            // Decode failed on a 200 — likely a "no session" response shape
            usage = nil
            lastError = nil
            lastUpdated = Date()
            state = .noSession
            return
        }

        // Determine if there's any active session data
        let hasActiveSession: Bool = {
            // Check if any tier has a reset date in the future
            let tiers = [decoded.fiveHour, decoded.sevenDay, decoded.sevenDaySonnet, decoded.sevenDayOpus]
            let now = Date()
            for tier in tiers.compactMap({ $0 }) {
                if let resetDate = tier.resetDate, resetDate > now {
                    return true
                }
                // If there's utilization > 0, treat as active even without a parseable reset date
                if tier.utilization > 0 {
                    return true
                }
            }
            return false
        }()

        if hasActiveSession {
            usage = decoded
            lastError = nil
            lastUpdated = Date()
            state = .ready
        } else {
            usage = nil
            lastError = nil
            lastUpdated = Date()
            state = .noSession
        }
    }

    /// Delay before the next retry. Honors a `Retry-After` header when present,
    /// otherwise backs off 2s then 5s.
    private func retryDelayNanos(_ response: HTTPURLResponse?, _ attempt: Int) -> UInt64 {
        let seconds: TimeInterval
        if let header = response?.value(forHTTPHeaderField: "Retry-After"), let parsed = Double(header) {
            seconds = min(max(parsed, 1), 30)
        } else {
            let backoff: [TimeInterval] = [2, 5]
            seconds = backoff[min(attempt - 1, backoff.count - 1)]
        }
        return UInt64(seconds * 1_000_000_000)
    }

    private func getOAuthToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jsonString.isEmpty else {
            throw UsageError.noCredentials
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw UsageError.invalidCredentials
        }

        return token
    }

    /// Where the steady-pace line sits right now, as a 0–100 percentage of the
    /// window elapsed. Shared by every windowed tier.
    private func paceTarget(resetDate: Date?, window: TimeInterval) -> Double {
        guard let resetDate = resetDate else { return 0 }
        let windowStart = resetDate.addingTimeInterval(-window)
        let elapsed = Date().timeIntervalSince(windowStart)
        return min(max(elapsed / window * 100, 0), 100)
    }

    private func formatReset(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "Now" }
        return formatDuration(remaining)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Time equivalent of how far usage sits past the pace marker. e.g. 62% used
    /// against a 48% pace over a 7-day window ≈ 23h ahead. nil when on/under pace.
    private func aheadString(utilization: Double, target: Double, window: TimeInterval) -> String? {
        guard utilization > target else { return nil }
        let aheadSeconds = (utilization - target) / 100 * window
        guard aheadSeconds >= 60 else { return nil }
        return formatDuration(aheadSeconds)
    }
}

enum UsageError: LocalizedError {
    case noCredentials
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Claude credentials found in keychain"
        case .invalidCredentials: return "Could not parse OAuth token from credentials"
        }
    }
}
