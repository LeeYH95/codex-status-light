# Codex Traffic Glass

A macOS floating widget for Codex status and quota visibility.

## Run

```sh
swift run CodexTrafficGlass
```

## Verify

```sh
swift run CodexTrafficGlassSelfTests
swift build
```

## MVP Scope

- Desktop floating widget, not a menu bar app.
- Left side: compact red/yellow/green status light.
- Right side: expandable frosted glass panel.
- Data source: local Codex session JSONL files under `~/.codex/sessions`.
- Quota source: `event_msg.payload.rate_limits` from Codex session logs.
