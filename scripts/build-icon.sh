#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
source="Resources/AppIcon.png"
iconset="build/Cruzador.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$iconset" --output build/AppIcon.icns
