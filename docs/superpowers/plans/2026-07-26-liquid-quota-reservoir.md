# Liquid Quota Reservoir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the collapsed circular quota gauge with a 46-point frosted-glass liquid reservoir that stays visible while the panel expands.

**Architecture:** `WeeklyQuotaPresentation.normalizedRemainingProgress` continues to supply the liquid level. A private SwiftUI view in `TrafficGlassRootView.swift` renders the glass vessel and an animatable sine-wave fill, mapping existing weekly quota bands to coral, amber, and emerald water. The reservoir is always part of the left stack and the window uses one fixed height in both collapsed and expanded states, eliminating the current removal-and-resize flicker.

**Tech Stack:** Swift 6, SwiftUI, CodexTrafficGlassCore self-test executable.

---

### Task 1: Add reservoir layout specifications

**Files:**
- Modify: `Sources/CodexTrafficGlassCore/CodexPanelVisualMetrics.swift`
- Modify: `Sources/CodexTrafficGlassCore/CodexPanelMotion.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
try expect(CodexPanelVisualMetrics.quotaReservoirSize == 46, "quota reservoir should use the approved 46 point size")
try expect(CodexPanelVisualMetrics.quotaReservoirCornerRadius == 16, "quota reservoir should use the approved 16 point corner radius")
try expect(
    CodexPanelMotion.quotaReservoirWindowHeight == CodexPanelMotion.collapsedWindowHeight,
    "expanded and collapsed states should use the same reservoir window height"
)
```

- [ ] **Step 2: Run the self-test to verify it fails**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: compilation fails because the reservoir metrics and fixed window-height constant do not exist.

- [ ] **Step 3: Add core constants**

```swift
// CodexPanelVisualMetrics.swift
public static let quotaReservoirSize = 46.0
public static let quotaReservoirCornerRadius = 16.0

// CodexPanelMotion.swift
public static let quotaReservoirWindowHeight = collapsedWindowHeight
```

- [ ] **Step 4: Run the self-test to verify it passes**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests`

Expected: `All self-tests passed`.

### Task 2: Replace the gauge with a persistent liquid reservoir

**Files:**
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift`
- Modify: `Sources/CodexTrafficGlassApp/App/CodexTrafficGlassApp.swift`

- [ ] **Step 1: Keep the reservoir in the left stack in both states**

```swift
VStack(spacing: CodexPanelVisualMetrics.quotaGaugeSpacing) {
    TrafficLightColumn(snapshot: store.snapshot)
        .overlay(alignment: .trailing) { /* existing collapsed-only expand button */ }
    CollapsedWeeklyQuotaReservoir(quota: store.snapshot.quota)
}
```

Remove the `if !store.isExpanded` around the quota view. Do not change the collapsed-only expand button.

- [ ] **Step 2: Keep the app window height fixed while expanding**

```swift
private var windowHeight: Double {
    CodexPanelMotion.quotaReservoirWindowHeight
}

FloatingWindowConfigurator(
    width: store.isExpanded ? CodexPanelMotion.expandedWidth : CodexPanelMotion.collapsedWidth,
    height: CodexPanelMotion.quotaReservoirWindowHeight
)
```

- [ ] **Step 3: Add the frosted liquid component and wave shape**

```swift
private struct LiquidWaveShape: Shape {
    var level: CGFloat
    var phase: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(level, phase) }
        set { level = newValue.first; phase = newValue.second }
    }
}

private struct CollapsedWeeklyQuotaReservoir: View {
    let quota: CodexQuota
    @State private var wavePhase = 0.0
}
```

Clip a `LiquidWaveShape` inside a 46-point, 16-point-corner `RoundedRectangle`, use `.ultraThinMaterial` with a low-opacity ice-blue highlight and a single low-contrast border. Use `normalizedRemainingProgress` for `level`; animate `wavePhase` linearly over 4.8 seconds with repeat-forever. Map `.critical`, `.caution`, and `.ample` to coral, amber, and emerald water gradients. Render only the percentage text, with no label or outer glow.

- [ ] **Step 4: Build the application**

Run: `swift build --disable-sandbox --product Codexquota`

Expected: product builds with no compiler errors.

### Task 3: Package and verify

**Files:**
- Update generated app: `dist/Codex Quota.app`

- [ ] **Step 1: Copy and sign the executable**

```bash
cp .build/debug/Codexquota "dist/Codex Quota.app/Contents/MacOS/Codexquota"
/usr/bin/codesign --force --deep --sign - "dist/Codex Quota.app"
/usr/bin/codesign --verify --deep --strict --verbose=4 "dist/Codex Quota.app"
```

- [ ] **Step 2: Run final verification**

Run: `swift run --disable-sandbox CodexTrafficGlassSelfTests && swift build --disable-sandbox --product Codexquota && git diff --check`

Expected: self-tests pass, the app builds, and the source diff has no whitespace errors.
