# 缺失 5 小时额度展示回退 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在没有 5 小时额度的账户中隐藏展开面板的 5 小时行，并让左下悬浮球展示周额度。

**Architecture:** 额度采集模型保持不变。核心展示辅助函数决定悬浮球取值；SwiftUI 卡片直接根据可选 5 小时比例决定是否渲染该行。

**Tech Stack:** Swift 6、SwiftUI、Swift Package Manager。

---

### Task 1: 为悬浮球回退规则建立回归测试

**Files:**

- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift:278-288`
- Modify: `Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift:3-6`

- [ ] **Step 1: 写入失败的周额度回退测试**

```swift
try expect(
    CollapsedQuotaReservoirPresentation.remainingPercent(
        for: CodexQuota(weeklyRemainingPercent: 20)
    ) == 20,
    "collapsed quota reservoir should fall back to weekly quota when 5-hour quota is unavailable"
)
```

- [ ] **Step 2: 运行自测并确认该测试失败**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: FAIL，失败信息包含 `collapsed quota reservoir should fall back to weekly quota`。

- [ ] **Step 3: 最小化实现展示回退**

```swift
public static func remainingPercent(for quota: CodexQuota) -> Double? {
    quota.fiveHourRemainingPercent ?? quota.weeklyRemainingPercent
}
```

- [ ] **Step 4: 再次运行自测并确认通过**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: `All self-tests passed`。

- [ ] **Step 5: 提交核心回退规则**

Run: `git add Sources/CodexTrafficGlassCore/CollapsedQuotaReservoirPresentation.swift Tests/CodexTrafficGlassSelfTests/main.swift && git commit -m "fix: fall back to weekly quota reservoir"`

### Task 2: 按 5 小时字段显示额度行

**Files:**

- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift:44,131,983-988`

- [ ] **Step 1: 将悬浮球视图名改为不预设数据窗口的名称**

```swift
CollapsedQuotaReservoir(quota: store.snapshot.quota)

private struct CollapsedQuotaReservoir: View {
```

- [ ] **Step 2: 仅在存在 5 小时剩余比例时渲染该额度行**

```swift
if quota.fiveHourRemainingPercent != nil {
    QuotaWindowRow(
        label: "5 小时",
        remainingPercent: quota.fiveHourRemainingPercent,
        resetAt: quota.fiveHourResetAt,
        resetDateFormat: "H:mm"
    )
}
```

- [ ] **Step 3: 运行完整验证**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests && swift build --disable-sandbox && git diff --check`

Expected: 三个命令退出码均为 0。

- [ ] **Step 4: 提交 SwiftUI 展示变更**

Run: `git add Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift && git commit -m "fix: hide unavailable five-hour quota"`

### Task 3: 生成正式补丁包

**Files:**

- Modify: `VERSION`
- Modify: `CHANGELOG.md`
- Modify: `dist/Codex Quota.app/Contents/Info.plist`
- Modify: `dist/Codex Quota.app/Contents/MacOS/Codexquota`
- Create: `dist/releases/Codex-Quota-v1.0.5.zip`

- [ ] **Step 1: 将 PATCH 版本从 1.0.4 升至 1.0.5，并写明用户可感知变更与验证结果**

Run: 将 `VERSION` 写为 `1.0.5`，并在 `CHANGELOG.md` 中加入本功能及 self-test、Swift build 验证项。

- [ ] **Step 2: 在已合并的 `main` 上运行正式打包脚本**

Run: `./scripts/package-release.sh`

Expected: 生成新 `Codex Quota.app` 与 `dist/releases/Codex-Quota-v1.0.5.zip`，且不覆盖旧版本资产。

- [ ] **Step 3: 检查包内容、版本号和 zip 完整性**

Run: `plutil -p 'dist/Codex Quota.app/Contents/Info.plist' && unzip -t dist/releases/Codex-Quota-v1.0.5.zip`

Expected: Info.plist 含版本 `1.0.5`，zip 检查成功。

- [ ] **Step 4: 提交正式打包结果**

Run: `git add VERSION CHANGELOG.md 'dist/Codex Quota.app' dist/releases/Codex-Quota-v1.0.5.zip && git commit -m "build: package v1.0.5"`
