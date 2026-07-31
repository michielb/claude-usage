#!/bin/bash
# Regenerates docs/menubar.png and docs/detail.png from the app's real
# rendering code with mock usage data. Run after visual changes:
#   bash scripts/readme-graphics.sh
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# All app sources except the @main entry point (the script has its own).
SRCS=$(ls Sources/ClaudeUsage/*.swift | grep -v '/App\.swift$')

# swiftc only allows top-level code in a file named main.swift
cp scripts/readme-graphics.swift "$TMP/main.swift"
swiftc -O $SRCS "$TMP/main.swift" -o "$TMP/render"
"$TMP/render" docs
