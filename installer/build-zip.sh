#!/usr/bin/env bash
# Build the portable zip: throttle.exe, the two WinDivert files, the license
# and the third-party notices, all at the archive root.
#
#   ./installer/build-zip.sh
#
# Produces dist/Throttle-v<version>-windows-x64.zip and its .sha256. The
# in-app updater looks for an asset ending in `-windows-x64.zip` plus the
# matching `.sha256`, so keep this name.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

build_release
stage_payload
mkdir -p "$DIST"

out="$DIST/Throttle-v${VERSION}-windows-x64.zip"
rm -f "$out"

echo "==> packing portable zip"
if command -v powershell.exe >/dev/null 2>&1; then
  ps_cmd="Compress-Archive -Path '$(winpath "$STAGE")\\*' -DestinationPath '$(winpath "$out")' -Force"
  MSYS2_ARG_CONV_EXCL='*' powershell.exe -NoProfile -NonInteractive -Command "$ps_cmd"
elif command -v zip >/dev/null 2>&1; then
  (cd "$STAGE" && zip -9 -q "$out" throttle.exe WinDivert.dll WinDivert64.sys LICENSE THIRD_PARTY_NOTICES.md)
else
  echo "error: neither powershell.exe nor zip is available to create the archive" >&2
  exit 1
fi

write_sha256 "$out"

echo "==> done"
ls -lh "$out" "$out.sha256"
