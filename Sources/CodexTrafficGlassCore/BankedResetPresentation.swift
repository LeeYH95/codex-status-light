import Foundation

public enum BankedResetPresentation {
    public static func summaryLabel(for quota: CodexQuota) -> String {
        let availableCount = quota.bankedResetAvailableCount ?? quota.bankedResets.count
        guard availableCount != 0 else {
            return ""
        }

        return "重置次数 \(availableCount) 次"
    }

    public static func sortedResets(for quota: CodexQuota) -> [CodexBankedReset] {
        quota.bankedResets.sorted { lhs, rhs in
            lhs.expiresAt < rhs.expiresAt
        }
    }

    public static func earliestExpirationLabel(
        for quota: CodexQuota,
        now: Date = Date()
    ) -> String? {
        guard let earliest = sortedResets(for: quota).first else {
            return nil
        }

        let seconds = earliest.expiresAt.timeIntervalSince(now)
        if seconds <= 0 {
            return "已有重置次数过期"
        }

        let days = max(1, Int(ceil(seconds / 86_400)))
        return "最早 \(days) 天后过期"
    }
}
