import Foundation

public struct CodexAppServerRateLimitsParser: Sendable {
    public init() {}

    public func parseQuota(from data: Data) throws -> CodexQuota {
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let result = envelope.result
        let rateLimits = result?.rateLimits ?? result?.rateLimitsByLimitId?["codex"]
        let windows = parseWindows(from: rateLimits)
        let resetCredits = result?.rateLimitResetCredits

        return CodexQuota(
            fiveHourRemainingPercent: windows.fiveHourRemainingPercent,
            weeklyRemainingPercent: windows.weeklyRemainingPercent,
            fiveHourResetAt: windows.fiveHourResetAt,
            weeklyResetAt: windows.weeklyResetAt,
            bankedResetAvailableCount: resetCredits?.availableCount,
            bankedResets: parseBankedResets(from: resetCredits)
        )
    }

    private func parseWindows(from rateLimits: RateLimits?) -> ParsedWindows {
        guard let rateLimits else {
            return ParsedWindows()
        }

        var parsed = ParsedWindows()
        for window in [rateLimits.primary, rateLimits.secondary].compactMap({ $0 }) {
            let remaining = window.usedPercent.map { min(100, max(0, 100 - $0)) }
            let resetAt = window.resetsAt.map(Date.init(timeIntervalSince1970:))

            switch window.windowDurationMins {
            case 300:
                parsed.fiveHourRemainingPercent = remaining
                parsed.fiveHourResetAt = resetAt
            case 10_080:
                parsed.weeklyRemainingPercent = remaining
                parsed.weeklyResetAt = resetAt
            default:
                continue
            }
        }

        return parsed
    }

    private func parseBankedResets(from summary: RateLimitResetCreditsSummary?) -> [CodexBankedReset] {
        summary?.credits?
            .filter { $0.status == "available" }
            .compactMap { credit in
                credit.expiresAt.map { CodexBankedReset(expiresAt: Date(timeIntervalSince1970: $0)) }
            } ?? []
    }

    private struct ResponseEnvelope: Decodable {
        let result: ResultPayload?
    }

    private struct ResultPayload: Decodable {
        let rateLimits: RateLimits?
        let rateLimitsByLimitId: [String: RateLimits]?
        let rateLimitResetCredits: RateLimitResetCreditsSummary?
    }

    private struct RateLimits: Decodable {
        let primary: RateLimitWindow?
        let secondary: RateLimitWindow?
    }

    private struct RateLimitWindow: Decodable {
        let usedPercent: Double?
        let windowDurationMins: Int?
        let resetsAt: TimeInterval?
    }

    private struct RateLimitResetCreditsSummary: Decodable {
        let availableCount: Int?
        let credits: [RateLimitResetCredit]?
    }

    private struct RateLimitResetCredit: Decodable {
        let status: String?
        let expiresAt: TimeInterval?
    }

    private struct ParsedWindows {
        var fiveHourRemainingPercent: Double?
        var weeklyRemainingPercent: Double?
        var fiveHourResetAt: Date?
        var weeklyResetAt: Date?
    }
}
