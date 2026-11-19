#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${DIR}/Pixel_8_Pro_RU_5G_VoLTE_Fix.zip"

rm -f "${OUTPUT}"

# Recompile Applier.dex if JDK is available
if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ] && [ -f "${DIR}/src/Applier.java" ]; then
    echo "Compiling Applier.dex..."
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
    TMP_CLS=$(mktemp -d)
    TMP_DEX=$(mktemp -d)
    javac -cp ~/Library/Android/sdk/platforms/android-34/android.jar "${DIR}/src/Applier.java" -d "$TMP_CLS"
    ~/Library/Android/sdk/build-tools/36.1.0/d8 "$TMP_CLS/Applier.class" --output "$TMP_DEX" --min-api 33
    cp "$TMP_DEX/classes.dex" "${DIR}/system/bin/Applier.dex"
    rm -rf "$TMP_CLS" "$TMP_DEX"
fi

cd "${DIR}"
chmod 755 customize.sh post-fs-data.sh service.sh system/bin/netfix
chmod 644 system/bin/Applier.dex module.prop config.json

zip -r9 "${OUTPUT}" \
  module.prop \
  customize.sh \
  post-fs-data.sh \
  service.sh \
  config.json \
  carrier_config_template.xml \
  confpack \
  uecap \
  system \
  webroot

echo "Successfully built: ${OUTPUT}"
