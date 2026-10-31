#!/usr/bin/env bash
# Build CruxShotter.app and package it into build/CruxShotter-<version>.dmg.
#
#   scripts/build-release.sh <version> [--skip-sign]
#
# <version> may carry a pre-release suffix (0.0.1-alpha); MARKETING_VERSION gets the numeric part.
# --skip-sign : Release build, ad-hoc signed without hardened runtime (library validation would reject Sparkle), no export / notarization (local testing, CI without secrets).
# otherwise   : archive -> exportArchive (developer-id) -> notarize -> staple. Requires a Developer ID
#               identity in the keychain and NOTARY_PROFILE (notarytool keychain profile) or
#               APPLE_ID / APPLE_TEAM_ID / APPLE_APP_PASSWORD in the environment.
set -euo pipefail

usage() { echo "usage: $0 <version> [--skip-sign]" >&2; exit 64; }

[[ $# -ge 1 && $# -le 2 ]] || usage
VERSION="$1"
SKIP_SIGN=0
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--skip-sign" ]] || usage
  SKIP_SIGN=1
fi
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$ ]]; then
  echo "error: invalid version '$VERSION' (expected e.g. 0.0.1 or 0.0.1-alpha)" >&2
  exit 64
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="CruxShotter"
SCHEME="CruxShot"
NUMERIC_VERSION="${VERSION%%-*}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
BUILD_DIR="$ROOT/build"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
STAGING="$BUILD_DIR/dmg-staging"
VERSION_SETTINGS=(MARKETING_VERSION="$NUMERIC_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" CRUXSHOT_RELEASE_VERSION="$VERSION")

trap 'rm -rf "$STAGING"' EXIT
rm -rf "$BUILD_DIR/release" "$STAGING" "$DMG"
mkdir -p "$BUILD_DIR/release"

xcodegen generate

if [[ $SKIP_SIGN -eq 1 ]]; then
  xcodebuild -project CruxShot.xcodeproj -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR/release/DerivedData" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO \
    "${VERSION_SETTINGS[@]}" build
  APP="$BUILD_DIR/release/DerivedData/Build/Products/Release/$APP_NAME.app"
else
  ARCHIVE="$BUILD_DIR/release/$APP_NAME.xcarchive"
  EXPORT_DIR="$BUILD_DIR/release/export"
  cat > "$BUILD_DIR/release/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
  <key>teamID</key><string>${APPLE_TEAM_ID:?}</string>
</dict></plist>
PLIST
  xcodebuild -project CruxShot.xcodeproj -scheme "$SCHEME" -configuration Release \
    -archivePath "$ARCHIVE" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="${APPLE_TEAM_ID:?}" \
    "${VERSION_SETTINGS[@]}" archive
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/release/ExportOptions.plist"
  APP="$EXPORT_DIR/$APP_NAME.app"
fi

[[ -d "$APP" ]] || { echo "error: $APP not found" >&2; exit 1; }

mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

if [[ $SKIP_SIGN -eq 0 ]]; then
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    xcrun notarytool submit "$DMG" --apple-id "${APPLE_ID:?}" --team-id "${APPLE_TEAM_ID:?}" \
      --password "${APPLE_APP_PASSWORD:?}" --wait
  fi
  xcrun stapler staple "$DMG"
fi

echo
echo "DMG:    $DMG"
echo "sha256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
