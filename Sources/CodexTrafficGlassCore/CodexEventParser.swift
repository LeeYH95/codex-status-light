import Foundation

public struct CodexEventParser: Sendable {
    public init() {}

    public func parse(_ line: String) -> CodexParsedEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let jsonEvent = parseJSON(trimmed) {
            return jsonEvent
        }

        return parseText(trimmed)
    }

    private func parseJSON(_ line: String) -> CodexParsedEvent? {
        guard
            let data = line.data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let at = date(from: payload["timestamp"]) ?? Date(timeIntervalSince1970: 0)
        let type = string(payload["type"])?.lowercased()

        if type == "response_item", let nestedPayload = dictionary(payload["payload"]) {
            return parseResponseItem(nestedPayload, at: at)
        }

        if type == "event_msg", let nestedPayload = dictionary(payload["payload"]) {
            return parseEventMessage(nestedPayload, at: at)
        }

        switch type {
        case "task_started", "task_start", "session_started":
            return .taskStarted(at)
        case "reasoning", "thinking":
            return .reasoning(at)
        case "function_call", "tool_call":
            return .functionCall(name: string(payload["name"]) ?? "tool", at: at)
        case "function_output", "tool_output":
            let output = string(payload["output"]) ?? string(payload["text"]) ?? ""
            return .functionOutput(text: output, exitCode: exitCode(in: output), at: at)
        case "final_answer", "assistant_final":
            return .finalAnswer(at)
        case "task_complete", "session_complete":
            return .taskComplete(success: bool(payload["success"]) ?? true, at: at)
        case "token_count", "tokens":
            return .tokenCount(input: int(payload["input"]), output: int(payload["output"]), at: at)
        case "quota", "rate_limit", "usage":
            return .quota(
                fiveHourUsedPercent: double(payload["five_hour_used_percent"]),
                weeklyUsedPercent: double(payload["weekly_used_percent"]),
                fiveHourResetAt: date(from: payload["five_hour_reset_at"]),
                weeklyResetAt: date(from: payload["weekly_reset_at"]),
                at: at
            )
        case "user_input_needed", "approval_requested":
            return .userInputNeeded(at)
        default:
            return nil
        }
    }

    private func parseResponseItem(_ payload: [String: Any], at: Date) -> CodexParsedEvent? {
        let type = string(payload["type"])?.lowercased()

        switch type {
        case "reasoning":
            return .reasoning(at)
        case "function_call", "custom_tool_call", "tool_call":
            return .functionCall(name: string(payload["name"]) ?? "tool", at: at)
        case "function_call_output", "custom_tool_call_output", "tool_output":
            let output = string(payload["output"]) ?? string(payload["text"]) ?? ""
            return .functionOutput(text: output, exitCode: exitCode(in: output), at: at)
        case "message":
            let role = string(payload["role"])?.lowercased()
            let phase = string(payload["phase"])?.lowercased()

            if role == "user" {
                return .taskStarted(at)
            }

            if phase == "final_answer" {
                return .finalAnswer(at)
            }

            return .reasoning(at)
        case "final_answer", "assistant_final":
            return .finalAnswer(at)
        default:
            return nil
        }
    }

    private func parseEventMessage(_ payload: [String: Any], at: Date) -> CodexParsedEvent? {
        if let rateLimits = dictionary(payload["rate_limits"]) {
            if let limitID = string(rateLimits["limit_id"])?.lowercased(), limitID != "codex" {
                return nil
            }

            let primary = dictionary(rateLimits["primary"])
            let secondary = dictionary(rateLimits["secondary"])
            guard primary != nil || secondary != nil else {
                return nil
            }

            return .quota(
                fiveHourUsedPercent: double(primary?["used_percent"]),
                weeklyUsedPercent: double(secondary?["used_percent"]),
                fiveHourResetAt: epochDate(from: primary?["resets_at"]),
                weeklyResetAt: epochDate(from: secondary?["resets_at"]),
                at: at
            )
        }

        let type = string(payload["type"])?.lowercased()
        let occurredAt = epochDate(from: payload["started_at"])
            ?? epochDate(from: payload["completed_at"])
            ?? at

        switch type {
        case "user_message", "task_started", "task_start", "session_started":
            return .taskStarted(occurredAt)
        case "reasoning", "thinking":
            return .reasoning(occurredAt)
        case "agent_message":
            if string(payload["phase"])?.lowercased() == "final_answer" {
                return .finalAnswer(occurredAt)
            }
            return .reasoning(occurredAt)
        case "task_complete", "session_complete":
            return .taskComplete(success: bool(payload["success"]) ?? true, at: occurredAt)
        case "approval_requested", "user_input_needed":
            return .userInputNeeded(occurredAt)
        default:
            break
        }

        if type == "token_count", let info = dictionary(payload["info"]) {
            let usage = dictionary(info["last_token_usage"])
            return .tokenCount(
                input: int(usage?["input_tokens"]),
                output: int(usage?["output_tokens"]),
                at: at
            )
        }

        return nil
    }

    private func parseText(_ line: String) -> CodexParsedEvent? {
        let lowercased = line.lowercased()

        if lowercased.contains("task started") || lowercased.contains("session started") {
            return .taskStarted(Date(timeIntervalSince1970: 0))
        }

        if lowercased.contains("final answer") || lowercased.contains("task complete") {
            return .finalAnswer(Date(timeIntervalSince1970: 0))
        }

        if lowercased.contains("approval") || lowercased.contains("waiting for user") {
            return .userInputNeeded(Date(timeIntervalSince1970: 0))
        }

        if let exitCode = exitCode(in: line) {
            return .functionOutput(text: line, exitCode: exitCode, at: Date(timeIntervalSince1970: 0))
        }

        return nil
    }

    private func exitCode(in text: String) -> Int? {
        let pattern = #"(?i)(exit(?:ed)?(?: with)? code|exit status)\s+(-?\d+)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges >= 3,
            let range = Range(match.range(at: 2), in: text)
        else {
            return nil
        }

        return Int(text[range])
    }

    private func date(from value: Any?) -> Date? {
        guard let text = string(value) else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: text) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private func string(_ value: Any?) -> String? {
        value as? String
    }

    private func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private func int(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? Double {
            return Int(value)
        }

        if let value = value as? String {
            return Int(value)
        }

        return nil
    }

    private func double(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? String {
            return Double(value)
        }

        return nil
    }

    private func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }

        if let value = value as? String {
            return Bool(value)
        }

        return nil
    }

    private func epochDate(from value: Any?) -> Date? {
        guard let timestamp = double(value) else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

}
