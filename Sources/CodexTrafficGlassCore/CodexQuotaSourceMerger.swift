import Foundation

public enum CodexQuotaSourceMerger {
    /// Uses session-log quota as a fallback, while preserving every available
    /// field from the current App Server response as the authoritative value.
    public static func resolving(logQuota: CodexQuota, liveQuota: CodexQuota?) -> CodexQuota {
        guard let liveQuota else {
            return logQuota
        }

        let hasLiveRateLimitWindow = liveQuota.fiveHourRemainingPercent != nil
            || liveQuota.weeklyRemainingPercent != nil

        return CodexQuota(
            fiveHourRemainingPercent: hasLiveRateLimitWindow
                ? liveQuota.fiveHourRemainingPercent
                : logQuota.fiveHourRemainingPercent,
            weeklyRemainingPercent: hasLiveRateLimitWindow
                ? liveQuota.weeklyRemainingPercent
                : logQuota.weeklyRemainingPercent,
            fiveHourResetAt: hasLiveRateLimitWindow ? liveQuota.fiveHourResetAt : logQuota.fiveHourResetAt,
            weeklyResetAt: hasLiveRateLimitWindow ? liveQuota.weeklyResetAt : logQuota.weeklyResetAt,
            bankedResetAvailableCount: liveQuota.bankedResetAvailableCount ?? logQuota.bankedResetAvailableCount,
            bankedResets: liveQuota.bankedResetAvailableCount == nil ? logQuota.bankedResets : liveQuota.bankedResets
        )
    }
}
