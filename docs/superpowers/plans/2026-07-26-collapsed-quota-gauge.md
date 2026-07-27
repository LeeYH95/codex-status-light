# Collapsed Quota Gauge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a 63-point circular weekly-quota gauge below the collapsed traffic light, with a 14-point gap and risk-aware green/amber/coral progress colors.

**Architecture:** Reuse `WeeklyQuotaPresentation.remainingBand` as the canonical weekly-quota color band and add a normalized progress helper beside it. Keep the actual gauge view private to `TrafficGlassRootView.swift`; it only receives `CodexQuota` and appears when the floating panel is collapsed. Window height becomes state-specific so the expanded panel retains its current dimensions.

**Tech Stack:** Swift 6, SwiftUI, CodexTrafficGlassCore self-test executable.

---

### Task 1: Add verified layout and progress specifications

**Files:**
- Modify: `Sources/CodexTrafficGlassCore/WeeklyQuotaPresentation.swift`
- Modify: `Sources/CodexTrafficGlassCore/CodexPanelMotion.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift`

- [ ] **Step 1: Write the failing test**

```swift
try expect(
    WeeklyQuotaPresentation.normalizedRemainingProgress(for: 12) == 0.12,
    "weekly quota gauge should convert 12 percent remaining to 0.12 progress"
)
try expect(
    WeeklyQuotaPresentation.normalizedRemainingProgress(for: 120) == 1,
    "weekly quota gauge progress should clamp values above 100 percent"
)
try expect(CodexPanelVisualMetrics.quotaGaugeDiameter == 63, "quota gauge should use the approved 63 point diameter")
try expect(CodexPanelVisualMetrics.quotaGaugeSpacing == 14, "quota gauge should keep 14 points away from the traffic light")
try expect(CodexPanelMotion.collapsedWindowHeight == 318, "collapsed window should fit the detached quota gauge")
```

- [ ] **Step 2: Run the self-test to verify it fails**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: compilation fails because `normalizedRemainingProgress`, gauge metrics, and `collapsedWindowHeight` do not yet exist.

- [ ] **Step 3: Add the smallest core implementation**

```swift
// WeeklyQuotaPresentation.swift
public static func normalizedRemainingProgress(for remainingPercent: Double?) -> Double {
    min(1, max(0, (remainingPercent ?? 0) / 100))
}

// CodexPanelVisualMetrics.swift
public static let quotaGaugeDiameter = 63.0
public static let quotaGaugeSpacing = 14.0

// CodexPanelMotion.swift
public static let collapsedWindowHeight = 318.0
```

- [ ] **Step 4: Run the self-test to verify it passes**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: `All self-tests passed`.

### Task 2: Render the collapsed-only quota gauge

**Files:**
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift`
- Modify: `Sources/CodexTrafficGlassApp/App/CodexTrafficGlassApp.swift`
- Test: `Tests/CodexTrafficGlassSelfTests/main.swift`

- [ ] **Step 1: Use state-specific window height and wrap the light column**

```swift
private var windowHeight: Double {
    store.isExpanded ? CodexPanelMotion.windowHeight : CodexPanelMotion.collapsedWindowHeight
}

VStack(spacing: CodexPanelVisualMetrics.quotaGaugeSpacing) {
    TrafficLightColumn(snapshot: store.snapshot)
    if !store.isExpanded {
        CollapsedWeeklyQuotaGauge(quota: store.snapshot.quota)
    }
}

// CodexTrafficGlassApp.swift
FloatingWindowConfigurator(
    width: store.isExpanded ? CodexPanelMotion.expandedWidth : CodexPanelMotion.collapsedWidth,
    height: store.isExpanded ? CodexPanelMotion.windowHeight : CodexPanelMotion.collapsedWindowHeight
)
```

- [ ] **Step 2: Add the private SwiftUI gauge**

```swift
private struct CollapsedWeeklyQuotaGauge: View {
    let quota: CodexQuota

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.10), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.035, WeeklyQuotaPresentation.normalizedRemainingProgress(for: quota.weeklyRemainingPercent)))
                .stroke(progressGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(quota.weeklyRemainingPercent.map { "\(Int($0.rounded()))%" } ?? "--")
                .monospacedDigit()
        }
        .frame(width: CodexPanelVisualMetrics.quotaGaugeDiameter, height: CodexPanelVisualMetrics.quotaGaugeDiameter)
    }
}
```

Use `WeeklyQuotaPresentation.remainingBand` for the three approved gradients:

```swift
case .critical: [Color(red: 1.0, green: 0.58, blue: 0.55), Color(red: 0.95, green: 0.28, blue: 0.31)]
case .caution: [Color(red: 1.0, green: 0.89, blue: 0.54), Color(red: 0.96, green: 0.66, blue: 0.17)]
case .ample: [Color(red: 0.64, green: 1.0, blue: 0.83), Color(red: 0.15, green: 0.85, blue: 0.51)]
```

- [ ] **Step 3: Build the app**

Run: `swift build --disable-sandbox --product Codexquota`

Expected: product builds with no compiler errors.

### Task 3: Package and verify the app

**Files:**
- Update generated app: `dist/Codex Quota.app`

- [ ] **Step 1: Copy and re-sign the built executable**

```bash
cp .build/debug/Codexquota "dist/Codex Quota.app/Contents/MacOS/Codexquota"
/usr/bin/codesign --force --deep --sign - "dist/Codex Quota.app"
/usr/bin/codesign --verify --deep --strict --verbose=4 "dist/Codex Quota.app"
```

- [ ] **Step 2: Final verification**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests && swift build --disable-sandbox --product Codexquota && git diff --check`

Expected: all self-tests pass, the executable builds, and the diff has no whitespace errors.
