# GitHub 介绍文案与后续发行草稿

## About 建议

macOS desktop traffic light and quota panel for Codex, built with SwiftUI.

## Topics 建议

`codex`、`macos`、`swiftui`、`developer-tools`

## v1.0.9 发布说明草稿

本段是根据仓库已提交的 CHANGELOG 整理的草稿，不表示 v1.0.9 已在 GitHub Release 发布。

- 通过红绿灯查看 Codex 近期状态，并在悬浮面板中查看返回的额度与重置时间。
- 支持账户仅返回周额度的情况，额度球自动回退显示周额度。
- 修复新版 Codex 命令行路径变化后重置卡数量无法读取的问题。
- 支持通过红绿灯区域或额度球拖动悬浮组件。

数据来自本地会话日志和 Codex app-server，状态为推断结果；额度窗口与重置卡取决于账户返回的数据。

## 视频制作

`docs/media/intro.mp4` 为无音轨、22 秒的静态画面讲解。五张画面由 `make-media.swift` 使用 `docs/media/demo.png` 合成；该截图由项目 UI 代码及虚构数据生成，不包含账户实际额度。若重建，请在新的输出目录放入 `demo.png` 后运行 Swift 生成器，再依据 `storyboard.md` 使用 FFmpeg 合成视频，避免覆盖既有产物。
