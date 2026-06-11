# Claude Usage

Mac menu bar app that tracks Claude API usage within the 5-hour rate limit window.

## Stack
- Swift 6 / SwiftUI with MenuBarExtra
- Swift Package Manager (build with `swift build`)
- No external dependencies

## Architecture
- `App.swift` — Entry point, MenuBarExtra scene
- `UsageService.swift` — OAuth token retrieval (macOS Keychain), API polling every 3 min
- `ProgressBarRenderer.swift` — NSImage-based progress bar for menu bar
- `MenuBarView.swift` — Menu bar label layout: `52% ====+---- 5h`
- `DetailView.swift` — Dropdown panel with all usage tiers
- `Models.swift` — Codable structs for API response

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
