#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Periquito Release Script
# Usage: ./scripts/create-release.sh <version>
# Example: ./scripts/create-release.sh 1.1.0
# =============================================================================

# --- Configuration ---
TEAM_ID="SXT98GH5HN"
BUNDLE_ID="com.ruban.periquito"
SCHEME="periquito"
PROJECT_PATH="periquito/periquito.xcodeproj"
APPCAST_OUTPUT="docs/appcast.xml"
APP_NAME="Periquito"

# TODO: Set your notarytool keychain profile name.
# Create one with: xcrun notarytool store-credentials "periquito-notarize" --apple-id "you@example.com" --team-id "SXT98GH5HN"
NOTARYTOOL_PROFILE="periquito-notarize"

# Sparkle tools directory — override with SPARKLE_BIN_DIR env var.
# Falls back to searching DerivedData for the Sparkle build artifacts.
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"

BUILD_DIR="build/release"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

# --- Helpers ---
step() {
    echo ""
    echo "===> $1"
    echo ""
}

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

find_sparkle_bin_dir() {
    if [[ -n "$SPARKLE_BIN_DIR" ]]; then
        echo "$SPARKLE_BIN_DIR"
        return
    fi

    local derived_data="${HOME}/Library/Developer/Xcode/DerivedData"
    local found
    found=$(find "$derived_data" -path "*/Sparkle.framework/../bin" -type d 2>/dev/null | head -n 1)

    if [[ -z "$found" ]]; then
        found=$(find "$derived_data" -name "sign_update" -type f 2>/dev/null | head -n 1)
        if [[ -n "$found" ]]; then
            found=$(dirname "$found")
        fi
    fi

    if [[ -z "$found" ]]; then
        fail "Could not find Sparkle tools. Set SPARKLE_BIN_DIR to the directory containing sign_update and generate_appcast."
    fi

    echo "$found"
}

# --- Step 1: Validate version argument ---
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    fail "Usage: $0 <version>  (e.g. $0 1.1.0)"
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "Version must be in semver format (e.g. 1.1.0), got: $VERSION"
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

step "Starting release build for ${APP_NAME} v${VERSION}"

# --- Step 2: Clean and archive ---
step "Step 1/6: Clean and archive (Developer ID distribution)"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild clean archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE="Manual" \
    | xcpretty || xcodebuild clean archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE="Manual"

echo "Archive created at ${ARCHIVE_PATH}"

# --- Step 3: Export the archive ---
step "Step 2/6: Export archive"

EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$EXPORT_DIR" \
    | xcpretty || xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$EXPORT_DIR"

if [[ ! -d "$APP_PATH" ]]; then
    fail "Export failed: ${APP_PATH} not found"
fi

echo "Exported ${APP_PATH}"

# --- Step 4: Notarize and staple ---
step "Step 3/6: Notarize and staple"

NOTARIZE_ZIP="${BUILD_DIR}/periquito-submit.zip"
echo "Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

echo "Submitting for notarization..."
xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

rm -f "$NOTARIZE_ZIP"

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

echo "Notarization complete and stapled into ${APP_PATH}"

# --- Step 5: Create DMG ---
step "Step 4/6: Create distribution DMG"

DMG_TEMP_DIR="${BUILD_DIR}/dmg-staging"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

cp -R "$APP_PATH" "$DMG_TEMP_DIR/"
ln -s /Applications "$DMG_TEMP_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_TEMP_DIR"

if [[ ! -f "$DMG_PATH" ]]; then
    fail "DMG creation failed: ${DMG_PATH} not found"
fi

echo "Created ${DMG_PATH}"

# --- Step 6: Sign with Sparkle ---
step "Step 5/6: Sign DMG with Sparkle"

SPARKLE_KEY_FILE=".sparkle-keys/eddsa_private_key"
if [[ ! -f "$SPARKLE_KEY_FILE" ]]; then
    fail "Sparkle private key not found at ${SPARKLE_KEY_FILE}. Run generate_keys and save the key there."
fi

SPARKLE_BIN_DIR=$(find_sparkle_bin_dir)
SIGN_UPDATE="${SPARKLE_BIN_DIR}/sign_update"
GENERATE_APPCAST="${SPARKLE_BIN_DIR}/generate_appcast"

if [[ ! -x "$SIGN_UPDATE" ]]; then
    fail "sign_update not found or not executable at ${SIGN_UPDATE}"
fi

if [[ ! -x "$GENERATE_APPCAST" ]]; then
    fail "generate_appcast not found or not executable at ${GENERATE_APPCAST}"
fi

echo "Using Sparkle tools from: ${SPARKLE_BIN_DIR}"

SIGNATURE=$("$SIGN_UPDATE" --ed-key-file "$SPARKLE_KEY_FILE" "$DMG_PATH")
echo "Sparkle signature:"
echo "$SIGNATURE"

# --- Step 7: Generate appcast ---
step "Step 6/6: Generate appcast"

mkdir -p "$(dirname "$APPCAST_OUTPUT")"

APPCAST_STAGING="${BUILD_DIR}/appcast-staging"
rm -rf "$APPCAST_STAGING"
mkdir -p "$APPCAST_STAGING"
cp "$DMG_PATH" "$APPCAST_STAGING/"

"$GENERATE_APPCAST" \
    --ed-key-file "$SPARKLE_KEY_FILE" \
    --download-url-prefix "https://github.com/sk-ruban/periquito/releases/download/v${VERSION}/" \
    -o "$APPCAST_OUTPUT" \
    "$APPCAST_STAGING"

rm -rf "$APPCAST_STAGING"

echo "Appcast written to ${APPCAST_OUTPUT}"

# --- Done ---
step "Release v${VERSION} built successfully!"

echo "Files:"
echo "  DMG:     ${DMG_PATH}"
echo "  Appcast: ${APPCAST_OUTPUT}"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub Release tagged v${VERSION}"
echo "  2. Upload ${DMG_PATH} to the GitHub Release"
echo "  3. Commit ${APPCAST_OUTPUT} and push to main"
echo "  4. Verify the appcast download URL matches your GitHub Release asset URL"
