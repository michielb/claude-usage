# Claude Usage

Mac menu bar app that tracks Claude rate-limit usage: the 5-hour window, the 7-day window, and model-scoped weekly limits (e.g. Fable).

## Stack
- Swift 6 / SwiftUI with MenuBarExtra
- Swift Package Manager (build with `swift build`)
- No external dependencies

## Architecture
- `App.swift` — Entry point, MenuBarExtra scene
- `UsageService.swift` — OAuth token retrieval (macOS Keychain), API polling every 3 min, service state machine, pace targets
- `ProgressBarRenderer.swift` — NSImage-based progress bars for menu bar (plus compact "C" mode)
- `MenuBarView.swift` — Menu bar label layout: `52% ====+---- 5h 62% ====+---- 7d`
- `DetailView.swift` — Dropdown panel with all usage tiers and controls
- `FloatingPanel.swift` — Always-on-top HUD panel and its controller
- `OnboardingView.swift` — First-run window when no credentials are found
- `AppSettings.swift` — Compact mode setting, auto-enabled on narrow screens
- `Models.swift` — Codable structs for API response
- `docs/menubar.png`, `docs/detail.png` — README graphics rendered from the app's own drawing code with mock data; regenerate with `bash scripts/readme-graphics.sh` after visual changes

## API
- Endpoint: `GET https://api.anthropic.com/api/oauth/usage`
- Auth: OAuth token from Keychain (`Claude Code-credentials`)
- Rate limit: poll no more than once per 2-3 minutes

## Build & Run
```sh
swift build
.build/debug/ClaudeUsage
```

## Package for Distribution
```sh
bash scripts/build.sh <version>   # e.g. bash scripts/build.sh 1.0.6
```
This builds a universal binary (arm64 + x86_64), assembles the .app bundle, code-signs, creates a .pkg installer, notarizes with Apple, and staples. Output: `build/ClaudeUsage-<version>.pkg`

Requires Developer ID certificates and notary credentials (see comments in `scripts/build.sh`).
