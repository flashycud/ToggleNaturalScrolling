# ToggleNaturalScrolling

A lightweight macOS app that instantly toggles your scroll direction between Natural and Traditional with a single click — no System Settings UI, no accessibility permissions needed.

## How It Works

1. Reads the current `com.apple.swipescrolldirection` preference
2. Flips the boolean value
3. Writes it back to both `AnyHost` and `CurrentHost` preference domains
4. Applies the change immediately via Apple's `activateSettings -u`
5. Shows a macOS notification confirming the new direction

## Requirements

- macOS (tested on macOS Tahoe 26.x)
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
cd Contents
xcrun clang -O2 -framework Foundation -o MacOS/ToggleScrolling Resources/main.m
codesign -fs - /Applications/ToggleNaturalScrolling.app
```

## Install

Copy `ToggleNaturalScrolling.app` to `/Applications/` (or anywhere you like), then double-click to toggle.

## Usage

- **Double-click** the app to toggle scroll direction
- A notification will confirm: "Scrolling → Natural" or "Scrolling → Traditional"
- No windows open, no Dock icon — it runs and quits instantly
