#!/usr/bin/env bash
# Build the single-file portable launcher.
#
#   ./installer/build-portable.sh
#
# The launcher is an NSIS self-extracting executable: on first run it unpacks
# the app and the WinDivert files into
# %LOCALAPPDATA%\Throttle\portable\<version> and starts throttle.exe. Later
# runs reuse the extracted copy, so a running instance is never overwritten.
#
# Produces dist/Throttle-v<version>-windows-x64-portable.exe and its .sha256.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

NSIS="$(find_makensis)"
require_bom installer/ThrottlePortable.nsi

build_release
stage_payload
mkdir -p "$DIST"

out="$DIST/Throttle-v${VERSION}-windows-x64-portable.exe"
echo "==> compiling portable launcher"
MSYS2_ARG_CONV_EXCL='*' "$NSIS" /V2 \
  "/DVERSION=$VERSION" \
  "/DSOURCE_DIR=$(winpath "$STAGE")" \
  "/DOUT_FILE=$(winpath "$out")" \
  "/DICON_FILE=$(winpath "$ROOT/assets/throttle.ico")" \
  "$(winpath "$ROOT/installer/ThrottlePortable.nsi")"

write_sha256 "$out"

echo "==> done"
ls -lh "$out" "$out.sha256"
