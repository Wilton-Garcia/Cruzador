#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release --jobs 4
binary_dir=$(swift build -c release --show-bin-path)
app="build/Cruzador.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Cruzador" "$app/Contents/MacOS/Cruzador"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Cruzador</string>
<key>CFBundleIdentifier</key><string>io.github.wilton-garcia.cruzador</string>
<key>CFBundleName</key><string>Cruzador</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
runtime_source="${CRUZADOR_RUNTIME_PATH:-.local/Runtime-11.21}"
if [ -d "$runtime_source" ]; then
    python3 scripts/stage-wine-runtime.py "$runtime_source" "$app"
elif [ -n "${CRUZADOR_RUNTIME_PATH:-}" ]; then
    printf 'Pacote Wine selecionado não existe: %s\n' "$runtime_source" >&2
    exit 1
fi
codesign --force --sign - "$app"
printf 'Aplicativo gerado: %s\n' "$app"
