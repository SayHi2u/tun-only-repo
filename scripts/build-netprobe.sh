#!/usr/bin/env bash
# 构建 Net Probe APK：aapt2 -> javac -> d8 -> zipalign -> apksigner。
# 需要 JDK 17 和 Android SDK（build-tools、platforms）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
BT="${BUILD_TOOLS:-$(ls -d "$SDK"/build-tools/* 2>/dev/null | sort -V | tail -n1)}"
PLATFORM="${ANDROID_PLATFORM:-$(ls -d "$SDK"/platforms/android-* 2>/dev/null | sort -V | tail -n1)}"

if [ -z "$BT" ] || [ -z "$PLATFORM" ]; then
  echo "ERROR: 找不到 Android SDK build-tools 或 platforms" >&2
  echo "请设置 ANDROID_SDK_ROOT，例如：export ANDROID_SDK_ROOT=\$HOME/Android/Sdk" >&2
  exit 1
fi

AJ="$PLATFORM/android.jar"
TARGET_SDK="${TARGET_SDK:-$(basename "$PLATFORM" | sed 's/^android-//; s/\..*$//')}"
VERSION_CODE="${VERSION_CODE:-3}"
VERSION_NAME="${VERSION_NAME:-1.2}"

BUILD="$ROOT/.build/netprobe"
OUT="$ROOT/dist"
rm -rf "$BUILD"
mkdir -p "$BUILD/classes" "$BUILD/dex" "$OUT"

echo "SDK:      $SDK"
echo "build:    $BT"
echo "platform: $PLATFORM (targetSdk $TARGET_SDK)"

# 1. 编译 Java
find "$ROOT/netprobe/src" -name '*.java' -print0 \
  | xargs -0 javac -source 8 -target 8 -Xlint:-options \
      -bootclasspath "$AJ" \
      -d "$BUILD/classes"

# 2. dex
find "$BUILD/classes" -name '*.class' -print0 \
  | xargs -0 "$BT/d8" --lib "$AJ" --min-api 23 --output "$BUILD/dex"

# 3. 资源 + manifest
"$BT/aapt2" link \
  -o "$BUILD/netprobe-unsigned.apk" \
  -I "$AJ" \
  --manifest "$ROOT/netprobe/AndroidManifest.xml" \
  --min-sdk-version 23 \
  --target-sdk-version "$TARGET_SDK" \
  --version-code "$VERSION_CODE" \
  --version-name "$VERSION_NAME"

# 4. 放入 classes.dex 并对齐
(
  cd "$BUILD"
  zip -uj netprobe-unsigned.apk dex/classes.dex
)
"$BT/zipalign" -f 4 "$BUILD/netprobe-unsigned.apk" "$BUILD/netprobe-aligned.apk"

# 5. 签名：优先使用 KEYSTORE；否则生成一个本地 debug keystore
if [ -n "${KEYSTORE:-}" ]; then
  KS="$KEYSTORE"
  KS_PASS="${KEYSTORE_PASS:-android}"
  KEY_ALIAS="${KEY_ALIAS:-netprobe}"
  KEY_PASS="${KEY_PASS:-$KS_PASS}"
else
  KS="$BUILD/debug.keystore"
  KS_PASS=android
  KEY_ALIAS=netprobe
  KEY_PASS=android
  keytool -genkeypair \
    -keystore "$KS" \
    -alias "$KEY_ALIAS" \
    -storepass "$KS_PASS" \
    -keypass "$KEY_PASS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Net Probe,O=Tun Only,C=CN"
fi

"$BT/apksigner" sign \
  --ks "$KS" \
  --ks-pass "pass:$KS_PASS" \
  --ks-key-alias "$KEY_ALIAS" \
  --key-pass "pass:$KEY_PASS" \
  --out "$OUT/netprobe.apk" \
  "$BUILD/netprobe-aligned.apk"

"$BT/apksigner" verify --verbose "$OUT/netprobe.apk" | sed -n '1,12p'
echo "built: $OUT/netprobe.apk"
