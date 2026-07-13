import Foundation

struct UsageResponse: Codable, Sendable {
    let fiveHour: UsageTier?
    let sevenDay: UsageTier?
    let sevenDaySonnet: UsageTier?
    let sevenDayOpus: UsageTier?
    let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case limits
    }
}

struct UsageTier: Codable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? { parseISODate(resetsAt) }
}

/// One entry in the API's `limits` array. Model-scoped weekly limits (e.g. Fable)
/// appear only here, not as a top-level field. Fields are lenient so an unexpected
/// entry can't fail the whole decode.
struct Limit: Codable, Sendable {
    let kind: String?
    let percent: Double?
    let resetsAt: String?
    let scope: LimitScope?

    enum CodingKeys: String, CodingKey {
        case kind
        case percent
        case resetsAt = "resets_at"
        case scope
    }

    var resetDate: Date? { parseISODate(resetsAt) }
}

struct LimitScope: Codable, Sendable {
    let model: LimitModel?
}

struct LimitModel: Codable, Sendable {
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private func parseISODate(_ string: String?) -> Date? {
    guard let string = string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
}
