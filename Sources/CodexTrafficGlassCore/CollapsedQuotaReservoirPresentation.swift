import Foundation

public enum CollapsedQuotaReservoirPresentation {
    public static func remainingPercent(for quota: CodexQuota) -> Double? {
        quota.fiveHourRemainingPercent
    }
}
