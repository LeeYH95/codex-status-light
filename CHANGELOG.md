# Changelog

所有正式版本的用户可感知变更记录在此。发布 `vX.Y.Z` 前，必须先新增对应的版本段落。

## [Unreleased]

## [1.0.5]

### 修复（Fixed）

- 当账户没有 5 小时额度时，展开面板不再显示 5 小时额度行；左下悬浮球自动显示周额度。
- 账户有 5 小时额度时，继续优先显示 5 小时额度，不影响原有双额度展示。

### 验证（Verification）

- CodexTrafficGlassSelfTests 通过。
- Swift 构建通过。

## [1.0.4]

### 修复（Fixed）

- 折叠态的小悬浮额度球现在显示 5 小时额度，不再误显示每周额度。

### 验证（Verification）

- CodexTrafficGlassSelfTests 通过。
- Swift 构建通过。

## [1.0.3]

### 调整（Changed）

- 展开面板的额度卡现在同时显示 5 小时和 1 周剩余额度、各自的重置时间与进度条。

### 验证（Verification）

- CodexTrafficGlassSelfTests 通过。
- Swift 构建通过。

## [1.0.2]

### 修复（Fixed）

- 额度日志中的 Unix 秒数格式重置时间现在可正确解析，不会丢失 5 小时或每周重置时间。
- 当可用重置次数为 0 时，展开面板不再显示“重置次数 0 次”入口。

### 验证（Verification）

- 新增额度日志数值时间戳、任务取消/失败状态和重置倒计时边界的自测样本。

## [1.0.1]

### 调整（Changed）

- 当前额度优先通过 Codex app-server 读取；近期 session 日志尾部仅在 app-server 暂不可用时作为兜底。
- 空闲时账户额度校准改为每 60 秒一次。
- 新增版本文件与可重复的本地打包脚本。

### 修复（Fixed）

- 不再在常驻状态刷新中反复扫描历史 session 日志。
- 修正 README 中无法运行的启动命令。
