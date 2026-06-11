# Build & Install

## Requirements

- macOS 14.0+
- Swift 6 (Xcode 16+)

## Debug Build

```sh
swift build
.build/debug/ClaudeUsage
```

## Release Build & Install

```sh
# Build release binary
swift build -c release

# Kill running instance
pkill -f ClaudeUsage

# Copy to app bundle
cp .build/release/ClaudeUsage /Applications/ClaudeUsage.app/Contents/MacOS/ClaudeUsage

# Launch
open /Applications/ClaudeUsage.app
```

## App Bundle

The app is a minimal bundle at `/Applications/ClaudeUsage.app`:

```
ClaudeUsage.app/
  Contents/
    Info.plist      # LSUIElement=true (menu bar only, no dock icon)
    MacOS/
      ClaudeUsage   # release binary
```

## First-Time Setup

If the app bundle doesn't exist yet, create it:

```sh
mkdir -p /Applications/ClaudeUsage.app/Contents/MacOS
cp Info.plist /Applications/ClaudeUsage.app/Contents/
swift build -c release
cp .build/release/ClaudeUsage /Applications/ClaudeUsage.app/Contents/MacOS/
```
