import Foundation

public struct GlobalStatusAggregator: Sendable {
    private let statusReducer: StatusReducer
    private let now: Date
    private let completionDisplayDuration: TimeInterval
    private let monitoringHorizon: TimeInterval

    public init(
        statusReducer: StatusReducer = StatusReducer(),
        now: Date = Date(),
        completionDisplayDuration: TimeInterval = 180,
        monitoringHorizon: TimeInterval = 6 * 60 * 60
    ) {
        self.statusReducer = statusReducer
        self.now = now
        self.completionDisplayDuration = completionDisplayDuration
        self.monitoringHorizon = monitoringHorizon
    }

    public func reduce(
        current: CodexStatusSnapshot,
        sessionEvents: [[CodexParsedEvent]]
    ) -> CodexStatusSnapshot {
        let candidates = sessionEvents.compactMap { events -> CodexStatusSnapshot? in
            guard containsStatusEvent(events) else {
                return nil
            }

            var snapshot = CodexStatusSnapshot(
                state: .unknown,
                title: "Codex",
                detail: "等待活动",
                confidence: 0,
                updatedAt: nil,
                quota: current.quota
            )

            for event in events {
                snapshot = statusReducer.reduce(current: snapshot, event: event, now: now)
            }

            let refreshed = statusReducer.refresh(current: snapshot, now: now)
            guard isInsideMonitoringHorizon(refreshed) else {
                return nil
            }

            return refreshed
        }

        guard let selected = candidates.max(by: shouldPreferSecondCandidate) else {
            return CodexStatusSnapshot(
                state: .idle,
                title: "空闲",
                detail: "暂无正在进行的 Codex 任务",
                confidence: 0.55,
                updatedAt: nil,
                quota: current.quota
            )
        }

        return normalize(selected, currentQuota: current.quota)
    }

    private func containsStatusEvent(_ events: [CodexParsedEvent]) -> Bool {
        events.contains { event in
            switch event {
            case .quota, .quotaSnapshot, .tokenCount:
                false
            case .taskStarted, .reasoning, .functionCall, .functionOutput, .finalAnswer, .taskComplete, .taskAborted, .userInputNeeded:
                true
            }
        }
    }

    private func shouldPreferSecondCandidate(
        _ lhs: CodexStatusSnapshot,
        _ rhs: CodexStatusSnapshot
    ) -> Bool {
        let leftPriority = priority(for: lhs)
        let rightPriority = priority(for: rhs)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        return (lhs.updatedAt ?? .distantPast) < (rhs.updatedAt ?? .distantPast)
    }

    private func isInsideMonitoringHorizon(_ snapshot: CodexStatusSnapshot) -> Bool {
        guard let updatedAt = snapshot.updatedAt else {
            return false
        }

        return now.timeIntervalSince(updatedAt) <= monitoringHorizon
    }

    private func priority(for snapshot: CodexStatusSnapshot) -> Int {
        switch snapshot.state {
        case .failed, .stalled:
            100
        case .waiting:
            90
        case .running:
            80
        case .thinking:
            70
        case .processing:
            60
        case .done:
            30
        case .idle:
            10
        case .unknown:
            0
        }
    }

    private func normalize(
        _ snapshot: CodexStatusSnapshot,
        currentQuota: CodexQuota
    ) -> CodexStatusSnapshot {
        let quota = snapshot.quota == CodexQuota() ? currentQuota : snapshot.quota

        switch snapshot.state {
        case .failed:
            return CodexStatusSnapshot(
                state: .failed,
                title: "任务失败",
                detail: "有 Codex 对话执行失败",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .stalled:
            return CodexStatusSnapshot(
                state: .stalled,
                title: "需要检查",
                detail: "有 Codex 对话长时间没有新动态",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .waiting:
            return CodexStatusSnapshot(
                state: .waiting,
                title: "需要确认",
                detail: "有 Codex 对话正在等待你处理",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .running:
            return CodexStatusSnapshot(
                state: .running,
                title: "Codex 正在执行",
                detail: "有 Codex 对话正在运行工具或命令",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .thinking:
            return CodexStatusSnapshot(
                state: .thinking,
                title: "Codex 正在思考",
                detail: "有 Codex 对话正在分析任务",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .processing:
            return CodexStatusSnapshot(
                state: .processing,
                title: "处理中",
                detail: "有对话较久未更新，可能仍在执行",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .done:
            guard
                let updatedAt = snapshot.updatedAt,
                now.timeIntervalSince(updatedAt) <= completionDisplayDuration
            else {
                return CodexStatusSnapshot(
                    state: .idle,
                    title: "空闲",
                    detail: "暂无正在进行的 Codex 任务",
                    confidence: 0.55,
                    updatedAt: snapshot.updatedAt,
                    quota: quota
                )
            }

            return CodexStatusSnapshot(
                state: .done,
                title: "任务已完成",
                detail: "最近的 Codex 任务已完成",
                confidence: snapshot.confidence,
                updatedAt: updatedAt,
                quota: quota
            )
        case .idle:
            return CodexStatusSnapshot(
                state: .idle,
                title: "空闲",
                detail: "暂无正在进行的 Codex 任务",
                confidence: snapshot.confidence,
                updatedAt: snapshot.updatedAt,
                quota: quota
            )
        case .unknown:
            return snapshot
        }
    }
}
