#!/bin/bash
set -euo pipefail

# Configuration
# Team ID: 45E2M62JUC (from Apple Developer account)
#
# To set up signing:
# 1. Go to https://developer.apple.com/account/resources/certificates
# 2. Click "+" → create "Developer ID Application" certificate
# 3. Click "+" → create "Developer ID Installer" certificate
# 4. Download and double-click both to install in Keychain
# 5. Run: xcrun notarytool store-credentials "claude-usage-notary"
#    (enter Apple ID, app-specific password, team ID 45E2M62JUC)
# 6. Verify: security find-identity -v -p codesigning | grep "Developer ID"
#
APP_IDENTITY="${APP_IDENTITY:-Developer ID Application: Michiel Berger (45E2M62JUC)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-Developer ID Installer: Michiel Berger (45E2M62JUC)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-claude-usage-notary}"

VERSION="${1:-1.0.0}"
APP_NAME="ClaudeUsage"
APP_BUNDLE="${APP_NAME}.app"
PKG_NAME="${APP_NAME}-${VERSION}.pkg"
BUILD_DIR="build"

echo "==> Building ${APP_NAME} v${VERSION}"

# 1. Build universal binary
echo "==> Building universal binary..."
swift build -c release --arch arm64
swift build -c release --arch x86_64

ARM_BIN=".build/arm64-apple-macosx/release/${APP_NAME}"
X86_BIN=".build/x86_64-apple-macosx/release/${APP_NAME}"

mkdir -p "${BUILD_DIR}"
UNIVERSAL_BIN="${BUILD_DIR}/${APP_NAME}"
lipo -create -output "${UNIVERSAL_BIN}" "${ARM_BIN}" "${X86_BIN}"
echo "    Universal binary: $(file "${UNIVERSAL_BIN}" | sed 's/.*: //')"

# 2. Assemble .app bundle
echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${BUILD_DIR}/${APP_BUNDLE}"
mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources"

cp "${UNIVERSAL_BIN}" "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/"
cp Info.plist "${BUILD_DIR}/${APP_BUNDLE}/Contents/"

# Inject version into Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${BUILD_DIR}/${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${BUILD_DIR}/${APP_BUNDLE}/Contents/Info.plist"

# Copy icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/"
fi

# 3. Code sign
echo "==> Code signing..."
codesign --force --options runtime --timestamp \
    --sign "${APP_IDENTITY}" \
    --entitlements Entitlements.plist \
    "${BUILD_DIR}/${APP_BUNDLE}"

echo "    Signed: $(codesign -dv "${BUILD_DIR}/${APP_BUNDLE}" 2>&1 | grep 'Authority='  | head -1)"

# 4. Verify signature
echo "==> Verifying signature..."
codesign --verify --strict "${BUILD_DIR}/${APP_BUNDLE}"

# 5. Build .pkg (component + product for welcome/readme screens)
echo "==> Building ${PKG_NAME}..."

PKG_ROOT="${BUILD_DIR}/pkg-root"
COMPONENT_PKG="${BUILD_DIR}/component.pkg"
rm -rf "${PKG_ROOT}"
mkdir -p "${PKG_ROOT}/Applications"
cp -R "${BUILD_DIR}/${APP_BUNDLE}" "${PKG_ROOT}/Applications/"

# Prepare postinstall scripts directory
SCRIPTS_DIR="${BUILD_DIR}/pkg-scripts"
rm -rf "${SCRIPTS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
cp scripts/postinstall "${SCRIPTS_DIR}/postinstall"
chmod +x "${SCRIPTS_DIR}/postinstall"

# Build component package (unsigned — the product archive gets signed)
pkgbuild \
    --root "${PKG_ROOT}" \
    --identifier "com.michielb.claude-usage" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    "${COMPONENT_PKG}"

# Create distribution XML with welcome + readme
DIST_XML="${BUILD_DIR}/distribution.xml"
cat > "${DIST_XML}" << 'DISTEOF'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Claude Usage</title>
    <welcome file="welcome.html" />
    <readme file="readme.html" />
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64" />
    <choices-outline>
        <line choice="default">
            <line choice="com.michielb.claude-usage"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.michielb.claude-usage" visible="false">
        <pkg-ref id="com.michielb.claude-usage"/>
    </choice>
    <pkg-ref id="com.michielb.claude-usage" version="VERSION" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
DISTEOF

# Inject version into distribution XML
sed -i '' "s/VERSION/${VERSION}/g" "${DIST_XML}"

# Build final product archive with welcome/readme and signing
productbuild \
    --distribution "${DIST_XML}" \
    --resources Resources \
    --package-path "${BUILD_DIR}" \
    --sign "${INSTALLER_IDENTITY}" \
    "${BUILD_DIR}/${PKG_NAME}"

rm -rf "${PKG_ROOT}" "${COMPONENT_PKG}" "${DIST_XML}" "${SCRIPTS_DIR}"

# 6. Notarize
echo "==> Submitting for notarization..."
xcrun notarytool submit "${BUILD_DIR}/${PKG_NAME}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

# 7. Staple
echo "==> Stapling..."
xcrun stapler staple "${BUILD_DIR}/${PKG_NAME}"

echo ""
echo "==> Done! ${BUILD_DIR}/${PKG_NAME}"
echo "    Version: ${VERSION}"
echo "    Size: $(du -h "${BUILD_DIR}/${PKG_NAME}" | cut -f1)"
