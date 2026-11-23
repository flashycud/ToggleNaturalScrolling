#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
artwork="${1:-$root/Resources/AppIcon.png}"
output="${2:-$root/build/ToggleNaturalScrolling.app}"

if [[ ! -f "$artwork" ]]; then
    echo "Provide a 1024x1024 PNG icon as the first argument (or add Resources/AppIcon.png)." >&2
    exit 1
fi
properties="$(sips -g format -g pixelWidth -g pixelHeight "$artwork")"
if ! grep -Eq 'format: png[[:space:]]*$' <<< "$properties" ||
   ! grep -Eq 'pixelWidth: 1024[[:space:]]*$' <<< "$properties" ||
   ! grep -Eq 'pixelHeight: 1024[[:space:]]*$' <<< "$properties"; then
    echo "Icon artwork must be a 1024x1024 PNG." >&2
    exit 1
fi
if [[ -e "$output" ]]; then
    echo "Output already exists: $output. Choose a new output path." >&2
    exit 1
fi

contents="$output/Contents"
iconset="$contents/Resources/AppIcon.iconset"
mkdir -p "$contents/MacOS" "$iconset"
cp "$root/Info.plist" "$contents/Info.plist"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$artwork" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$artwork" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$contents/Resources/AppIcon.icns"
for size in 16 32 128 256 512; do
    rm "$iconset/icon_${size}x${size}.png" "$iconset/icon_${size}x${size}@2x.png"
done
rmdir "$iconset"
xcrun clang -O2 -framework Foundation -o "$contents/MacOS/ToggleScrolling" "$root/Resources/main.m"
codesign --force --sign - "$output"
echo "Built $output"
