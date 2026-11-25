#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
case "${CRUZADOR_UNIVERSAL:-0}" in
    0) set -- ;;
    1) set -- --arch arm64 --arch x86_64 ;;
    *) printf 'CRUZADOR_UNIVERSAL deve ser 0 ou 1.\n' >&2; exit 2 ;;
esac
swift build -c release --jobs 4 "$@"
binary_dir=$(swift build -c release "$@" --show-bin-path)
app="build/Cruzador.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Cruzador" "$app/Contents/MacOS/Cruzador"
cp config/recipes.json "$app/Contents/Resources/recipes.json"
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
<key>CFBundleURLTypes</key><array><dict>
<key>CFBundleURLName</key><string>io.github.wilton-garcia.cruzador.launch</string>
<key>CFBundleURLSchemes</key><array><string>cruzador</string></array>
</dict></array>
<key>CFBundleDocumentTypes</key><array>
<dict><key>CFBundleTypeName</key><string>Programa Windows</string><key>CFBundleTypeExtensions</key><array><string>exe</string><string>msi</string></array><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Alternate</string></dict>
<dict><key>CFBundleTypeName</key><string>Atalho Cruzador</string><key>CFBundleTypeExtensions</key><array><string>cruzadorapp</string></array><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Owner</string></dict>
<dict><key>CFBundleTypeName</key><string>Bottle Cruzador</string><key>CFBundleTypeExtensions</key><array><string>cruzadorbottle</string></array><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Owner</string><key>LSTypeIsPackage</key><true/></dict>
</array>
</dict></plist>
PLIST
runtime_source="${CRUZADOR_RUNTIME_PATH:-.local/Runtime-11.21}"
if [ -d "$runtime_source" ]; then
    python3 scripts/stage-wine-runtime.py "$runtime_source" "$app"
else
    printf 'Pacote Wine ausente: %s. Execute python3 scripts/prepare-wine-runtime.py antes do build.\n' "$runtime_source" >&2
    exit 1
fi
codesign --force --sign - "$app"
printf 'Aplicativo gerado: %s\n' "$app"
