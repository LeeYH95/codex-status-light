# 5 小时悬浮额度球 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让折叠态悬浮额度球只显示 5 小时剩余额度，不再错误代表周额度。

**Architecture:** 在 Core 中增加一个窄小的展示选择器，显式返回 `fiveHourRemainingPercent`，以便自测覆盖“不回退至周额度”的规则。SwiftUI 小球从该选择器读取进度、颜色、文字和辅助功能值；数据解析、展开面板及窗口尺寸不变。

**Tech Stack:** Swift 6、SwiftUI、Foundation、Swift Package Manager 自测可执行程序。

---

### Task 1: 锁定小球的 5 小时展示规则

**Files:**
- Create: `Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift:278-290`

- [ ] **Step 1: 写入会失败的选择器自测**

在 `currentQuota` 定义后加入：

```swift
try expect(
    CollapsedQuotaReservoirPresentation.remainingPercent(for: currentQuota) == 64,
    "collapsed quota reservoir should use the 5-hour remaining percent"
)
try expect(
    CollapsedQuotaReservoirPresentation.remainingPercent(
        for: CodexQuota(weeklyRemainingPercent: 20)
    ) == nil,
    "collapsed quota reservoir should not fall back to weekly quota"
)
```

- [ ] **Step 2: 运行自测确认失败**

运行：`swift run --disable-sandbox CodexTrafficGlassSelfTests`

预期：构建失败，指出 `CollapsedQuotaReservoirPresentation` 未定义。

- [ ] **Step 3: 以最小实现新增展示选择器**

创建 `Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift`：

```swift
import Foundation

public enum CollapsedQuotaReservoirPresentation {
    public static func remainingPercent(for quota: CodexQuota) -> Double? {
        quota.fiveHourRemainingPercent
    }
}
```

- [ ] **Step 4: 重跑自测确认通过**

运行：`swift run --disable-sandbox CodexTrafficGlassSelfTests`

预期：输出 `All self-tests passed`。

### Task 2: 将折叠态小球绑定到展示选择器

**Files:**
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift:44,131-239`

- [ ] **Step 1: 重命名小球 View**

将 `CollapsedWeeklyQuotaReservoir` 改为 `CollapsedFiveHourQuotaReservoir`，并将调用点改为：

```swift
CollapsedFiveHourQuotaReservoir(quota: store.snapshot.quota)
```

- [ ] **Step 2: 统一读取 5 小时展示值**

在 View 中新增：

```swift
private var remainingPercent: Double? {
    CollapsedQuotaReservoirPresentation.remainingPercent(for: quota)
}
```

把进度、风险色、中央文字与辅助功能值中的所有 `quota.weeklyRemainingPercent` 替换为 `remainingPercent`。保留现有 `WeeklyQuotaPresentation` 的进度归一化与颜色阈值逻辑。

- [ ] **Step 3: 修正辅助功能语义**

将 `.accessibilityLabel("周额度剩余")` 替换为 `.accessibilityLabel("5小时额度剩余")`。

- [ ] **Step 4: 编译应用**

运行：`swift build --disable-sandbox`

预期：输出 `Build complete!`。

### Task 3: 最终验证与提交

**Files:**
- Create: `Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift`
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift`
- Create: `docs/superpowers/plans/2026-08-26-five-hour-reservoir.md`

- [ ] **Step 1: 运行完整自动验证**

依次运行：

```sh
swift run --disable-sandbox CodexTrafficGlassSelfTests
swift build --disable-sandbox
git diff --check
```

预期：自测输出 `All self-tests passed`，构建输出 `Build complete!`，差异检查无输出。

- [ ] **Step 2: 检查变更边界**

运行：`git status --short`

预期：只包含本功能的 Core 选择器、SwiftUI 绑定、自测与计划文件；不包含 `dist/Codex Quota.app`、`VERSION`、`CHANGELOG.md` 或主目录中用户已有的文档变更。

- [ ] **Step 3: 提交功能分支**

运行：

```sh
git add Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift
git add Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift
git add Tests/CodexTrafficGlassSelfTests/main.swift
git add docs/superpowers/plans/2026-08-26-five-hour-reservoir.md
git commit -m "fix: show five-hour quota in reservoir"
```

预期：功能提交只在 `codex/five-hour-reservoir` 上；除非用户再次明确要求，不能合并到 `main` 或重新生成正式 app。
