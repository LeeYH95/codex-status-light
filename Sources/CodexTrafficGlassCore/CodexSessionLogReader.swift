import Foundation

public struct CodexSessionLogReader: Sendable {
    public let sessionsDirectory: URL

    public init(
        codexHome: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
    ) {
        self.sessionsDirectory = codexHome.appendingPathComponent("sessions")
    }

    public init(sessionsDirectory: URL) {
        self.sessionsDirectory = sessionsDirectory
    }

    public func latestSessionFile() -> URL? {
        latestSessionFiles(limit: 1).first
    }

    public func latestSessionFiles(limit: Int = 8) -> [URL] {
        guard limit > 0 else {
            return []
        }

        guard
            let enumerator = FileManager.default.enumerator(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var sessionFiles: [(url: URL, modifiedAt: Date)] = []

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard
                let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                let modifiedAt = resourceValues.contentModificationDate
            else {
                continue
            }

            sessionFiles.append((url, modifiedAt))
        }

        return sessionFiles
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.url.path > rhs.url.path
                }
                return lhs.modifiedAt > rhs.modifiedAt
            }
            .prefix(limit)
            .map(\.url)
    }

    public func readRecentEvents(
        limit: Int = 400,
        maxBytes: UInt64 = 128 * 1024,
        parser: CodexEventParser = CodexEventParser()
    ) -> [CodexParsedEvent] {
        guard let latestSessionFile = latestSessionFile() else {
            return []
        }

        return readRecentEvents(from: latestSessionFile, limit: limit, maxBytes: maxBytes, parser: parser)
    }

    public func readRecentSessionEvents(
        sessionLimit: Int = 8,
        eventLimit: Int = 400,
        maxBytesPerSession: UInt64 = 128 * 1024,
        parser: CodexEventParser = CodexEventParser()
    ) -> [[CodexParsedEvent]] {
        latestSessionFiles(limit: sessionLimit)
            .map { fileURL in
                readRecentEvents(from: fileURL, limit: eventLimit, maxBytes: maxBytesPerSession, parser: parser)
            }
    }

    public func readLatestQuotaEvent(
        maxBytes: UInt64 = 64 * 1024 * 1024,
        parser: CodexEventParser = CodexEventParser()
    ) -> CodexParsedEvent? {
        selectConservativeQuotaEvent(
            from: latestSessionFiles(limit: 12)
                .flatMap { readQuotaEvents(from: $0, maxBytes: maxBytes, parser: parser) }
        )
    }

    public func readLatestQuotaEvent(
        from fileURL: URL,
        maxBytes: UInt64 = 64 * 1024 * 1024,
        parser: CodexEventParser = CodexEventParser()
    ) -> CodexParsedEvent? {
        selectConservativeQuotaEvent(from: readQuotaEvents(from: fileURL, maxBytes: maxBytes, parser: parser))
    }

    public func readRecentEvents(
        from fileURL: URL,
        limit: Int = 400,
        maxBytes: UInt64 = 128 * 1024,
        parser: CodexEventParser = CodexEventParser()
    ) -> [CodexParsedEvent] {
        guard let text = readTailText(from: fileURL, maxBytes: maxBytes) else {
            return []
        }

        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(limit)
            .compactMap { parser.parse(String($0)) }
    }

    private func readTailText(from fileURL: URL, maxBytes: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }

        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let startOffset = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: startOffset)

        guard let data = try? handle.readToEnd(), !data.isEmpty else {
            return ""
        }

        var text = String(decoding: data, as: UTF8.self)
        if startOffset > 0, let firstNewline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNewline)...])
        }

        return text
    }

    private func readLatestEventContaining(
        _ needle: String,
        from fileURL: URL,
        maxBytes: UInt64,
        chunkBytes: UInt64 = 512 * 1024,
        overlapBytes: UInt64 = 64 * 1024,
        parser: CodexEventParser,
        matches: @escaping (CodexParsedEvent) -> Bool
    ) -> CodexParsedEvent? {
        guard maxBytes > 0, let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }

        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize > 0 else {
            return nil
        }

        var endOffset = fileSize
        var scannedBytes: UInt64 = 0

        while endOffset > 0 && scannedBytes < maxBytes {
            let remainingBudget = maxBytes - scannedBytes
            let bodyBytes = min(chunkBytes, endOffset, remainingBudget)
            guard bodyBytes > 0 else {
                break
            }

            let bodyStartOffset = endOffset - bodyBytes
            let startOffset = bodyStartOffset > overlapBytes ? bodyStartOffset - overlapBytes : 0
            let readLength = endOffset - startOffset

            guard
                let readCount = Int(exactly: readLength),
                (try? handle.seek(toOffset: startOffset)) != nil,
                let data = try? handle.read(upToCount: readCount),
                !data.isEmpty
            else {
                return nil
            }

            let text = String(decoding: data, as: UTF8.self)
            if let event = latestMatchingEvent(in: text, containing: needle, parser: parser, matches: matches) {
                return event
            }

            scannedBytes += bodyBytes
            guard bodyStartOffset > 0 else {
                break
            }
            endOffset = bodyStartOffset
        }

        return nil
    }

    private func latestMatchingEvent(
        in text: String,
        containing needle: String,
        parser: CodexEventParser,
        matches: (CodexParsedEvent) -> Bool
    ) -> CodexParsedEvent? {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .reversed()
            .lazy
            .filter { $0.contains(needle) }
            .compactMap { parser.parse(String($0)) }
            .first(where: matches)
    }

    private func readQuotaEvents(
        from fileURL: URL,
        maxBytes: UInt64,
        parser: CodexEventParser
    ) -> [CodexParsedEvent] {
        readEventsContaining(#""rate_limits""#, from: fileURL, maxBytes: maxBytes, parser: parser) { event in
            if case .quota = event {
                return true
            }
            return false
        }
    }

    private func readEventsContaining(
        _ needle: String,
        from fileURL: URL,
        maxBytes: UInt64,
        chunkBytes: UInt64 = 512 * 1024,
        overlapBytes: UInt64 = 64 * 1024,
        parser: CodexEventParser,
        matches: @escaping (CodexParsedEvent) -> Bool
    ) -> [CodexParsedEvent] {
        guard maxBytes > 0, let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return []
        }

        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize > 0 else {
            return []
        }

        var endOffset = fileSize
        var scannedBytes: UInt64 = 0
        var seenLines: Set<String> = []
        var events: [CodexParsedEvent] = []

        while endOffset > 0 && scannedBytes < maxBytes {
            let remainingBudget = maxBytes - scannedBytes
            let bodyBytes = min(chunkBytes, endOffset, remainingBudget)
            guard bodyBytes > 0 else {
                break
            }

            let bodyStartOffset = endOffset - bodyBytes
            let startOffset = bodyStartOffset > overlapBytes ? bodyStartOffset - overlapBytes : 0
            let readLength = endOffset - startOffset

            guard
                let readCount = Int(exactly: readLength),
                (try? handle.seek(toOffset: startOffset)) != nil,
                let data = try? handle.read(upToCount: readCount),
                !data.isEmpty
            else {
                return events
            }

            let text = String(decoding: data, as: UTF8.self)
            let chunkEvents = text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .lazy
                .filter { $0.contains(needle) }
                .compactMap { line -> CodexParsedEvent? in
                    let lineText = String(line)
                    guard seenLines.insert(lineText).inserted else {
                        return nil
                    }

                    guard let event = parser.parse(lineText), matches(event) else {
                        return nil
                    }

                    return event
                }
            events.append(contentsOf: chunkEvents)

            scannedBytes += bodyBytes
            guard bodyStartOffset > 0 else {
                break
            }
            endOffset = bodyStartOffset
        }

        return events
    }

    private func selectConservativeQuotaEvent(from events: [CodexParsedEvent]) -> CodexParsedEvent? {
        let quotas = events.compactMap(QuotaCandidate.init(event:))
        guard !quotas.isEmpty else {
            return nil
        }

        let fiveHour = selectQuotaValue(
            from: quotas.compactMap { candidate in
                candidate.fiveHourUsedPercent.map {
                    QuotaValue(usedPercent: $0, resetAt: candidate.fiveHourResetAt, occurredAt: candidate.occurredAt)
                }
            }
        )
        let weekly = selectQuotaValue(
            from: quotas.compactMap { candidate in
                candidate.weeklyUsedPercent.map {
                    QuotaValue(usedPercent: $0, resetAt: candidate.weeklyResetAt, occurredAt: candidate.occurredAt)
                }
            }
        )

        guard fiveHour != nil || weekly != nil else {
            return nil
        }

        let occurredAt = [fiveHour?.occurredAt, weekly?.occurredAt]
            .compactMap { $0 }
            .max() ?? quotas.map(\.occurredAt).max() ?? Date(timeIntervalSince1970: 0)

        return .quota(
            fiveHourUsedPercent: fiveHour?.usedPercent,
            weeklyUsedPercent: weekly?.usedPercent,
            fiveHourResetAt: fiveHour?.resetAt,
            weeklyResetAt: weekly?.resetAt,
            at: occurredAt
        )
    }

    private func selectQuotaValue(from values: [QuotaValue]) -> QuotaValue? {
        guard !values.isEmpty else {
            return nil
        }

        let latestOccurredAt = values.map(\.occurredAt).max() ?? Date(timeIntervalSince1970: 0)
        let recentCutoff = latestOccurredAt.addingTimeInterval(-15 * 60)
        let recentValues = values.filter { $0.occurredAt >= recentCutoff }
        let latestResetAt = recentValues.compactMap(\.resetAt).max()
        let resetWindowValues: [QuotaValue]
        if let latestResetAt {
            resetWindowValues = recentValues.filter { value in
                guard let resetAt = value.resetAt else {
                    return false
                }

                return abs(resetAt.timeIntervalSince(latestResetAt)) <= 120
            }
        } else {
            resetWindowValues = recentValues
        }

        return (resetWindowValues.isEmpty ? recentValues : resetWindowValues)
            .max { lhs, rhs in
                if lhs.usedPercent != rhs.usedPercent {
                    return lhs.usedPercent < rhs.usedPercent
                }

                return lhs.occurredAt < rhs.occurredAt
            }
    }

    private struct QuotaCandidate {
        let fiveHourUsedPercent: Double?
        let weeklyUsedPercent: Double?
        let fiveHourResetAt: Date?
        let weeklyResetAt: Date?
        let occurredAt: Date

        init?(event: CodexParsedEvent) {
            guard case let .quota(fiveHourUsedPercent, weeklyUsedPercent, fiveHourResetAt, weeklyResetAt, occurredAt) = event else {
                return nil
            }

            self.fiveHourUsedPercent = fiveHourUsedPercent
            self.weeklyUsedPercent = weeklyUsedPercent
            self.fiveHourResetAt = fiveHourResetAt
            self.weeklyResetAt = weeklyResetAt
            self.occurredAt = occurredAt
        }
    }

    private struct QuotaValue {
        let usedPercent: Double
        let resetAt: Date?
        let occurredAt: Date
    }
}
