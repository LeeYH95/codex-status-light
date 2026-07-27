import Foundation

public enum WeeklyQuotaPresentation {
    public enum RemainingBand: Equatable, Sendable {
        case ample
        case caution
        case critical
        case unknown
    }

    public static let weeklyCycleDuration: TimeInterval = 7 * 24 * 60 * 60

    public static func remainingBand(for remainingPercent: Double?) -> RemainingBand {
        guard let remainingPercent else {
            return .unknown
        }

        switch remainingPercent {
        case 60...:
            return .ample
        case 25...:
            return .caution
        default:
            return .critical
        }
    }

    public static func normalizedRemainingProgress(for remainingPercent: Double?) -> Double {
        min(1, max(0, (remainingPercent ?? 0) / 100))
    }

    public static func cycleElapsedProgress(resetAt: Date?, now: Date) -> Double? {
        guard let resetAt else {
            return nil
        }

        let cycleStartedAt = resetAt.addingTimeInterval(-weeklyCycleDuration)
        let elapsed = now.timeIntervalSince(cycleStartedAt)
        return min(1, max(0, elapsed / weeklyCycleDuration))
    }

    public static func resetCountdownLabel(resetAt: Date?, now: Date) -> String {
        guard let resetAt else {
            return "--"
        }

        let remainingInterval = resetAt.timeIntervalSince(now)
        guard remainingInterval > 0 else {
            return "等待额度刷新"
        }

        let remainingHours = Int(remainingInterval / 3_600)
        guard remainingHours > 0 else {
            return "不足1小时"
        }

        let days = remainingHours / 24
        let hours = remainingHours % 24
        return days > 0 ? "\(days)天\(hours)小时" : "\(hours)小时"
    }

    public static func nextHourlyRefresh(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.end ?? date.addingTimeInterval(3_600)
    }
}
