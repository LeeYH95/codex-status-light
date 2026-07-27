# Weekly Quota and Reset Timing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the retired 5-hour quota card with a secondary reset-timing card while making weekly quota color reflect remaining capacity.

**Architecture:** Add a Foundation-only presentation helper for capacity bands, weekly cycle elapsed progress, next hourly refresh, and reset labels. The SwiftUI panel consumes those values to render a 60/40 weekly-quota/reset-timing row; time refreshing is aligned to the next wall-clock hour.

**Tech Stack:** Swift 6, SwiftUI, Foundation, SwiftPM self-test executable.

---

### Task 1: Define quota and reset-time semantics in Core

**Files:**
- Create: `Sources/CodexTrafficGlassCore/WeeklyQuotaPresentation.swift`
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift`

- [ ] **Step 1: Write failing self-tests** for capacity thresholds, cycle elapsed ratio, reset labels, and next whole-hour boundary.
- [ ] **Step 2: Run `swift run --disable-sandbox CodexTrafficGlassSelfTests`** and confirm compilation fails because `WeeklyQuotaPresentation` does not exist.
- [ ] **Step 3: Implement `WeeklyQuotaPresentation`** with 60% / 25% remaining-capacity bands; a seven-day cycle derived from `resetAt`; and whole-hour scheduling.
- [ ] **Step 4: Re-run the self-tests** and confirm they pass.

### Task 2: Render the approved 60/40 lower row

**Files:**
- Modify: `Sources/CodexTrafficGlassApp/Views/TrafficGlassRootView.swift`

- [ ] **Step 1: Replace the five-hour `QuotaCard`** with a larger `WeeklyQuotaCard` and a smaller `ResetTimingCard`.
- [ ] **Step 2: Map capacity bands to green, amber, and red**, retaining a neutral fallback when quota is unavailable.
- [ ] **Step 3: Render reset time as an elapsed-cycle neutral bar** and refresh its current-time value at each wall-clock hour.
- [ ] **Step 4: Build the app product** with `swift build --disable-sandbox --product Codexquota`.

### Task 3: Verify integration

**Files:**
- Modify: `Tests/CodexTrafficGlassSelfTests/main.swift` only if additional integration coverage is required

- [ ] **Step 1: Run the full self-test executable.**
- [ ] **Step 2: Run the product build.**
- [ ] **Step 3: Run `git diff --check`** to validate patch formatting and report the exact changed files.
