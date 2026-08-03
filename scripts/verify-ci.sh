#!/bin/zsh

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_root/VERSION")"
info_plist="$project_root/dist/Codex Quota.app/Contents/Info.plist"
release_directory="${RELEASE_DIRECTORY:-$(mktemp -d /private/tmp/codex-quota-ci-release.XXXXXX)}"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "VERSION 必须是 X.Y.Z 格式，当前值：$version"
    exit 1
fi

cd "$project_root"
swift run --disable-sandbox CodexTrafficGlassSelfTests
swift build --disable-sandbox

if [[ "$(plutil -extract CFBundleShortVersionString raw "$info_plist")" != "$version" ]]; then
    print -u2 "CFBundleShortVersionString 必须与 VERSION 一致"
    exit 1
fi

if [[ "$(plutil -extract CFBundleVersion raw "$info_plist")" != "$version" ]]; then
    print -u2 "CFBundleVersion 必须与 VERSION 一致"
    exit 1
fi

RELEASE_DIRECTORY="$release_directory" ./scripts/package-release.sh
release_archive="$release_directory/Codex-Quota-v$version.zip"
unzip -t "$release_archive"
git diff --check
