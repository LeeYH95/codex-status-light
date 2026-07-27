import Foundation
import CodexTrafficGlassCore

private struct SelfTestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SelfTestFailure(description: message)
    }
}

private func runSelfTests() throws {
    let parser = CodexEventParser()
    let timestamp = ISO8601DateFormatter().date(from: "2026-05-30T12:00:00Z")!
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let fractionalTimestamp = fractionalFormatter.date(from: "2026-05-30T12:00:00.123Z")!

    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"function_call","name":"exec_command"}"#)
            == .functionCall(name: "exec_command", at: timestamp),
        "JSON function_call should parse"
    )

    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"function_call","name":"exec_command"}}"#)
            == .functionCall(name: "exec_command", at: timestamp),
        "Nested response_item function_call should parse"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00.123Z","type":"response_item","payload":{"type":"function_call","name":"exec_command"}}"#)
            == .functionCall(name: "exec_command", at: fractionalTimestamp),
        "response_item should parse fractional second timestamps"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"event_msg","payload":{"type":"user_message","message":"你好"}}"#)
            == .taskStarted(timestamp),
        "event_msg user_message should start an active task"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"你好"}]}}"#)
            == .taskStarted(timestamp),
        "response_item user message should not parse as final answer"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"message","role":"assistant","phase":"commentary","content":[{"type":"output_text","text":"我会先看日志"}]}}"#)
            == .reasoning(timestamp),
        "response_item commentary assistant message should not parse as final answer"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"message","role":"assistant","phase":"final_answer","content":[{"type":"output_text","text":"完成"}]}}"#)
            == .finalAnswer(timestamp),
        "response_item final assistant message should parse as final answer"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"event_msg","payload":{"type":"task_complete","completed_at":1780157908}}"#)
            == .taskComplete(success: true, at: Date(timeIntervalSince1970: 1780157908)),
        "event_msg task_complete should prefer completed_at when available"
    )
    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"完成"}}"#)
            == .finalAnswer(timestamp),
        "event_msg final agent message should parse as final answer"
    )

    let outputEvent = parser.parse(#"{"timestamp":"2026-05-30T12:01:00Z","type":"function_output","output":"Process exited with code 2"}"#)
    guard case let .functionOutput(_, exitCode, _) = outputEvent else {
        throw SelfTestFailure(description: "function_output should parse")
    }
    try expect(exitCode == 2, "function_output should extract non-zero exit code")

    try expect(
        parser.parse("Task started") == .taskStarted(Date(timeIntervalSince1970: 0)),
        "text lifecycle start should parse"
    )
    try expect(
        parser.parse("final answer generated") == .finalAnswer(Date(timeIntervalSince1970: 0)),
        "text final answer should parse"
    )

    let quotaEvent = CodexParsedEvent.quota(
        fiveHourUsedPercent: 17,
        weeklyUsedPercent: 42,
        fiveHourResetAt: nil,
        weeklyResetAt: nil,
        at: Date(timeIntervalSince1970: 10)
    )
    let quota = QuotaReducer().reduce(current: CodexQuota(), event: quotaEvent)
    try expect(quota.fiveHourRemainingPercent == 83, "5-hour quota remaining should be 83")
    try expect(quota.weeklyRemainingPercent == 58, "weekly quota remaining should be 58")

    let staleLogQuota = CodexQuota(
        weeklyRemainingPercent: 99,
        weeklyResetAt: Date(timeIntervalSince1970: 1_784_764_800),
        bankedResetAvailableCount: 0
    )
    let liveAccountQuota = CodexQuota(
        weeklyRemainingPercent: 70,
        weeklyResetAt: Date(timeIntervalSince1970: 1_785_283_200),
        bankedResetAvailableCount: 3,
        bankedResets: [CodexBankedReset(expiresAt: Date(timeIntervalSince1970: 1_785_542_400))]
    )
    let resolvedQuota = CodexQuotaSourceMerger.resolving(
        logQuota: staleLogQuota,
        liveQuota: liveAccountQuota
    )
    try expect(
        resolvedQuota.weeklyRemainingPercent == 70,
        "live app-server weekly quota should win over stale session-log quota"
    )
    try expect(
        resolvedQuota.weeklyResetAt == Date(timeIntervalSince1970: 1_785_283_200),
        "live app-server reset time should win over stale session-log reset time"
    )
    try expect(
        resolvedQuota.bankedResetAvailableCount == 3,
        "live app-server reset credits should win over stale session-log quota"
    )

    let bankedResetQuota = CodexQuota(
        bankedResets: [
            CodexBankedReset(expiresAt: Date(timeIntervalSince1970: 1_782_900_000)),
            CodexBankedReset(expiresAt: Date(timeIntervalSince1970: 1_782_500_000))
        ]
    )
    try expect(
        BankedResetPresentation.summaryLabel(for: bankedResetQuota) == "重置次数 2 次",
        "banked reset entry should show total reset count"
    )
    try expect(
        BankedResetPresentation.sortedResets(for: bankedResetQuota).map(\.expiresAt)
            == [
                Date(timeIntervalSince1970: 1_782_500_000),
                Date(timeIntervalSince1970: 1_782_900_000)
            ],
        "banked reset details should be sorted by earliest expiration first"
    )
    try expect(
        BankedResetPresentation.earliestExpirationLabel(
            for: bankedResetQuota,
            now: Date(timeIntervalSince1970: 1_782_068_800)
        ) == "最早 5 天后过期",
        "banked reset details should call out the earliest expiration"
    )
    try expect(
        BankedResetPresentation.summaryLabel(for: CodexQuota()) == "重置次数 0 次",
        "empty banked reset entry should make the zero state explicit"
    )

    try expect(
        WeeklyQuotaPresentation.remainingBand(for: 60) == .ample,
        "60 percent remaining should use the ample quota band"
    )
    try expect(
        WeeklyQuotaPresentation.remainingBand(for: 59.9) == .caution,
        "remaining quota below 60 percent should use the caution band"
    )
    try expect(
        WeeklyQuotaPresentation.remainingBand(for: 25) == .caution,
        "25 percent remaining should remain in the caution band"
    )
    try expect(
        WeeklyQuotaPresentation.remainingBand(for: 24.9) == .critical,
        "remaining quota below 25 percent should use the critical band"
    )

    let weeklyResetAt = Date(timeIntervalSince1970: 604_800)
    let cycleMidpoint = Date(timeIntervalSince1970: 302_400)
    try expect(
        WeeklyQuotaPresentation.cycleElapsedProgress(resetAt: weeklyResetAt, now: cycleMidpoint) == 0.5,
        "reset timeline should show elapsed weekly-cycle time"
    )
    try expect(
        WeeklyQuotaPresentation.resetCountdownLabel(resetAt: weeklyResetAt, now: cycleMidpoint) == "3天12小时",
        "reset countdown should show remaining whole days and hours"
    )
    try expect(
        WeeklyQuotaPresentation.resetCountdownLabel(
            resetAt: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 11)
        ) == "等待额度刷新",
        "expired reset data should wait for a quota refresh instead of looking imminent"
    )
    try expect(
        WeeklyQuotaPresentation.nextHourlyRefresh(after: Date(timeIntervalSince1970: 45_296))
            == Date(timeIntervalSince1970: 46_800),
        "reset timeline should refresh at the next wall-clock hour"
    )

    let appServerRateLimitJSON = Data(#"{"id":2,"result":{"rateLimitResetCredits":{"availableCount":3,"credits":[{"id":"RateLimitResetCredit_1","resetType":"codexRateLimits","status":"available","grantedAt":1782519396,"expiresAt":1785111396,"title":"Full reset","description":"Thanks for using Codex! You've been granted one free rate limit reset."},{"id":"RateLimitResetCredit_2","resetType":"codexRateLimits","status":"available","grantedAt":1782933283,"expiresAt":1785525283,"title":"Full reset","description":"Thanks for using Codex! You've been granted one free rate limit reset."},{"id":"RateLimitResetCredit_3","resetType":"codexRateLimits","status":"available","grantedAt":1783966227,"expiresAt":1786558227,"title":"Full reset","description":"Thanks for using Codex! You've been granted one free rate limit reset."}]},"rateLimits":{"limitId":"codex","primary":{"usedPercent":32,"windowDurationMins":10080,"resetsAt":1785287297},"secondary":null}}}"#.utf8)
    let appServerQuota = try CodexAppServerRateLimitsParser().parseQuota(from: appServerRateLimitJSON)
    try expect(
        appServerQuota.bankedResetAvailableCount == 3,
        "app-server rate limit response should parse available reset count"
    )
    try expect(
        appServerQuota.bankedResets.map(\.expiresAt) == [
            Date(timeIntervalSince1970: 1_785_111_396),
            Date(timeIntervalSince1970: 1_785_525_283),
            Date(timeIntervalSince1970: 1_786_558_227)
        ],
        "app-server rate limit response should parse reset credit expiration times"
    )
    try expect(
        BankedResetPresentation.summaryLabel(for: appServerQuota) == "重置次数 3 次",
        "banked reset summary should prefer app-server available count"
    )

    let appServerCountOnlyJSON = Data(#"{"id":2,"result":{"rateLimitResetCredits":{"availableCount":3,"credits":null}}}"#.utf8)
    let countOnlyQuota = try CodexAppServerRateLimitsParser().parseQuota(from: appServerCountOnlyJSON)
    try expect(
        countOnlyQuota.bankedResetAvailableCount == 3 && countOnlyQuota.bankedResets.isEmpty,
        "app-server rate limit response should keep count when detail rows are unavailable"
    )

    let currentQuota = CodexQuota(fiveHourRemainingPercent: 64, weeklyRemainingPercent: 20)
    let unchangedQuota = QuotaReducer().reduce(
        current: currentQuota,
        event: .quota(fiveHourUsedPercent: nil, weeklyUsedPercent: nil, fiveHourResetAt: nil, weeklyResetAt: nil, at: Date())
    )
    try expect(unchangedQuota == currentQuota, "missing quota values should preserve current values")

    let nestedQuotaEvent = parser.parse(#"{"timestamp":"2026-05-30T12:02:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":79.0,"resets_at":1780157908},"secondary":{"used_percent":59.0,"resets_at":1780233520}}}}"#)
    guard case let .quota(fiveHourUsed, weeklyUsed, fiveHourResetAt, weeklyResetAt, _) = nestedQuotaEvent else {
        throw SelfTestFailure(description: "nested rate_limits should parse")
    }
    try expect(fiveHourUsed == 79, "nested primary used percent should parse")
    try expect(weeklyUsed == 59, "nested secondary used percent should parse")
    try expect(fiveHourResetAt == Date(timeIntervalSince1970: 1780157908), "primary reset epoch should parse")
    try expect(weeklyResetAt == Date(timeIntervalSince1970: 1780233520), "secondary reset epoch should parse")

    try expect(
        parser.parse(#"{"timestamp":"2026-05-30T12:03:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"premium","primary":null,"secondary":null,"credits":{"has_credits":false}}}}"#) == nil,
        "premium credit records without codex windows should not parse as quota"
    )

    let statusReducer = StatusReducer(stallAfter: 300)
    let running = statusReducer.reduce(
        current: .empty,
        event: .functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 10)),
        now: Date(timeIntervalSince1970: 10)
    )
    try expect(running.state == .running, "function call should set running")
    try expect(running.title == "Codex 正在执行", "function call title should describe tool execution")
    try expect(running.detail == "正在运行命令", "function call detail should be user friendly")
    try expect(running.confidence == 0.9, "function call confidence should be high")

    let started = statusReducer.reduce(
        current: .empty,
        event: .taskStarted(Date(timeIntervalSince1970: 10)),
        now: Date(timeIntervalSince1970: 10)
    )
    try expect(started.state == .thinking, "user message should set thinking")
    try expect(started.title == "Codex 正在思考", "task start title should be thinking")
    try expect(started.detail == "已收到新任务", "task start detail should be user friendly")

    let failed = statusReducer.reduce(
        current: .empty,
        event: .functionOutput(text: "Process exited with code 2", exitCode: 2, at: Date(timeIntervalSince1970: 20)),
        now: Date(timeIntervalSince1970: 20)
    )
    try expect(failed.state == .failed, "non-zero exit should set failed")
    try expect(failed.title == "工具执行失败", "non-zero exit title should describe failure")

    let stale = statusReducer.refresh(
        current: CodexStatusSnapshot(
            state: .running,
            title: "Codex 正在执行",
            detail: "exec_command",
            confidence: 0.9,
            updatedAt: Date(timeIntervalSince1970: 0)
        ),
        now: Date(timeIntervalSince1970: 500)
    )
    try expect(stale.state == .stalled, "stale active state should set stalled")
    try expect(stale.title == "需要检查", "stalled title should be actionable")
    try expect(stale.detail == "暂未收到新的 Codex 动态", "epoch fallback should use friendly stalled detail")

    let staleRecent = statusReducer.refresh(
        current: CodexStatusSnapshot(
            state: .running,
            title: "Codex 正在执行",
            detail: "exec_command",
            confidence: 0.9,
            updatedAt: Date(timeIntervalSince1970: 200)
        ),
        now: Date(timeIntervalSince1970: 700)
    )
    try expect(staleRecent.detail == "已 8 分钟没有新动态", "stalled detail should use readable minutes")

    let globalAggregator = GlobalStatusAggregator(
        statusReducer: StatusReducer(processingAfter: 300, stallAfter: 900),
        now: Date(timeIntervalSince1970: 1_000)
    )
    let globalRunning = globalAggregator.reduce(
        current: .empty,
        sessionEvents: [
            [.functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 900))],
            [.finalAnswer(Date(timeIntervalSince1970: 950))]
        ]
    )
    try expect(globalRunning.state == .running, "global status should stay running while any session is active")
    try expect(globalRunning.title == "Codex 正在执行", "global running title should describe active work")

    let globalProcessing = globalAggregator.reduce(
        current: .empty,
        sessionEvents: [
            [.functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 500))],
            [.finalAnswer(Date(timeIntervalSince1970: 950))]
        ]
    )
    try expect(globalProcessing.state == .processing, "global status should show processing for quiet active sessions")
    try expect(globalProcessing.title == "处理中", "quiet active sessions should use processing title")

    let globalWaiting = globalAggregator.reduce(
        current: .empty,
        sessionEvents: [
            [.functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 980))],
            [.userInputNeeded(Date(timeIntervalSince1970: 970))]
        ]
    )
    try expect(globalWaiting.state == .waiting, "global status should prioritize user confirmation")
    try expect(globalWaiting.detail == "有 Codex 对话正在等待你处理", "waiting detail should be global and actionable")

    let globalStalled = GlobalStatusAggregator(
        statusReducer: StatusReducer(processingAfter: 300, stallAfter: 900),
        now: Date(timeIntervalSince1970: 2_000)
    ).reduce(
        current: .empty,
        sessionEvents: [
            [.functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 1_000))],
            [.finalAnswer(Date(timeIntervalSince1970: 1_950))]
        ]
    )
    try expect(globalStalled.state == .stalled, "global status should prioritize long-stalled active sessions")
    try expect(globalStalled.title == "需要检查", "global stalled title should be user friendly")

    let abortedTurnStartedLine = #"{"timestamp":"2026-06-30T09:47:27.861Z","type":"event_msg","payload":{"type":"task_started","started_at":1782812847.861,"turn_id":"turn-1"}}"#
    let abortedTurnEndedLine = #"{"timestamp":"2026-06-30T09:48:21.443Z","type":"event_msg","payload":{"type":"turn_aborted","completed_at":1782812901.443,"reason":"user_cancelled","turn_id":"turn-1"}}"#
    let abortedTurnEvents = [abortedTurnStartedLine, abortedTurnEndedLine].compactMap { parser.parse($0) }
    let globalAbortedTurn = GlobalStatusAggregator(
        statusReducer: StatusReducer(processingAfter: 300, stallAfter: 900),
        now: Date(timeIntervalSince1970: 1782814000),
        monitoringHorizon: 6 * 60 * 60
    ).reduce(
        current: .empty,
        sessionEvents: [abortedTurnEvents]
    )
    try expect(globalAbortedTurn.state == .idle, "aborted turns should not become stalled")
    try expect(globalAbortedTurn.title == "空闲", "aborted turns should leave the global lamp idle")

    let quotaShouldNotRefreshStatusTime = statusReducer.reduce(
        current: CodexStatusSnapshot(
            state: .stalled,
            title: "需要检查",
            detail: "已 20 分钟没有新动态",
            confidence: 0.65,
            updatedAt: Date(timeIntervalSince1970: 100)
        ),
        event: .quota(
            fiveHourUsedPercent: 20,
            weeklyUsedPercent: 10,
            fiveHourResetAt: nil,
            weeklyResetAt: nil,
            at: Date(timeIntervalSince1970: 1_000)
        ),
        now: Date(timeIntervalSince1970: 1_000)
    )
    try expect(
        quotaShouldNotRefreshStatusTime.updatedAt == Date(timeIntervalSince1970: 100),
        "quota updates should not make stale status look fresh"
    )
    try expect(
        quotaShouldNotRefreshStatusTime.quota.fiveHourRemainingPercent == 80,
        "quota updates should still refresh quota values"
    )

    let oldAbandonedSession = GlobalStatusAggregator(
        statusReducer: StatusReducer(processingAfter: 300, stallAfter: 900),
        now: Date(timeIntervalSince1970: 30_000),
        monitoringHorizon: 6 * 60 * 60
    ).reduce(
        current: .empty,
        sessionEvents: [
            [.functionCall(name: "exec_command", at: Date(timeIntervalSince1970: 1_000))]
        ]
    )
    try expect(oldAbandonedSession.state == .idle, "global status should ignore abandoned sessions outside the monitoring horizon")
    try expect(oldAbandonedSession.title == "空闲", "old abandoned sessions should not keep the lamp red")

    try expect(
        StatusPresentation.presentation(for: .running).activeLamp == .red,
        "running should light red"
    )
    try expect(
        !StatusPresentation.presentation(for: .running).isBlinking,
        "running should use steady red"
    )
    try expect(
        StatusPresentation.presentation(for: .failed).activeLamp == .red,
        "failed should light red"
    )
    try expect(
        StatusPresentation.presentation(for: .failed).isBlinking,
        "failed should blink red"
    )
    try expect(
        StatusPresentation.presentation(for: .stalled).isBlinking,
        "stalled should blink red"
    )
    try expect(
        StatusPresentation.presentation(for: .done).activeLamp == .green,
        "done should light green"
    )
    try expect(
        StatusPresentation.presentation(for: .processing).activeLamp == .red,
        "processing should light red"
    )
    try expect(
        StatusPresentation.presentation(for: .thinking).activeLamp == .yellow,
        "thinking should keep yellow"
    )
    try expect(
        StatusPresentation.freshnessLabel(updatedAt: nil, now: Date(timeIntervalSince1970: 100)) == "监听中",
        "missing status timestamp should show monitoring"
    )
    try expect(
        StatusPresentation.freshnessLabel(
            updatedAt: Date(timeIntervalSince1970: 95),
            now: Date(timeIntervalSince1970: 100)
        ) == "刚刚",
        "fresh status timestamp should show just now"
    )
    try expect(
        StatusPresentation.freshnessLabel(
            updatedAt: Date(timeIntervalSince1970: 100),
            now: Date(timeIntervalSince1970: 280)
        ) == "3分钟前",
        "minute-old status timestamp should show minutes"
    )
    try expect(
        StatusPresentation.freshnessLabel(
            updatedAt: Date(timeIntervalSince1970: 100),
            now: Date(timeIntervalSince1970: 7_400)
        ) == "2小时前",
        "hour-old status timestamp should show hours"
    )
    try expect(CodexPanelMotion.duration == 0.24, "panel motion should stay smooth but quick")
    try expect(CodexPanelMotion.revealOffsetX == -14, "panel should reveal with a subtle leading offset")
    try expect(CodexPanelMotion.collapsedScale == 0.985, "panel scale should be subtle")
    try expect(CodexPanelMotion.hoverCollapseDelay == 0.12, "hover collapse should wait briefly to prevent pointer handoff flicker")
    try expect(CodexPanelMotion.expandedWidth == 500, "expanded window should fit the full panel")
    try expect(CodexPanelMotion.collapsedWidth == 126, "collapsed window should only cover the lamp and expand handle")
    try expect(CodexPanelMotion.panelBottomBreathingRoom == 12, "panel should reserve 12 points below quota cards")
    try expect(CodexPanelMotion.windowHeight == 276, "window height should include panel bottom breathing room")
    try expect(CodexPanelVisualMetrics.statusCardCornerRadius == 16, "status card should use a tighter 16 point corner radius")
    try expect(CodexPanelVisualMetrics.quotaCardCornerRadius == 14, "quota cards should use a tighter 14 point corner radius")
    try expect(CodexPanelVisualMetrics.resetCountCornerRadius == 12, "reset count entry should no longer be a full capsule")
    try expect(CodexPanelVisualMetrics.resetDetailsCornerRadius == 16, "reset details popover should use a tighter corner radius")
    try expect(
        WeeklyQuotaPresentation.normalizedRemainingProgress(for: 12) == 0.12,
        "weekly quota gauge should convert 12 percent remaining to 0.12 progress"
    )
    try expect(
        WeeklyQuotaPresentation.normalizedRemainingProgress(for: 120) == 1,
        "weekly quota gauge progress should clamp values above 100 percent"
    )
    try expect(CodexPanelVisualMetrics.quotaGaugeDiameter == 63, "quota gauge should use the approved 63 point diameter")
    try expect(CodexPanelVisualMetrics.quotaGaugeSpacing == 14, "quota gauge should keep 14 points away from the traffic light")
    try expect(CodexPanelMotion.collapsedWindowHeight == 318, "collapsed window should fit the detached quota gauge")
    try expect(CodexPanelVisualMetrics.quotaReservoirSize == 46, "quota reservoir should use the approved 46 point size")
    try expect(CodexPanelVisualMetrics.quotaReservoirCornerRadius == 16, "quota reservoir should use the approved 16 point corner radius")
    try expect(
        CodexPanelVisualMetrics.trafficLightWithReservoirHeight == 280,
        "traffic light and reservoir stack should reserve a fixed 280 point height"
    )
    try expect(
        CodexPanelMotion.quotaReservoirWindowHeight == CodexPanelMotion.collapsedWindowHeight,
        "expanded and collapsed states should use the same reservoir window height"
    )

    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexTrafficGlassSelfTests-\(UUID().uuidString)")
    let olderDirectory = tempDirectory.appendingPathComponent("2026/05/29")
    let newerDirectory = tempDirectory.appendingPathComponent("2026/05/30")
    try FileManager.default.createDirectory(at: olderDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newerDirectory, withIntermediateDirectories: true)

    let olderFile = olderDirectory.appendingPathComponent("rollout-old.jsonl")
    let newerFile = newerDirectory.appendingPathComponent("rollout-new.jsonl")
    try #"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"reasoning"}}"#
        .write(to: olderFile, atomically: true, encoding: .utf8)
    Thread.sleep(forTimeInterval: 0.02)
    try #"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"function_call","name":"exec_command"}}"#
        .write(to: newerFile, atomically: true, encoding: .utf8)

    let logReader = CodexSessionLogReader(sessionsDirectory: tempDirectory)
    try expect(
        logReader.latestSessionFile()?.standardizedFileURL == newerFile.standardizedFileURL,
        "latest session file should use modification date"
    )
    try expect(
        logReader.readRecentEvents(limit: 10) == [.functionCall(name: "exec_command", at: timestamp)],
        "log reader should parse latest session events"
    )

    let longFile = newerDirectory.appendingPathComponent("rollout-tail.jsonl")
    let filler = String(repeating: #"{"type":"unknown"}"# + "\n", count: 200)
    let tailLine = #"{"timestamp":"2026-05-30T12:00:00Z","type":"response_item","payload":{"type":"reasoning"}}"#
    try (filler + tailLine + "\n").write(to: longFile, atomically: true, encoding: .utf8)
    let tailEvents = logReader.readRecentEvents(from: longFile, limit: 10, maxBytes: 512)
    try expect(tailEvents == [.reasoning(timestamp)], "log reader should parse recent events from file tail")

    let quotaTailFile = newerDirectory.appendingPathComponent("rollout-quota-tail.jsonl")
    let oldQuotaLine = #"{"timestamp":"2026-05-30T12:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":79.0,"resets_at":1780214926},"secondary":{"used_percent":74.0,"resets_at":1780233520}}}}"#
    let newQuotaLine = #"{"timestamp":"2026-05-30T12:05:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":90.0,"resets_at":1780214926},"secondary":{"used_percent":76.0,"resets_at":1780233520}}}}"#
    let largeMessageLine = #"{"timestamp":"2026-05-30T12:04:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":""# + String(repeating: "x", count: 160_000) + #""}]}}"#
    try ([oldQuotaLine, largeMessageLine, newQuotaLine].joined(separator: "\n") + "\n")
        .write(to: quotaTailFile, atomically: true, encoding: .utf8)
    try expect(
        logReader.readLatestQuotaEvent(from: quotaTailFile, maxBytes: 256 * 1024)
            == .quota(
                fiveHourUsedPercent: 90,
                weeklyUsedPercent: 76,
                fiveHourResetAt: Date(timeIntervalSince1970: 1780214926),
                weeklyResetAt: Date(timeIntervalSince1970: 1780233520),
                at: ISO8601DateFormatter().date(from: "2026-05-30T12:05:00Z")!
            ),
        "latest quota reader should prefer the newest rate limit line"
    )

    let trailingNoiseQuotaFile = newerDirectory.appendingPathComponent("rollout-quota-before-large-tail.jsonl")
    let resetQuotaLine = #"{"timestamp":"2026-05-30T12:10:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":1.0,"resets_at":1780244671},"secondary":{"used_percent":78.0,"resets_at":1780233520}}}}"#
    let trailingLargeMessageLine = #"{"timestamp":"2026-05-30T12:11:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":""# + String(repeating: "y", count: 1_500_000) + #""}]}}"#
    try ([oldQuotaLine, resetQuotaLine, trailingLargeMessageLine].joined(separator: "\n") + "\n")
        .write(to: trailingNoiseQuotaFile, atomically: true, encoding: .utf8)
    try expect(
        logReader.readLatestQuotaEvent(from: trailingNoiseQuotaFile)
            == .quota(
                fiveHourUsedPercent: 1,
                weeklyUsedPercent: 78,
                fiveHourResetAt: Date(timeIntervalSince1970: 1780244671),
                weeklyResetAt: Date(timeIntervalSince1970: 1780233520),
                at: ISO8601DateFormatter().date(from: "2026-05-30T12:10:00Z")!
            ),
        "latest quota reader should scan past large trailing non-quota messages"
    )

    let premiumAfterQuotaFile = newerDirectory.appendingPathComponent("rollout-premium-after-quota.jsonl")
    let premiumQuotaLine = #"{"timestamp":"2026-05-30T12:11:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"premium","primary":null,"secondary":null,"credits":{"has_credits":false}}}}"#
    try ([resetQuotaLine, premiumQuotaLine].joined(separator: "\n") + "\n")
        .write(to: premiumAfterQuotaFile, atomically: true, encoding: .utf8)
    try expect(
        logReader.readLatestQuotaEvent(from: premiumAfterQuotaFile)
            == .quota(
                fiveHourUsedPercent: 1,
                weeklyUsedPercent: 78,
                fiveHourResetAt: Date(timeIntervalSince1970: 1780244671),
                weeklyResetAt: Date(timeIntervalSince1970: 1780233520),
                at: ISO8601DateFormatter().date(from: "2026-05-30T12:10:00Z")!
        ),
        "latest quota reader should skip premium credit records and keep scanning for codex quota"
    )

    let staleLowerQuotaFile = newerDirectory.appendingPathComponent("rollout-stale-lower-quota.jsonl")
    let accurateQuotaLine = #"{"timestamp":"2026-05-30T12:12:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":38.0,"resets_at":1780641165},"secondary":{"used_percent":10.0,"resets_at":1781143281}}}}"#
    let staleLowerQuotaLine = #"{"timestamp":"2026-05-30T12:13:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":16.0,"resets_at":1780641165},"secondary":{"used_percent":7.0,"resets_at":1781143281}}}}"#
    try ([accurateQuotaLine, staleLowerQuotaLine].joined(separator: "\n") + "\n")
        .write(to: staleLowerQuotaFile, atomically: true, encoding: .utf8)
    try expect(
        logReader.readLatestQuotaEvent(from: staleLowerQuotaFile)
            == .quota(
                fiveHourUsedPercent: 38,
                weeklyUsedPercent: 10,
                fiveHourResetAt: Date(timeIntervalSince1970: 1780641165),
                weeklyResetAt: Date(timeIntervalSince1970: 1781143281),
                at: ISO8601DateFormatter().date(from: "2026-05-30T12:12:00Z")!
            ),
        "latest quota reader should not let a later stale lower snapshot reduce used quota"
    )

    let latestQuotaDirectory = tempDirectory.appendingPathComponent("2026/05/31")
    try FileManager.default.createDirectory(at: latestQuotaDirectory, withIntermediateDirectories: true)
    let olderQuotaFile = newerDirectory.appendingPathComponent("rollout-older-quota.jsonl")
    let newerQuotaFile = latestQuotaDirectory.appendingPathComponent("rollout-newer-quota.jsonl")
    let olderCodexQuotaLine = #"{"timestamp":"2026-05-30T12:20:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":60.0,"resets_at":1780641165},"secondary":{"used_percent":70.0,"resets_at":1781143281}}}}"#
    let newerCodexQuotaLine = #"{"timestamp":"2026-05-30T12:25:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":30.0,"resets_at":1780641165},"secondary":{"used_percent":80.0,"resets_at":1781143281}}}}"#
    try (olderCodexQuotaLine + "\n").write(to: olderQuotaFile, atomically: true, encoding: .utf8)
    Thread.sleep(forTimeInterval: 0.02)
    try (newerCodexQuotaLine + "\n").write(to: newerQuotaFile, atomically: true, encoding: .utf8)
    try expect(
        logReader.readLatestQuotaEvent()
            == .quota(
                fiveHourUsedPercent: 60,
                weeklyUsedPercent: 80,
                fiveHourResetAt: Date(timeIntervalSince1970: 1780641165),
                weeklyResetAt: Date(timeIntervalSince1970: 1781143281),
                at: ISO8601DateFormatter().date(from: "2026-05-30T12:25:00Z")!
            ),
        "latest quota reader should conservatively merge current-window quota across recent session files"
    )
    try? FileManager.default.removeItem(at: tempDirectory)
}

do {
    try runSelfTests()
    print("All self-tests passed")
} catch {
    fputs("Self-test failed: \(error)\n", stderr)
    exit(1)
}
