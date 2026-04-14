# CLAUDE.md — BrewManager v0.2.0 Feature Sprint

## Goal

Ship 8 features in a single pass. Every feature must compile, not regress the existing 52 tests, and be manually verifiable per the criteria below. No partial implementations — if a feature can't be completed, skip it entirely rather than leaving stubs.

## Build & Test

```bash
make build          # Must succeed with zero warnings
make test           # All 52 existing tests + any new tests must pass
make run            # Launch and manually verify each feature
```

Single test: `swift test --filter BrewManagerTests.SuiteName/testName`

## Architecture Context

Read the existing CLAUDE.md at project root for full architecture. Key points:

- Three-tier: Actors → @MainActor ViewModels → SwiftUI Views
- Zero external dependencies. SPM executable target. macOS 14+ / Swift 5.9.
- `ProcessRunner` is an actor — all subprocess calls go through it.
- Swift regex literals (`/pattern/`) don't compile reliably. Use `CharacterSet` or `NSRegularExpression`.
- macOS pipe buffer is 64KB. Always `readDataToEndOfFile()` before `process.waitUntilExit()`.
- `brew list --json=v2` does NOT exist. Use `brew info --json=v2 --installed`.
- Pure ASCII only in any scripts or string literals that touch the shell.

## Features

### 1. Real Content Scaling (CRITICAL — replaces broken zoom)

**What exists now:** `App.swift` has `adjustScale(by:)` and `resetScale()` that call `window.setFrame()`. This resizes the window, not the content. Cmd+/- and Cmd+0 are bound to these broken methods.

**What done looks like:**
- `@AppStorage("uiScale")` stores a `CGFloat` (default 1.0, range 0.75–1.5, step 0.05)
- Root `ContentView` is wrapped in `.scaleEffect(scale)` with compensating `.frame()` so layout doesn't clip
- Cmd+/- increments/decrements by 0.05, Cmd+0 resets to 1.0
- `adjustScale(by:)`, `resetScale()`, and all `window.setFrame` logic deleted from `App.swift`
- Scale persists across launches

**What you'd get wrong:**
- `scaleEffect` on a `NavigationSplitView` can cause hit-testing misalignment. If this happens, apply the scale to each pane's content individually instead of the root. Test clicking buttons at 0.75x and 1.5x.
- Don't use `GeometryReader` to compute the compensating frame — it creates feedback loops. Use `NSScreen.main!.visibleFrame` or fixed base dimensions (1100x750 from the existing `.defaultSize`).
- The keyboard shortcuts are defined in `.commands {}` on the `WindowGroup` — they must stay there, just rewired to modify the `@AppStorage` value.

---

### 2. Phased Package Loading

**What exists now:** `PackageListViewModel.loadPackages()` fires in `.task` on `ContentView`. If Homebrew is slow (common — 2-5 seconds for `brew info --json=v2 --installed`), the user sees a spinner and nothing else.

**What done looks like:**
- On launch, immediately read `~/.brew-manager/Brewfile` via `GitService.shared.readBrewfile()` and populate the package list from those entries (name + type, no version info yet). Show these with a "cached" indicator.
- In parallel, fire the real `brew info` + `brew outdated` calls.
- When live data arrives, merge it over the cached list. Packages in cached but not in live = stale (remove them). Packages in live but not cached = new (add them). Matched packages get their full metadata.
- If the Brewfile doesn't exist yet (first run), fall through to the current spinner behavior.

**What you'd get wrong:**
- `GitService` is an `actor` and `readBrewfile()` is `async`. You still need to call it from `@MainActor` context via `await`.
- The cached Brewfile entries are `BrewfileEntry` (type: `.brew`/`.cask`/`.tap`), not `BrewPackage`. You need to convert: `BrewfileEntry` → `BrewPackage` with `installedVersion: nil`, `latestVersion: nil`, etc. Skip `.tap` entries.
- Don't show taps in the cached list — the package list only shows formulae and casks.

---

### 3. First-Run Brew Validation

**What exists now:** If `brew` isn't at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`, `ProcessRunner` will fail on first use with an unhelpful `ProcessError`. No graceful handling.

**What done looks like:**
- New `BrewSetupView` shown instead of `ContentView` when brew is not detected.
- View shows: "Homebrew not found" message, detected search paths that were checked, a link to `https://brew.sh`, and a "Retry" button.
- Detection: `ProcessRunner` already resolves the path in `init()`. Expose a `var isBrewAvailable: Bool` on `ProcessRunner` that checks `FileManager.default.fileExists(atPath: brewPath)`.
- `App.swift` checks this before showing `ContentView`. Use `@State private var brewAvailable` set in `.task`.

**What you'd get wrong:**
- `ProcessRunner` is an `actor` — you can't synchronously read `isBrewAvailable` from `@MainActor`. Either make it a simple synchronous static check (FileManager is thread-safe for `fileExists`), or wrap it in an async call at app startup.
- Don't add Homebrew installation logic. Just detect + inform + link + retry.

---

### 4. In-Memory API Cache for Search

**What exists now:** `BrewAPIService.searchFormulae()` and `searchCasks()` each fetch the full `formula.json` / `cask.json` from `formulae.brew.sh` on every search call. URLSession has `returnCacheDataElseLoad` but no explicit TTL.

**What done looks like:**
- Add private `cachedFormulae: [FormulaAPIResponse]?` and `cachedCasks: [CaskAPIResponse]?` properties on `BrewAPIService` with timestamps.
- On first search, fetch and cache. Subsequent searches filter the cached array.
- Cache expires after 1 hour (compare `Date()` to stored timestamp). Next search after expiry re-fetches.
- Add `func invalidateCache()` for manual refresh.

**What you'd get wrong:**
- `BrewAPIService` is an `actor` — the cached properties are already isolated. No extra synchronization needed, but also no `@Published`. This is fine since the cache is internal.
- The `formula.json` endpoint returns ~6,500 entries (~4MB). The `cask.json` is ~7,000 entries. Both are fine to hold in memory. Don't prematurely optimize with disk caching.

---

### 5. Bulk Operations (Multi-Select)

**What exists now:** Single package selection only. `PackageListViewModel.selectedPackage` is a single `BrewPackage?`.

**What done looks like:**
- Add `@Published var selectedPackages: Set<BrewPackage> = []` to `PackageListViewModel`. Keep `selectedPackage` for detail pane (last selected).
- `PackageListView` list uses `.selection($vm.selectedPackages)` for multi-select (Cmd+click, Shift+click — native macOS List behavior).
- When multiple are selected, detail pane shows a summary: "N packages selected" with bulk action buttons: "Upgrade Selected", "Uninstall Selected".
- Bulk uninstall shows a single confirmation dialog listing all package names.
- Operations run sequentially (not parallel — brew doesn't handle concurrent installs).
- Status bar shows progress: "Uninstalling 1/5: jq..."
- After all operations complete, single refresh + snapshot.

**What you'd get wrong:**
- `List` multi-selection on macOS requires `Set<SelectionValue>` where `SelectionValue: Hashable`. `BrewPackage` already conforms to `Hashable` but its hash includes ALL fields. Two packages with the same name but different versions won't deduplicate in the Set. This is actually correct for our use case — the set represents installed packages which have unique `id` values (`type:name`).
- Don't change `selectedPackage` (singular) to optional — the detail pane still needs it for single-selection. Update it to the last-clicked item from the set.
- The `confirmationDialog` for bulk uninstall needs to list names. Use a `Text` with `packages.map(\.name).sorted().joined(separator: ", ")`.

---

### 6. Declarative Brewfile Mode

**What exists now:** App is fully imperative — each action calls `brew install/uninstall/upgrade` directly, then snapshots the Brewfile afterward.

**What done looks like:**
- New toggle in the UI: "Declarative Mode" (persisted via `@AppStorage("declarativeMode")`). Place it in the sidebar footer near the theme dots, or in a new Preferences area.
- When enabled:
  - Install/Uninstall actions edit the Brewfile (add/remove entries) instead of calling brew directly.
  - A new "Apply Changes" button appears (prominent, in the toolbar or status bar) showing pending change count.
  - "Apply Changes" calls `brew bundle install --cleanup --file=<path>` which converges system state to match the Brewfile. `--cleanup` removes packages not in the Brewfile.
  - After apply, refresh package list + git commit the Brewfile.
- When disabled: current imperative behavior, no change.
- Add `applyBrewfile()` to `BrewService` that runs `brew bundle install --cleanup --file=<path>`.

**What you'd get wrong:**
- `brew bundle install --cleanup` can remove packages the user didn't intend if their Brewfile is incomplete. On first enable of declarative mode, auto-export the current system state to the Brewfile first (call `dumpBrewfile()` + write) so nothing gets nuked.
- The Brewfile path is `~/.brew-manager/Brewfile` (managed by `GitService`). Pass this path to `brew bundle`.
- Pending changes need to be tracked as a diff between the current Brewfile and the proposed Brewfile. Store a `pendingBrewfile: Brewfile?` on the ViewModel. On "Apply", write it and run bundle.
- `--cleanup` also removes casks. This is correct but scary. Show a clear warning on the Apply confirmation: "This will install X, remove Y, and upgrade Z."

---

### 7. Keyboard Navigation

**What exists now:** Cmd+R refresh, Cmd+Shift+E export, Cmd+Shift+I import, Cmd+/- zoom (broken). No keyboard nav in lists or search.

**What done looks like:**
- **Escape:** Clear filter text (PackageListView), clear search (SearchView), deselect package.
- **Enter/Return:** When a search result is focused, install it. When an installed package is focused, open detail.
- **Delete/Backspace:** When an installed package is focused, trigger uninstall confirmation.
- **Cmd+F:** Focus the filter/search text field.
- **Tab:** Move focus between sidebar and detail areas.
- **Arrow keys:** Already handled by native `List` — verify they work.

Implementation: Use `.onKeyPress` (macOS 14+) on the relevant views, or `.keyboardShortcut` on invisible buttons. Prefer `.onKeyPress` since it's view-scoped.

**What you'd get wrong:**
- `.onKeyPress` requires the view to be focused. Lists in SwiftUI on macOS handle arrow keys natively but won't forward Enter/Delete unless you add explicit handling.
- Don't use `NSEvent.addLocalMonitorForEvents` — that's AppKit global and will conflict. Stay in SwiftUI.
- Escape to clear filter: check `vm.filterText.isEmpty` first — if already empty, deselect package instead.

---

### 8. Semantic Diff Viewer

**What exists now:** `DiffContentView` in `VersionHistoryView.swift` renders raw git diff output with line-level coloring (+green, -red, @@blue).

**What done looks like:**
- Above the raw diff, add a summary card:
  - "Added: jq, ripgrep, fd" (green, using `theme.success`)
  - "Removed: wget" (red, using `theme.danger`)
  - Package count badge: "+3 / -1"
- Data source: `VersionEntry` already has `addedPackages` and `removedPackages` arrays (populated by `GitService.parseDiff`).
- The raw diff stays below the summary, collapsed by default behind a "Show raw diff" disclosure.
- Summary card uses `FlowLayout` (already exists in `PackageDetailView.swift`) for the package name chips.

**What you'd get wrong:**
- `VersionEntry.addedPackages` and `removedPackages` might be empty for the initial commit (no parent to diff against). Handle gracefully — show "Initial Brewfile" or similar.
- The `FlowLayout` is defined in `PackageDetailView.swift` — it's not a standalone file. Either move it to a shared `Utilities/` or duplicate. Moving is better.
- Don't fetch additional data for the summary — it's already in the `VersionEntry` model. The semantic view is pure UI over existing data.

---

## Task Order

Build in this order to minimize conflicts:

1. **Feature 1** (scaling) — touches `App.swift` and `ContentView`. Get this done first since it changes the root view.
2. **Feature 3** (brew validation) — also touches `App.swift`. Do it right after scaling.
3. **Feature 7** (keyboard nav) — touches multiple views but additive (no existing code changes).
4. **Feature 4** (API cache) — isolated to `BrewAPIService.swift`. No view changes.
5. **Feature 2** (phased loading) — touches `PackageListViewModel` and `ContentView`. 
6. **Feature 8** (semantic diff) — isolated to `VersionHistoryView.swift` + `FlowLayout` extraction.
7. **Feature 5** (bulk operations) — touches `PackageListViewModel`, `PackageListView`, `PackageDetailView`.
8. **Feature 6** (declarative mode) — most invasive. Touches `BrewService`, `PackageListViewModel`, `PackageListView`, sidebar. Do last.

## Verification Checklist

After all features:

```
[ ] make build — zero warnings
[ ] make test — all tests pass (52 existing + new)
[ ] Cmd+Plus zooms content, not window. Cmd+0 resets. Persists across relaunch.
[ ] Launch with brew installed — cached list appears instantly, live data merges in.
[ ] Launch with brew removed from PATH — setup view appears with link and retry.
[ ] Search "jq" — first search fetches, second search instant (cached).
[ ] Cmd+click 3 packages — detail pane shows bulk actions. Bulk upgrade works.
[ ] Enable declarative mode — install edits Brewfile, "Apply Changes" converges.
[ ] Escape clears filter. Delete on selected package triggers uninstall confirm.
[ ] Version history shows semantic summary cards above raw diff.
[ ] All 6 themes still work. Theme switcher still functional.
[ ] No regressions in existing flows: single install, uninstall, upgrade, pin, export, import.
```

## New Tests to Add

- Scaling: Test that `uiScale` `@AppStorage` default is 1.0, clamps to 0.75–1.5.
- API Cache: Test that second call to `searchFormulae` doesn't re-fetch (mock URLSession or check cache state).
- Brew validation: Test `isBrewAvailable` returns false when path doesn't exist.
- Bulk operations: Test that sequential uninstall processes all packages (mock BrewService).
- Declarative mode: Test that `applyBrewfile()` calls correct brew bundle command.
- Semantic diff: Test that empty `addedPackages`/`removedPackages` renders gracefully.

## Style

- Zero external dependencies. Everything stays in the SPM package as-is.
- Pure ASCII in all string literals.
- Follow existing patterns: actors for concurrent work, `@MainActor` for ViewModels, `@Environment(\.theme)` for colors.
- Minimal code. No wrappers, no abstractions beyond what's needed. This is a 1-person utility app.
