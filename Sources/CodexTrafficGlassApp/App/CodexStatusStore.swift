import Foundation
import SwiftUI
import CodexTrafficGlassCore

@MainActor
final class CodexStatusStore: ObservableObject {
    @Published var snapshot: CodexStatusSnapshot
    @Published var isExpanded: Bool

    private let statusReducer: StatusReducer
    private let logReader: CodexSessionLogReader
    private let appServerRateLimitsReader: CodexAppServerRateLimitsReader
    private var pollingTask: Task<Void, Never>?
    private var quotaReconciliationTask: Task<Void, Never>?
    private var logChangeWatcher: CodexLogChangeWatcher?
    private var isRefreshing = false
    private var isRefreshingAccountRateLimits = false
    private var liveAccountQuota: CodexQuota?

    init(
        snapshot: CodexStatusSnapshot = CodexStatusSnapshot(
            state: .unknown,
            title: "Codex",
            detail: "正在读取本地活动",
            confidence: 0.3,
            updatedAt: nil
        ),
        isExpanded: Bool = false,
        statusReducer: StatusReducer = StatusReducer(),
        logReader: CodexSessionLogReader = CodexSessionLogReader(),
        appServerRateLimitsReader: CodexAppServerRateLimitsReader = CodexAppServerRateLimitsReader()
    ) {
        self.snapshot = snapshot
        self.isExpanded = isExpanded
        self.statusReducer = statusReducer
        self.logReader = logReader
        self.appServerRateLimitsReader = appServerRateLimitsReader
    }

    func start() {
        guard pollingTask == nil else {
            return
        }

        let watcher = CodexLogChangeWatcher(logReader: logReader) { [weak self] in
            Task { @MainActor in
                await self?.refreshFromLogs()
                await self?.refreshAccountRateLimits()
            }
        }
        logChangeWatcher = watcher
        watcher.start()

        pollingTask = Task { [weak self] in
            await self?.refreshFromLogs()
            await self?.refreshAccountRateLimits()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.refreshFromLogs()
            }
        }

        quotaReconciliationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await self?.refreshAccountRateLimits()
            }
        }
    }

    func apply(event: CodexParsedEvent) {
        snapshot = applyingLiveQuotaPriority(
            to: statusReducer.reduce(current: snapshot, event: event)
        )
    }

    func refreshFromLogs() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        var nextSnapshot = snapshot
        let reader = logReader
        let refreshResult = await Task.detached(priority: .utility) {
            (
                sessionEvents: reader.readRecentSessionEvents(),
                latestQuotaEvent: reader.readLatestQuotaEvent(),
                hasSessionFile: reader.latestSessionFile() != nil
            )
        }.value
        let sessionEvents = refreshResult.sessionEvents
        let events = sessionEvents.flatMap { $0 }

        if events.isEmpty {
            let quota = refreshResult.latestQuotaEvent.map {
                QuotaReducer().reduce(current: snapshot.quota, event: $0)
            } ?? snapshot.quota

            snapshot = applyingLiveQuotaPriority(to: CodexStatusSnapshot(
                state: refreshResult.hasSessionFile ? .idle : .unknown,
                title: refreshResult.hasSessionFile ? "空闲" : "未连接",
                detail: refreshResult.hasSessionFile ? "暂无正在进行的 Codex 任务" : "打开 Codex 后开始追踪",
                confidence: refreshResult.hasSessionFile ? 0.55 : 0.2,
                updatedAt: nil,
                quota: quota
            ))
            return
        }

        nextSnapshot = GlobalStatusAggregator(statusReducer: statusReducer)
            .reduce(current: nextSnapshot, sessionEvents: sessionEvents)

        if let latestQuotaEvent = refreshResult.latestQuotaEvent {
            nextSnapshot = statusReducer.reduce(current: nextSnapshot, event: latestQuotaEvent)
        }

        snapshot = applyingLiveQuotaPriority(
            to: statusReducer.refresh(current: nextSnapshot)
        )
        logChangeWatcher?.refreshWatchedFiles()
    }

    func refreshQuotaFromLogs() async {
        let reader = logReader
        let latestQuotaEvent = await Task.detached(priority: .utility) {
            reader.readLatestQuotaEvent()
        }.value

        guard let latestQuotaEvent else {
            return
        }

        snapshot = applyingLiveQuotaPriority(
            to: statusReducer.reduce(current: snapshot, event: latestQuotaEvent)
        )
    }

    func refreshAccountRateLimits() async {
        guard !isRefreshingAccountRateLimits else {
            return
        }

        isRefreshingAccountRateLimits = true
        defer {
            isRefreshingAccountRateLimits = false
        }

        let reader = appServerRateLimitsReader
        let accountQuota = await Task.detached(priority: .utility) {
            reader.readQuota()
        }.value
        guard let accountQuota else {
            return
        }

        liveAccountQuota = CodexQuotaSourceMerger.resolving(
            logQuota: liveAccountQuota ?? CodexQuota(),
            liveQuota: accountQuota
        )
        snapshot = applyingLiveQuotaPriority(to: snapshot)
    }

    private func applyingLiveQuotaPriority(to snapshot: CodexStatusSnapshot) -> CodexStatusSnapshot {
        CodexStatusSnapshot(
            state: snapshot.state,
            title: snapshot.title,
            detail: snapshot.detail,
            confidence: snapshot.confidence,
            updatedAt: snapshot.updatedAt,
            quota: CodexQuotaSourceMerger.resolving(
                logQuota: snapshot.quota,
                liveQuota: liveAccountQuota
            )
        )
    }

    deinit {
        pollingTask?.cancel()
        quotaReconciliationTask?.cancel()
        logChangeWatcher?.stop()
    }
}
