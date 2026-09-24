import Foundation

public struct QuotaReducer: Sendable {
    public init() {}

    public func reduce(current: CodexQuota, event: CodexParsedEvent) -> CodexQuota {
        switch event {
        case let .quota(fiveHourUsed, weeklyUsed, fiveHourResetAt, weeklyResetAt, _):
            return CodexQuota(
                fiveHourRemainingPercent: remaining(fromUsedPercent: fiveHourUsed) ?? current.fiveHourRemainingPercent,
                weeklyRemainingPercent: remaining(fromUsedPercent: weeklyUsed) ?? current.weeklyRemainingPercent,
                fiveHourResetAt: fiveHourResetAt ?? current.fiveHourResetAt,
                weeklyResetAt: weeklyResetAt ?? current.weeklyResetAt,
                bankedResetAvailableCount: current.bankedResetAvailableCount,
                bankedResets: current.bankedResets
            )
        case let .quotaSnapshot(fiveHourUsed, weeklyUsed, fiveHourResetAt, weeklyResetAt, _):
            return CodexQuota(
                fiveHourRemainingPercent: remaining(fromUsedPercent: fiveHourUsed),
                weeklyRemainingPercent: remaining(fromUsedPercent: weeklyUsed),
                fiveHourResetAt: fiveHourResetAt,
                weeklyResetAt: weeklyResetAt,
                bankedResetAvailableCount: current.bankedResetAvailableCount,
                bankedResets: current.bankedResets
            )
        default:
            return current
        }
    }

    private func remaining(fromUsedPercent usedPercent: Double?) -> Double? {
        guard let usedPercent else {
            return nil
        }

        return min(100, max(0, 100 - usedPercent))
    }
}
