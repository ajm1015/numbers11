# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
make build          # Release binary (swift build -c release)
make debug          # Debug binary (swift build)
make run            # Debug build + launch
make test           # Run all tests (swift test) — 52 tests across 5 suites
make package        # Build .app bundle + DMG → dist/BrewManager-{version}.dmg
make icon           # Regenerate AppIcon.icns from CoreGraphics script
make clean          # Remove .build/ and dist/
```

Single test: `swift test --filter BrewManagerTests.GitServiceTests/testInvalidHashEmpty`

## Architecture

SwiftUI macOS app (macOS 14+, Swift 5.9) with zero external dependencies. Built as an SPM executable target.

### Three-tier pattern: Actors → @MainActor ViewModels → SwiftUI Views

**Actors** (concurrent, isolated):
- `ProcessRunner` — All subprocess execution (`brew`, `git`). Reads pipes before `waitUntilExit()` to prevent deadlock on >64KB output.
- `GitService` — Manages `~/.brew-manager/` git repo for Brewfile version history. Validates hashes (4-40 hex chars) before any git operation.
- `BrewAPIService` — HTTP client for `formulae.brew.sh/api/`. Client-side filtering with URLSession caching.

**@MainActor singletons:**
- `BrewService` — Wraps `brew` CLI (install, uninstall, upgrade, search, pin, Brewfile ops). Throws `BrewServiceError` on invalid output or path traversal.
- `ThemeManager` — 6 themes persisted via `@AppStorage`.

**ViewModels** (all `@MainActor ObservableObject`):
- `PackageListViewModel` — Central state: installed/outdated packages, filtering, operations with status bar feedback, auto-snapshots Brewfile to git after every change.
- `SearchViewModel` — 300ms debounced search with task cancellation.
- `VersionHistoryViewModel` — Git log browsing with diff viewer.

### Data flow for package operations

```
User action → ViewModel (sets activeOperation) → BrewService (runs brew CLI via ProcessRunner)
  → ViewModel refreshes package list → snapshots Brewfile to GitService → shows success message (3s auto-dismiss)
```

### Key JSON decoders

`brew info --json=v2 --installed` → `BrewInfoResponse` (formulae: `BrewFormulaJSON[]`, casks: `BrewCaskJSON[]`)
- Cask `installed` field is a `String?` (version), NOT an array like formulae

`brew outdated --json=v2` → `BrewOutdatedResponse` (uses `installed_versions`/`current_version` keys)

### View hierarchy

`ContentView` (NavigationSplitView) → 4 sidebar tabs → `PackageListView` (HSplitView: list + detail), `SearchView`, `VersionHistoryView`, `ThemeSettingsView`

### Theme system

`Theme.swift` defines 6 themes (Midnight, Nord, Synthwave, Dracula, Solarized, Monochrome) with 14 color properties each. Injected via `EnvironmentKey` (`.theme`), persisted via `@AppStorage("selectedTheme")`.

## Packaging & Distribution

`make package` (runs `Scripts/package.sh`):
1. `swift build -c release`
2. Assembles `.app` bundle in `dist/` with Info.plist + icon
3. Ad-hoc codesign with entitlements
4. Creates DMG with Applications symlink

Ad-hoc signed only — recipients must Right-click > Open on first launch.

## Important Gotchas

- `brew list --json=v2` does NOT exist. Use `brew info --json=v2 --installed`.
- macOS pipe buffer is 64KB. Always `readDataToEndOfFile()` before `process.waitUntilExit()`.
- SPM executables don't activate as GUI apps. `App.swift` calls `NSApplication.shared.setActivationPolicy(.regular)`.
- Swift regex literals (`/pattern/`) don't compile reliably in this project's Swift version. Use `CharacterSet` or `NSRegularExpression`.
