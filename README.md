# ToggleNaturalScrolling

A lightweight macOS app that toggles between Natural and Traditional scrolling with one click. It runs and quits without a Dock icon and shows a notification after a successful change. If a preference cannot be saved or applied, it displays an error dialog.

## Requirements

- macOS (originally tested on macOS Tahoe 26.x)
- Xcode Command Line Tools (`xcode-select --install`)
- Original 1024 × 1024 PNG icon artwork. Use a square image, preferably with transparency and without a baked-in rounded mask; leave space around the important artwork for small sizes.

## Build

Place the artwork at `Resources/AppIcon.png`, or pass its path as the first argument:

```bash
bash build.sh /path/to/icon.png
```

The script generates a macOS `.icns`, builds `build/ToggleNaturalScrolling.app`, and ad-hoc signs it for local use. It refuses to overwrite an existing output; pass a new output path as the second argument when rebuilding:

```bash
bash build.sh /path/to/icon.png /path/to/new/ToggleNaturalScrolling.app
```

Ad-hoc signing does not notarize the app for distribution.

## Install and use

Copy the built app to `/Applications/`, then double-click it to toggle the scroll direction. Do not replace an existing installation without checking it first.

The app writes the global scroll direction preference for both AnyHost and CurrentHost and invokes macOS's private `activateSettings` utility to apply it. If that utility is unavailable or fails on a future macOS version, the app reports the failure and attempts to restore the previous saved preferences. Check System Settings if the error says the active setting may be inconsistent. macOS notification permissions may affect whether a success notification appears.

## Test

```bash
xcrun clang -framework Foundation Tests/toggle_tests.m -o /tmp/toggle-scrolling-tests
/tmp/toggle-scrolling-tests
```
