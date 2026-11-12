#!/usr/bin/env bash
# Build the Windows setup executable.
#
#   ./installer/build-installer.sh
#
# Requirements: a Rust toolchain, the vendored WinDivert files, and NSIS 3
# (makensis). Set NSIS_MAKENSIS to the compiler when it is not on PATH or in
# the default install location.
#
# Produces dist/Throttle-v<version>-windows-x64-setup.exe and its .sha256.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

NSIS="$(find_makensis)"
require_bom installer/Throttle.nsi

build_release
stage_payload
mkdir -p "$DIST"

out="$DIST/Throttle-v${VERSION}-windows-x64-setup.exe"
echo "==> compiling installer"
# MSYS would rewrite /V2 and /D... as POSIX paths, so turn that off for this
# one native command.
MSYS2_ARG_CONV_EXCL='*' "$NSIS" /V2 /NOCD \
  "/DVERSION=$VERSION" \
  "/DSOURCE_DIR=$(winpath "$STAGE")" \
  "/DOUT_FILE=$(winpath "$out")" \
  "/DICON_FILE=$(winpath "$ROOT/assets/throttle.ico")" \
  "$(winpath "$ROOT/installer/Throttle.nsi")"

write_sha256 "$out"

echo "==> done"
ls -lh "$out" "$out.sha256"
