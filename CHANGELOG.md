# Changelog

所有正式版本的用户可感知变更记录在此。发布 `vX.Y.Z` 前，必须先新增对应的版本段落。

## [Unreleased]

## [1.0.1]

### 调整（Changed）

- 当前额度优先通过 Codex app-server 读取；近期 session 日志尾部仅在 app-server 暂不可用时作为兜底。
- 空闲时账户额度校准改为每 60 秒一次。
- 新增版本文件与可重复的本地打包脚本。

### 修复（Fixed）

- 不再在常驻状态刷新中反复扫描历史 session 日志。
- 修正 README 中无法运行的启动命令。
