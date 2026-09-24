import Foundation

public enum RecentQuotaEventSelector {
    public static func latest(in eventGroups: [[CodexParsedEvent]]) -> CodexParsedEvent? {
        var latestQuotaEvent: CodexParsedEvent?

        for event in eventGroups.joined() {
            switch event {
            case .quota, .quotaSnapshot:
                break
            default:
                continue
            }

            guard let currentLatest = latestQuotaEvent else {
                latestQuotaEvent = event
                continue
            }

            if event.occurredAt > currentLatest.occurredAt {
                latestQuotaEvent = event
            }
        }

        return latestQuotaEvent
    }
}
