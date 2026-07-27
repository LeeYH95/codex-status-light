import Foundation

public enum CodexState: Equatable, Sendable {
    case idle
    case thinking
    case running
    case processing
    case waiting
    case done
    case failed
    case stalled
    case unknown

    public var displayName: String {
        switch self {
        case .idle:
            "空闲"
        case .thinking:
            "思考中"
        case .running:
            "执行中"
        case .processing:
            "处理中"
        case .waiting:
            "待确认"
        case .done:
            "已完成"
        case .failed:
            "失败"
        case .stalled:
            "停滞"
        case .unknown:
            "未知"
        }
    }
}

public struct CodexBankedReset: Equatable, Sendable {
    public var expiresAt: Date

    public init(expiresAt: Date) {
        self.expiresAt = expiresAt
    }
}

public struct CodexQuota: Equatable, Sendable {
    public var fiveHourRemainingPercent: Double?
    public var weeklyRemainingPercent: Double?
    public var fiveHourResetAt: Date?
    public var weeklyResetAt: Date?
    public var bankedResetAvailableCount: Int?
    public var bankedResets: [CodexBankedReset]

    public init(
        fiveHourRemainingPercent: Double? = nil,
        weeklyRemainingPercent: Double? = nil,
        fiveHourResetAt: Date? = nil,
        weeklyResetAt: Date? = nil,
        bankedResetAvailableCount: Int? = nil,
        bankedResets: [CodexBankedReset] = []
    ) {
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.fiveHourResetAt = fiveHourResetAt
        self.weeklyResetAt = weeklyResetAt
        self.bankedResetAvailableCount = bankedResetAvailableCount
        self.bankedResets = bankedResets
    }
}

public struct CodexStatusSnapshot: Equatable, Sendable {
    public var state: CodexState
    public var title: String
    public var detail: String
    public var confidence: Double
    public var updatedAt: Date?
    public var quota: CodexQuota

    public init(
        state: CodexState,
        title: String,
        detail: String,
        confidence: Double,
        updatedAt: Date?,
        quota: CodexQuota = CodexQuota()
    ) {
        self.state = state
        self.title = title
        self.detail = detail
        self.confidence = confidence
        self.updatedAt = updatedAt
        self.quota = quota
    }

    public static let empty = CodexStatusSnapshot(
        state: .unknown,
        title: "Codex",
        detail: "等待活动",
        confidence: 0,
        updatedAt: nil
    )
}

public enum CodexParsedEvent: Equatable, Sendable {
    case taskStarted(Date)
    case reasoning(Date)
    case functionCall(name: String, at: Date)
    case functionOutput(text: String, exitCode: Int?, at: Date)
    case finalAnswer(Date)
    case taskComplete(success: Bool, at: Date)
    case taskAborted(Date)
    case tokenCount(input: Int?, output: Int?, at: Date)
    case quota(fiveHourUsedPercent: Double?, weeklyUsedPercent: Double?, fiveHourResetAt: Date?, weeklyResetAt: Date?, at: Date)
    case userInputNeeded(Date)

    public var occurredAt: Date {
        switch self {
        case let .taskStarted(date),
             let .reasoning(date),
             let .functionCall(_, date),
             let .functionOutput(_, _, date),
             let .finalAnswer(date),
             let .taskComplete(_, date),
             let .taskAborted(date),
             let .tokenCount(_, _, date),
             let .quota(_, _, _, _, date),
             let .userInputNeeded(date):
            date
        }
    }
}
