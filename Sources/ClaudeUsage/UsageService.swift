import Foundation
import AppKit

@MainActor
@Observable
final class UsageService {
    var usage: UsageResponse?
    var lastError: String?
    var lastUpdated: Date?

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
        do {
            let token = try getOAuthToken()
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                lastError = "HTTP \(httpResponse.statusCode)"
                return
            }

            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            usage = decoded
            lastError = nil
            lastUpdated = Date()
        } catch {
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
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
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
