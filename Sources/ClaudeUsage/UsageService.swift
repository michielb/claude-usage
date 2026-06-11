import Foundation
import AppKit

enum ServiceState: Equatable {
    case loading
    case ready
    case noSession
    case noCredentials
    case invalidCredentials
    case networkError(String)
    case httpError(Int)
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
        guard let resetDate = usage?.fiveHour?.resetDate else { return 0 }
        let windowStart = resetDate.addingTimeInterval(-5 * 3600)
        let now = Date()
        let elapsed = now.timeIntervalSince(windowStart)
        return min(max(elapsed / (5 * 3600) * 100, 0), 100)
    }

    var sevenDayTarget: Double {
        guard let resetDate = usage?.sevenDay?.resetDate else { return 0 }
        let windowStart = resetDate.addingTimeInterval(-7 * 24 * 3600)
        let now = Date()
        let elapsed = now.timeIntervalSince(windowStart)
        return min(max(elapsed / (7 * 24 * 3600) * 100, 0), 100)
    }

    var fiveHourResetString: String {
        formatReset(usage?.fiveHour?.resetDate)
    }

    var sevenDayResetString: String {
        formatReset(usage?.sevenDay?.resetDate)
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
        } catch let error as UsageError {
            switch error {
            case .noCredentials:
                state = .noCredentials
                lastError = error.localizedDescription
            case .invalidCredentials:
                state = .invalidCredentials
                lastError = error.localizedDescription
            }
            return
        } catch {
            state = .networkError(error.localizedDescription)
            lastError = error.localizedDescription
            return
        }

        do {
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                state = .httpError(httpResponse.statusCode)
                lastError = "HTTP \(httpResponse.statusCode)"
                return
            }

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
        } catch {
            state = .networkError(error.localizedDescription)
            lastError = error.localizedDescription
        }
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

    private func formatReset(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "Now" }
        let totalMinutes = Int(remaining) / 60
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
