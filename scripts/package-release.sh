#!/bin/zsh

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
version_file="$project_root/VERSION"
app_path="$project_root/dist/Codex Quota.app"
binary_path="$project_root/.build/debug/Codexquota"
info_plist="$app_path/Contents/Info.plist"
release_directory="$project_root/dist/releases"

version="$(tr -d '[:space:]' < "$version_file")"
if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "VERSION 必须是 X.Y.Z 格式，当前值：$version"
    exit 1
fi

release_archive="$release_directory/Codex-Quota-v$version.zip"
if [[ -e "$release_archive" ]]; then
    print -u2 "发布资产已存在，拒绝覆盖：$release_archive"
    exit 1
fi

cd "$project_root"
swift build --disable-sandbox

cp "$binary_path" "$app_path/Contents/MacOS/Codexquota"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$info_plist"
codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict "$app_path"

mkdir -p "$release_directory"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$release_archive"

print "已生成 v$version 发布资产：$release_archive"
