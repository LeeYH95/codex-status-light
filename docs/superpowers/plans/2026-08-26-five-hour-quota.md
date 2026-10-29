# 5 小时额度合并卡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变展开 HUD 面板尺寸的前提下，在左侧额度卡中同时显示 5 小时与 1 周额度。

**Architecture:** 保持既有 `CodexQuota` 数据与刷新管线不变，只在 SwiftUI 展示层把单周额度卡替换为合并额度卡。新增的额度行间距与进度条高度进入 `CodexPanelVisualMetrics`，让 96pt 的底部卡片行能明确容纳一个标题和两条额度行；右侧周重置卡及 hover 行为不变。

**Tech Stack:** Swift 6、SwiftUI、Foundation、Swift Package Manager 自测可执行程序。

---

### Task 1: 锁定合并额度卡的布局 token

**Files:**
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift:542-555`
- Modify: `Sources/CodexTrafficGlassCore/CodexPanelVisualMetrics.swift:3-23`

- [ ] **Step 1: 写入会失败的布局 token 自测**

在现有 `quotaCardVerticalInset` 断言之后插入：

```swift
try expect(
    CodexPanelVisualMetrics.quotaWindowSpacing == 4,
    "two quota windows should use a compact, tokenized vertical gap"
)
try expect(
    CodexPanelVisualMetrics.quotaWindowProgressHeight == 5,
    "two quota windows should use a compact, tokenized progress height"
)
```

- [ ] **Step 2: 运行自测确认失败**

运行：`swift run --disable-sandbox CodexTrafficGlassSelfTests`

预期：构建失败，指出 `CodexPanelVisualMetrics` 没有 `quotaWindowSpacing` 与 `quotaWindowProgressHeight` 成员。

- [ ] **Step 3: 以最小实现定义 token**

在 `quotaCardVerticalInset` 后添加：

```swift
public static let quotaWindowSpacing = 4.0
public static let quotaWindowProgressHeight = 5.0
```

- [ ] **Step 4: 重跑自测确认通过**

运行：`swift run --disable-sandbox CodexTrafficGlassSelfTests`

预期：输出 `All self-tests passed`。

### Task 2: 用两行合并额度卡替换单周额度卡

**Files:**
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift:941-1062`

- [ ] **Step 1: 将行容器改为中性额度容器**

把 `WeeklyQuotaCardsRow` 重命名为 `QuotaCardsRow`，并将调用点改为：

```swift
QuotaCardsRow(quota: snapshot.quota)
    .frame(height: CodexPanelVisualMetrics.quotaCardRowHeight)
```

容器左侧仍占可用宽度的 60%，右侧 `ResetTimingCard(resetAt: quota.weeklyResetAt)` 仍占 40%。

- [ ] **Step 2: 用 `CombinedQuotaCard` 替换 `WeeklyQuotaCard`**

在左侧放置：

```swift
CombinedQuotaCard(quota: quota)
    .frame(width: availableWidth * 0.60)
```

新增 `CombinedQuotaCard`，使用现有 14pt 卡片背景，并在 96pt 固定高度内按此顺序排版：

```swift
VStack(alignment: .leading, spacing: CodexPanelVisualMetrics.quotaWindowSpacing) {
    Text("额度")
    QuotaWindowRow(
        label: "5 小时",
        remainingPercent: quota.fiveHourRemainingPercent,
        resetAt: quota.fiveHourResetAt,
        resetDateFormat: "H:mm"
    )
    QuotaWindowRow(
        label: "1 周",
        remainingPercent: quota.weeklyRemainingPercent,
        resetAt: quota.weeklyResetAt,
        resetDateFormat: "M月d日"
    )
}
```

标题使用现有卡片标签样式（11pt bold，`.white.opacity(0.58)`）；保留现有水平/垂直内边距与玻璃背景。

- [ ] **Step 3: 新增可复用的 `QuotaWindowRow`**

新增接收 `label`、`remainingPercent`、`resetAt`、`resetDateFormat` 的私有 View。顶部 HStack 从左至右放置标签、`remainingPercent.map { "\\(Int($0.rounded()))%" } ?? "--"`、格式化后的重置时间。其进度条必须：

```swift
.frame(height: CodexPanelVisualMetrics.quotaWindowProgressHeight)
```

并按现有 `WeeklyQuotaPresentation.remainingBand(for:)` 使用绿、黄、红或未知的灰色。时间格式化逻辑为：

```swift
guard let resetAt else { return "" }
let formatter = DateFormatter()
formatter.dateFormat = resetDateFormat
return formatter.string(from: resetAt)
```

- [ ] **Step 4: 删除不再使用的 `WeeklyQuotaCard`**

删除被 `CombinedQuotaCard` 和 `QuotaWindowRow` 完全替代的 `WeeklyQuotaCard`，不修改 `ResetTimingCard`、`CurrentStatusCard`、面板尺寸或 hover 状态。

- [ ] **Step 5: 编译应用**

运行：`swift build --disable-sandbox`

预期：输出 `Build complete!`，没有 SwiftUI 类型或布局编译错误。

### Task 3: 完整验证与提交

**Files:**
- Modify: `Sources/CodexTrafficGlassCore/CodexPanelVisualMetrics.swift`
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift`

- [ ] **Step 1: 运行完整自动验证**

依次运行：

```sh
swift run --disable-sandbox CodexTrafficGlassSelfTests
swift build --disable-sandbox
git diff --check
```

预期：自测输出 `All self-tests passed`，构建输出 `Build complete!`，`git diff --check` 无输出。

- [ ] **Step 2: 检查变更边界**

运行：`git diff --check && git status --short`

预期：仅包含本任务的视图、视觉 token、自测与该计划文件；不包含 `dist/Codex Quota.app`、`VERSION`、`CHANGELOG.md` 或主目录中用户的未提交文档。

- [ ] **Step 3: 提交功能分支**

运行：

```sh
git add Sources/CodexTrafficGlassCore/CodexPanelVisualMetrics.swift \
  Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift \
  Tests/CodexTrafficGlassSelfTests/main.swift \
  docs/superpowers/plans/2026-08-26-five-hour-quota.md
git commit -m "feat: show five-hour quota"
```

预期：功能提交只存在于 `codex/five-hour-quota`；未经用户随后明确要求，不合并到 `main` 或重新生成 `dist/Codex Quota.app`。
