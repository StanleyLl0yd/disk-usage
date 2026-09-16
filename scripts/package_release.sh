#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUEST_FILE="${1:-.release/request.json}"
OUTPUT_DIR="${2:-release-out}"

if [[ "$REQUEST_FILE" != /* ]]; then
  REQUEST_FILE="$ROOT/$REQUEST_FILE"
fi
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$ROOT/$OUTPUT_DIR"
fi

if [[ ! -f "$REQUEST_FILE" ]]; then
  echo "Missing release request: $REQUEST_FILE" >&2
  exit 1
fi
if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" == "/" ]]; then
  echo "Refusing unsafe output directory: $OUTPUT_DIR" >&2
  exit 1
fi

TAG="$(plutil -extract tag raw "$REQUEST_FILE")"
BUILD="$(plutil -extract build raw "$REQUEST_FILE")"

if [[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)-alpha\.([1-9][0-9]*)$ ]]; then
  VERSION="${BASH_REMATCH[1]}"
else
  echo "Unsupported alpha prerelease tag: $TAG" >&2
  exit 1
fi

if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid build number: $BUILD" >&2
  exit 1
fi

DERIVED_BASE="${RUNNER_TEMP:-$ROOT/.build}"
DERIVED_DATA="$DERIVED_BASE/DiskUsageReleaseDerivedData"

rm -rf "$DERIVED_DATA"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$ROOT/DiskUsage.xcodeproj" \
  -scheme DiskUsage \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS='arm64 x86_64' \
  clean build

APP_PATH="$DERIVED_DATA/Build/Products/Release/DiskUsage.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/DiskUsage"

if [[ ! -d "$APP_PATH" || ! -f "$INFO_PLIST" || ! -x "$EXECUTABLE" ]]; then
  echo "Release app was not produced at $APP_PATH" >&2
  exit 1
fi

ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

if [[ "$ACTUAL_VERSION" != "$VERSION" ]]; then
  echo "Bundle version mismatch: expected $VERSION, got $ACTUAL_VERSION" >&2
  exit 1
fi
if [[ "$ACTUAL_BUILD" != "$BUILD" ]]; then
  echo "Bundle build mismatch: expected $BUILD, got $ACTUAL_BUILD" >&2
  exit 1
fi

ARCH_LIST="$(lipo -archs "$EXECUTABLE")"
case " $ARCH_LIST " in
  *" arm64 "*) ;;
  *) echo "Missing arm64 architecture: $ARCH_LIST" >&2; exit 1 ;;
esac
case " $ARCH_LIST " in
  *" x86_64 "*) ;;
  *) echo "Missing x86_64 architecture: $ARCH_LIST" >&2; exit 1 ;;
esac

# Apple Silicon linkers embed an ad-hoc Mach-O signature even when Xcode code signing is disabled.
# Accept only that identity-less signature; reject any Developer ID/team-backed bundle signature.
SIGN_INFO="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
if ! grep -q '^Signature=adhoc$' <<< "$SIGN_INFO"; then
  echo "Expected only an ad-hoc linker signature." >&2
  echo "$SIGN_INFO" >&2
  exit 1
fi
if grep -q '^Authority=' <<< "$SIGN_INFO"; then
  echo "DiskUsage.app unexpectedly contains a signing authority." >&2
  echo "$SIGN_INFO" >&2
  exit 1
fi
if ! grep -q '^TeamIdentifier=not set$' <<< "$SIGN_INFO"; then
  echo "DiskUsage.app unexpectedly contains a TeamIdentifier." >&2
  echo "$SIGN_INFO" >&2
  exit 1
fi
if [[ -e "$APP_PATH/Contents/_CodeSignature" ]]; then
  echo "DiskUsage.app unexpectedly contains a bundle _CodeSignature directory." >&2
  exit 1
fi

RELEASE_NAME="${TAG#v}"
APP_ZIP="$OUTPUT_DIR/DiskUsage-${RELEASE_NAME}.app.zip"
DMG_PATH="$OUTPUT_DIR/DiskUsage-${RELEASE_NAME}.dmg"
CHECKSUMS_PATH="$OUTPUT_DIR/SHA256SUMS"
DMG_STAGING="$DERIVED_DATA/DMG"

rm -f "$APP_ZIP" "$DMG_PATH" "$CHECKSUMS_PATH"

# Preserve the application bundle structure and resource metadata in the standalone archive.
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"

mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/DiskUsage.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -quiet \
  -volname "DiskUsage ${RELEASE_NAME}" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$(basename "$APP_ZIP")" "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUMS_PATH")"
  shasum -a 256 -c "$(basename "$CHECKSUMS_PATH")"
)

echo "Packaged DiskUsage ${RELEASE_NAME} (build ${BUILD}) without Developer ID signing"
echo "Architectures: ${ARCH_LIST}"
echo "Signature: ad-hoc linker signature only; no signing authority or TeamIdentifier"
echo "Output: ${OUTPUT_DIR}"
