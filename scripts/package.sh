#!/bin/bash
# Builds a release .app bundle, code-signs it, and (optionally) notarizes it.
#
# Env vars:
#   CODESIGN_IDENTITY  - Developer ID Application identity to sign with.
#                         Defaults to ad-hoc signing ("-") if unset.
#   NOTARY_PROFILE      - keychain profile name created via
#                         `xcrun notarytool store-credentials`.
#                         If unset, notarization is skipped.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="TrayFlow"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"

echo "=== Building release binary ==="
swift build -c release

echo "=== Assembling app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp Info.plist "$APP_BUNDLE/Contents/"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
else
    echo "Warning: Resources/AppIcon.icns not found. Run 'make icon' first."
fi

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== Code signing ==="
IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
    echo "No CODESIGN_IDENTITY set — using ad-hoc signature (local use only, not distributable)."
else
    echo "Signing with identity: $IDENTITY"
fi
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "=== Notarizing ==="
    ZIP_PATH="${APP_NAME}.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    rm -f "$ZIP_PATH"
    echo "=== Notarization complete ==="
else
    echo "NOTARY_PROFILE not set — skipping notarization."
    echo "To notarize: xcrun notarytool store-credentials <profile> --apple-id <email> --team-id <team> --password <app-specific-password>"
    echo "Then re-run with NOTARY_PROFILE=<profile> CODESIGN_IDENTITY=\"Developer ID Application: ...\" ./scripts/package.sh"
fi

echo "=== Done: $APP_BUNDLE ==="
