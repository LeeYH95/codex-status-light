# Codex Traffic Glass MVP Requirements

## Goal

Build a macOS desktop floating widget that makes Codex's current work state and remaining usage immediately visible without external hardware.

The MVP focuses on two outcomes:

1. Accurately infer Codex state from local Codex activity logs.
2. Display current Codex remaining quota for the 5-hour and weekly windows.

## Product Shape

The widget is a small always-on-top desktop panel:

- Left: vertical red/yellow/green status light.
- Right: expandable/collapsible frosted glass panel.
- Expanded panel shows current status, latest activity detail, a plain Chinese status badge, 5-hour quota, weekly quota, and reset time when available.
- Collapsed mode keeps only the signal light plus a small expand affordance.

## State Logic

The app reads the latest modified Codex session file from:

```text
~/.codex/sessions/**/*.jsonl
```

It parses recent JSONL events from multiple recent session files. Each session is reduced independently, then the app displays the highest-priority global state. Only sessions with activity in the last 6 hours participate, so abandoned historical sessions do not keep the lamp red forever.

- Failure or stalled work -> red, "需要检查 / 有 Codex 对话长时间没有新动态"
- `approval_requested` / `user_input_needed` -> yellow, "需要确认 / 有 Codex 对话正在等待你处理"
- `function_call` / `custom_tool_call` -> yellow, "Codex 正在执行 / 有 Codex 对话正在运行工具或命令"
- `user_message` / `task_started` / `reasoning` -> yellow, "Codex 正在思考 / 有 Codex 对话正在分析任务"
- active sessions without new events for 5-15 minutes -> yellow, "处理中 / 有对话较久未更新，可能仍在执行"
- `agent_message` with `final_answer` / `task_complete` and no higher-priority active session -> green, "任务已完成 / 最近的 Codex 任务已完成"
- readable logs but no active task -> green, "空闲 / 暂无正在进行的 Codex 任务"
- no readable Codex activity -> Off / Unknown -> no active lamp, "未连接 / 打开 Codex 后开始追踪"

The traffic light is global, not scoped to the currently visible Codex conversation. If any recent Codex conversation is still active, waiting, stalled, or failed, that state wins over a newer completed conversation.
Active sessions with no new events for 0-5 minutes keep their current active state; 5-15 minutes becomes yellow "处理中"; more than 15 minutes becomes red "需要检查".

## Quota Logic

Quota is parsed from Codex `event_msg` records:

```text
payload.rate_limits.primary.used_percent
payload.rate_limits.secondary.used_percent
```

The widget displays remaining quota:

- 5h remaining = `100 - primary.used_percent`
- 1w remaining = `100 - secondary.used_percent`
- reset time = `primary.resets_at` / `secondary.resets_at`
- The app reads the latest quota separately from status events by scanning backward through recent session logs for the newest valid `codex` `rate_limits` record, so large trailing messages, empty `premium` credit records, or a single stale session file do not keep older quota values on screen.
- Within the current reset window, quota selection is conservative: if a later log line contains a lower `used_percent` snapshot than an earlier line in the same window, the app keeps the higher `used_percent` to avoid overstating remaining usage.
- Local synchronization is near-real-time: the app refreshes immediately when watched Codex session files change, with a low-frequency polling fallback. A separate quota reconciliation task rereads the latest valid quota every 60 seconds. It cannot show usage that Codex has not yet written to local logs.
- The current-status card must not show a percentage unless it is quota. Internal recognition confidence is kept out of the MVP UI to avoid confusing it with remaining usage.

## Plan

1. Build Swift package with a reusable core module.
2. Add parser and reducer self-tests for status, quota, and latest-session selection.
3. Build SwiftUI/AppKit floating desktop window.
4. Add traffic-light presentation and expandable frosted glass panel.
5. Watch local Codex JSONL log changes, aggregate recent session states globally, keep a low-frequency polling fallback, and reconcile quota once per minute.
6. Verify with self-tests and full app build.

## Current MVP Limitations

- It watches and periodically rereads local session logs instead of subscribing to a native Codex event API.
- It reads recent lines from the latest JSONL file on each refresh; this is acceptable for MVP but can be optimized with incremental tail offsets.
- It is desktop-floating only; menu bar mode is intentionally out of scope.
- Cursor integration and hardware lighting are intentionally out of scope.
