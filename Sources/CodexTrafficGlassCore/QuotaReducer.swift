import Foundation

public struct QuotaReducer: Sendable {
    public init() {}

    public func reduce(current: CodexQuota, event: CodexParsedEvent) -> CodexQuota {
        guard case let .quota(fiveHourUsed, weeklyUsed, fiveHourResetAt, weeklyResetAt, _) = event else {
            return current
        }

        return CodexQuota(
            fiveHourRemainingPercent: remaining(fromUsedPercent: fiveHourUsed) ?? current.fiveHourRemainingPercent,
            weeklyRemainingPercent: remaining(fromUsedPercent: weeklyUsed) ?? current.weeklyRemainingPercent,
            fiveHourResetAt: fiveHourResetAt ?? current.fiveHourResetAt,
            weeklyResetAt: weeklyResetAt ?? current.weeklyResetAt,
            bankedResetAvailableCount: current.bankedResetAvailableCount,
            bankedResets: current.bankedResets
        )
    }

    private func remaining(fromUsedPercent usedPercent: Double?) -> Double? {
        guard let usedPercent else {
            return nil
        }

        return min(100, max(0, 100 - usedPercent))
    }
}
