# Claude Usage

A lightweight Mac menu bar app that tracks your Claude API usage within the 5-hour rate limit window.

![menu bar example](https://img.shields.io/badge/menu_bar-55%25_%E2%96%88%E2%96%88%E2%96%88%E2%96%88%E2%96%88%E2%96%88%E2%96%8B%E2%94%80%E2%94%80%E2%94%80_43m-333?style=flat-square)

At a glance you can see:
- **Your current usage** (green bar)
- **Where you should be** based on elapsed time (+ marker)
- **Over-pacing** shown in red when usage exceeds the time-based target
- **Time remaining** until the window resets

## Prerequisites

You need [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated via browser-based OAuth login. The app reads the OAuth token from the macOS Keychain entry that Claude Code creates (`Claude Code-credentials`).

If you authenticated using `claude setup-token` instead of the browser flow, the token won't have the required scope. To fix this:
1. Delete the keychain entry: `security delete-generic-password -s "Claude Code-credentials"`
2. Restart Claude Code and authenticate via browser when prompted

## Build & Install

```sh
swift build -c release
mkdir -p /Applications/ClaudeUsage.app/Contents/MacOS
cp .build/release/ClaudeUsage /Applications/ClaudeUsage.app/Contents/MacOS/
cp ClaudeUsage.app/Contents/Info.plist /Applications/ClaudeUsage.app/Contents/
open /Applications/ClaudeUsage.app
```

To launch at login, add it in **System Settings > General > Login Items**, or:

```sh
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/ClaudeUsage.app", hidden:false}'
```

## How it works

- Polls `https://api.anthropic.com/api/oauth/usage` every 3 minutes
- Reads the OAuth token from the macOS Keychain (created by Claude Code)
- Refreshes automatically on wake from sleep
- No Dock icon — runs as a menu bar-only app

## Requirements

- macOS 14+
- Swift 6
- Claude Pro or Max subscription with Claude Code authenticated via browser OAuth
