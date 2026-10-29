import Foundation

public struct StatusReducer: Sendable {
    private let processingAfter: TimeInterval
    private let stallAfter: TimeInterval

    public init(processingAfter: TimeInterval = 300, stallAfter: TimeInterval = 900) {
        self.processingAfter = processingAfter
        self.stallAfter = stallAfter
    }

    public func reduce(current: CodexStatusSnapshot, event: CodexParsedEvent, now: Date = Date()) -> CodexStatusSnapshot {
        var snapshot = current
        switch event {
        case .quota, .quotaSnapshot:
            snapshot.quota = QuotaReducer().reduce(current: snapshot.quota, event: event)
            return refresh(current: snapshot, now: now)
        case .tokenCount:
            return refresh(current: snapshot, now: now)
        case .taskStarted,
             .reasoning,
             .functionCall,
             .functionOutput,
             .finalAnswer,
             .taskComplete,
             .taskAborted,
             .userInputNeeded:
            snapshot.updatedAt = event.occurredAt
        }

        switch event {
        case .taskStarted:
            snapshot.state = .thinking
            snapshot.title = "Codex 正在思考"
            snapshot.detail = "已收到新任务"
            snapshot.confidence = 0.85
        case .reasoning:
            snapshot.state = .thinking
            snapshot.title = "Codex 正在思考"
            snapshot.detail = "正在分析上下文"
            snapshot.confidence = 0.8
        case let .functionCall(name, _):
            snapshot.state = .running
            snapshot.title = "Codex 正在执行"
            snapshot.detail = toolDetail(for: name)
            snapshot.confidence = 0.9
        case let .functionOutput(text, exitCode, _):
            if let exitCode, exitCode != 0 {
                snapshot.state = .failed
                snapshot.title = "工具执行失败"
                snapshot.detail = text
                snapshot.confidence = 0.95
            } else {
                snapshot.state = .running
                snapshot.title = "Codex 正在执行"
                snapshot.detail = text.isEmpty ? "已收到执行结果" : "正在整理执行结果"
                snapshot.confidence = 0.75
            }
        case .finalAnswer:
            snapshot.state = .done
            snapshot.title = "任务已完成"
            snapshot.detail = "已生成最终回复"
            snapshot.confidence = 0.9
        case let .taskComplete(success, _):
            snapshot.state = success ? .done : .failed
            snapshot.title = success ? "任务已完成" : "任务失败"
            snapshot.detail = success ? "Codex 已完成任务" : "任务以错误结束"
            snapshot.confidence = 0.95
        case .taskAborted:
            snapshot.state = .idle
            snapshot.title = "空闲"
            snapshot.detail = "任务已取消"
            snapshot.confidence = 0.8
        case .tokenCount, .quota, .quotaSnapshot:
            break
        case .userInputNeeded:
            snapshot.state = .waiting
            snapshot.title = "需要人工确认"
            snapshot.detail = "等待用户操作"
            snapshot.confidence = 0.9
        }

        return refresh(current: snapshot, now: now)
    }

    public func refresh(current: CodexStatusSnapshot, now: Date = Date()) -> CodexStatusSnapshot {
        guard
            [.thinking, .running, .processing].contains(current.state),
            let updatedAt = current.updatedAt
        else {
            return current
        }

        let elapsed = now.timeIntervalSince(updatedAt)
        if elapsed <= processingAfter {
            return current
        }

        if elapsed <= stallAfter {
            return CodexStatusSnapshot(
                state: .processing,
                title: "处理中",
                detail: processingDetail(since: updatedAt, now: now),
                confidence: 0.7,
                updatedAt: current.updatedAt,
                quota: current.quota
            )
        }

        return CodexStatusSnapshot(
            state: .stalled,
            title: "需要检查",
            detail: stalledDetail(since: updatedAt, now: now),
            confidence: 0.65,
            updatedAt: current.updatedAt,
            quota: current.quota
        )
    }

    private func processingDetail(since updatedAt: Date, now: Date) -> String {
        guard updatedAt.timeIntervalSince1970 > 1 else {
            return "有对话较久未更新，可能仍在执行"
        }

        let elapsedMinutes = max(1, Int(now.timeIntervalSince(updatedAt)) / 60)
        return "已 \(elapsedMinutes) 分钟没有新动态，可能仍在执行"
    }

    private func stalledDetail(since updatedAt: Date, now: Date) -> String {
        guard updatedAt.timeIntervalSince1970 > 1 else {
            return "暂未收到新的 Codex 动态"
        }

        let elapsedSeconds = max(0, Int(now.timeIntervalSince(updatedAt)))
        if elapsedSeconds < 60 {
            return "刚刚还没有新动态"
        }

        let elapsedMinutes = max(1, elapsedSeconds / 60)
        if elapsedMinutes < 60 {
            return "已 \(elapsedMinutes) 分钟没有新动态"
        }

        let elapsedHours = elapsedMinutes / 60
        if elapsedHours < 24 {
            return "已 \(elapsedHours) 小时没有新动态"
        }

        return "已超过 1 天没有新动态"
    }

    private func toolDetail(for name: String) -> String {
        switch name {
        case "exec_command":
            return "正在运行命令"
        case "write_stdin":
            return "正在等待命令输出"
        case "apply_patch":
            return "正在修改文件"
        case "view_image":
            return "正在查看图片"
        case "tool_search_tool":
            return "正在查找工具"
        default:
            return "正在调用工具"
        }
    }
}
