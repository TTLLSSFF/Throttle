#!/usr/bin/env bash
# Shared helpers for the release artifact scripts.
#
# Source this file from a build script (see build-installer.sh); it defines
# ROOT, DIST, STAGE and VERSION and does not build anything on its own.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
STAGE="$DIST/stage"

VERSION="${VERSION:-$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)}"
if [[ -z "${VERSION:-}" ]]; then
  echo "error: could not read the version from Cargo.toml" >&2
  exit 1
fi

# NSIS is a native Windows binary: it needs Windows paths.
winpath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

find_makensis() {
  local candidate
  if [[ -n "${NSIS_MAKENSIS:-}" ]]; then
    if [[ -f "$NSIS_MAKENSIS" ]]; then
      printf '%s' "$NSIS_MAKENSIS"
      return 0
    fi
    echo "error: NSIS_MAKENSIS is set but not executable: $NSIS_MAKENSIS" >&2
    return 1
  fi
  for candidate in \
    "/c/Program Files (x86)/NSIS/makensis.exe" \
    "/c/Program Files/NSIS/makensis.exe" \
    "$(command -v makensis 2>/dev/null || true)" \
    "$(command -v makensis.exe 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  echo "error: makensis not found; install NSIS 3 or set NSIS_MAKENSIS" >&2
  return 1
}

# A BOM-less script is decoded with the system code page by NSIS, which turns
# the Chinese strings into mojibake. Refuse to compile such a script.
require_bom() {
  local file="$1" bom
  bom="$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')"
  if [[ "$bom" != "efbbbf" ]]; then
    echo "error: $file must be UTF-8 with a BOM" >&2
    return 1
  fi
}

build_release() {
  echo "==> building throttle.exe (release, v$VERSION)"
  cargo build --release
}

stage_payload() {
  echo "==> staging runtime payload in dist/stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp target/release/throttle.exe "$STAGE/"
  cp vendor/WinDivert-2.2.2-A/x64/WinDivert.dll "$STAGE/"
  cp vendor/WinDivert-2.2.2-A/x64/WinDivert64.sys "$STAGE/"
  cp LICENSE THIRD_PARTY_NOTICES.md "$STAGE/"
}

write_sha256() {
  local file="$1" hash
  hash="$(sha256sum "$file" | cut -d' ' -f1)"
  printf '%s  %s\n' "$hash" "$(basename "$file")" > "$file.sha256"
}
