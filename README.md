# Codex Traffic Glass

A macOS floating widget for Codex status and quota visibility.

## Run

```sh
swift run --disable-sandbox Codexquota
```

## Verify

```sh
swift run --disable-sandbox CodexTrafficGlassSelfTests
swift build --disable-sandbox
```

## Package a release

`VERSION` is the single source of truth for the app and release version. Set it to
the next `X.Y.Z` version, then run:

```sh
./scripts/package-release.sh
```

The script builds the app, synchronizes `CFBundleShortVersionString` and
`CFBundleVersion`, signs the app locally, and creates:

```text
dist/releases/Codex-Quota-vX.Y.Z.zip
```

For a formal release, push the matching Git tag `vX.Y.Z`; the release workflow
rebuilds the archive and uploads it automatically.

## Automation

GitHub Actions validates every pull request and every push to `main`: self-tests,
Swift build, version consistency, app signing, and zip integrity.

After a release PR is merged, push the matching `vX.Y.Z` tag. The release workflow
validates the tag against `VERSION`, builds the app again, creates the GitHub Release,
and uploads the zip. The release notes come from the matching section in `CHANGELOG.md`.

## MVP Scope

- Desktop floating widget, not a menu bar app.
- Left side: compact red/yellow/green status light.
- Right side: expandable frosted glass panel.
- Data source: local Codex session JSONL files under `~/.codex/sessions`.
- Quota source: the current Codex app-server response, with recent session-log tails as a fallback.

## License

This project is licensed under the [MIT License](LICENSE).
