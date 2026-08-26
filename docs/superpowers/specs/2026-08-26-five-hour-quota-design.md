# 5 小时额度合并卡设计

## 目标

在 Codex Quota 的展开面板中恢复 5 小时额度，同时保持当前 390pt 宽、241pt 高的紧凑玻璃 HUD，不新增面板层级、按钮或手动收起交互。

## 已选视觉方向

采用用户选定的设计稿 1：底部左侧 60% 宽的现有周额度卡改为单张“额度”合并卡；右侧 40% 宽的“下次重置”卡保持周额度语义与现有内容不变。

合并卡按以下顺序展示两行：

1. `5 小时`：剩余百分比、当天重置时间（`H:mm`）和细进度条。
2. `1 周`：剩余百分比、重置日期（`M月d日`）和细进度条。

每个窗口独立根据其剩余额度使用当前绿/黄/红/未知颜色规则；缺失额度显示 `--`，缺失重置时间显示为空，不以猜测数据代替。

## 布局与视觉约束

- 外层面板尺寸、header、状态卡、模块间距、右侧重置卡与 hover 行为不变。
- 合并卡继续使用现有深色玻璃卡片材质、14pt 圆角与 8pt 内容外 inset。
- 卡内新增的行高与行间距成为 `CodexPanelVisualMetrics` token；不能在 View 中加入无来源的尺寸常量。
- 两个窗口平等可扫读：标签在左，数值与重置时间在右，进度条位于各自行底部。
- 5 小时的 `H:mm` 仅表示其 `fiveHourResetAt` 的本地时间；1 周延续 `M月d日` 日期格式。

## 代码边界

- `CodexQuota` 已有 `fiveHourRemainingPercent`、`fiveHourResetAt`、`weeklyRemainingPercent` 与 `weeklyResetAt`，不改解析、合并或刷新数据管线。
- 视图层将 `WeeklyQuotaCardsRow` 重命名为中性的额度行容器，并以一个可复用的紧凑额度行渲染 5 小时与 1 周数据。
- 现有周额度风险色逻辑继续用于两个窗口；不引入新的状态阈值或动画时序。

## 验证

- 自测覆盖新增布局 token，确保 96pt 的现有底部卡片行高仍为合并卡保留明确空间。
- 运行 `swift run --disable-sandbox CodexTrafficGlassSelfTests`、`swift build --disable-sandbox` 与 `git diff --check`。
- 按用户已授予的小改动例外，跳过测试 app；正式 app 仅在实现合并至 `main` 后、用户再次明确要求生成时更新。
