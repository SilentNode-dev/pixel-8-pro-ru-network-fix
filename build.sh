#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${DIR}/Pixel_8_Pro_RU_5G_VoLTE_Fix.zip"

rm -f "${OUTPUT}"

cd "${DIR}"
zip -r9 "${OUTPUT}" \
  module.prop \
  customize.sh \
  post-fs-data.sh \
  service.sh \
  config.json \
  confpack \
  uecap \
  system

echo "Successfully built: ${OUTPUT}"
