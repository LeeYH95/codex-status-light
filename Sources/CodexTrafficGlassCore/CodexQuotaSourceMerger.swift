import Foundation

public enum CodexQuotaSourceMerger {
    /// Uses session-log quota as a fallback, while preserving every available
    /// field from the current App Server response as the authoritative value.
    public static func resolving(logQuota: CodexQuota, liveQuota: CodexQuota?) -> CodexQuota {
        guard let liveQuota else {
            return logQuota
        }

        return CodexQuota(
            fiveHourRemainingPercent: liveQuota.fiveHourRemainingPercent ?? logQuota.fiveHourRemainingPercent,
            weeklyRemainingPercent: liveQuota.weeklyRemainingPercent ?? logQuota.weeklyRemainingPercent,
            fiveHourResetAt: liveQuota.fiveHourResetAt ?? logQuota.fiveHourResetAt,
            weeklyResetAt: liveQuota.weeklyResetAt ?? logQuota.weeklyResetAt,
            bankedResetAvailableCount: liveQuota.bankedResetAvailableCount ?? logQuota.bankedResetAvailableCount,
            bankedResets: liveQuota.bankedResetAvailableCount == nil ? logQuota.bankedResets : liveQuota.bankedResets
        )
    }
}
