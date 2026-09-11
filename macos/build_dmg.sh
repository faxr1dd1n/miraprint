#!/usr/bin/env bash
set -euo pipefail

# Miraprint uchun tortib-o'rnatish (drag-to-install) .dmg yasaydi:
# Release build qiladi, natijani Applications'ga symlink bilan birga
# .dmg'ga joylaydi. Ishlatish: ./macos/build_dmg.sh

cd "$(dirname "$0")/.."

APP_NAME="miraprint.app"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME"
DMG_NAME="Miraprint.dmg"
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> pubspec.yaml'dagi versiya lib/core/app_version.dart'ga yoziladi"
PUBSPEC_VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')
SEM_VER="${PUBSPEC_VERSION%%+*}"
echo "const String kAppVersion = '$SEM_VER';" > lib/core/app_version.dart
echo "    kAppVersion = $SEM_VER"

echo "==> flutter clean (eski keshlangan build'ni tozalash)"
flutter clean

echo "==> flutter build macos --release"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "Xato: $APP_PATH topilmadi" >&2
  exit 1
fi

echo "==> Staging papka tayyorlanmoqda: $STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

OUT_DMG="$BUILD_DIR/$DMG_NAME"
RW_DMG="$BUILD_DIR/Miraprint-rw.dmg"
VOL_NAME="Miraprint"
rm -f "$OUT_DMG" "$RW_DMG"

echo "==> Vaqtinchalik (yozish mumkin) .dmg yasalmoqda"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$RW_DMG"

echo "==> Mount qilib, Finder ko'rinishini sozlash (Icon View)"
# Oldingi urinishdan shu nomdagi disk mount qilingan holda qolib ketgan
# bo'lishi mumkin — davom etishdan oldin tozalaymiz.
if [ -d "/Volumes/$VOL_NAME" ]; then
  hdiutil detach "/Volumes/$VOL_NAME" -force 2>/dev/null || true
  sleep 1
fi
hdiutil attach "$RW_DMG" -mountpoint "/Volumes/$VOL_NAME"

osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 700, 420}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "$APP_NAME" of container window to {130, 150}
    set position of item "Applications" of container window to {370, 150}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

hdiutil detach "/Volumes/$VOL_NAME"

echo "==> Yakuniy (siqilgan, faqat o'qish) .dmg yasalmoqda: $OUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -o "$OUT_DMG"
rm -f "$RW_DMG"

echo "==> Tayyor: $OUT_DMG"
