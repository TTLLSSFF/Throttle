#!/usr/bin/env bash
# Build the Windows setup executable for Throttle.
#
#   ./installer/build-installer.sh
#
# Requirements: a Rust toolchain, the vendored WinDivert files, and NSIS 3
# (makensis). Set NSIS_MAKENSIS to the compiler when it is not on PATH or in
# the default install location.
#
# The script stages the runtime payload in dist/stage, then compiles
# installer/Throttle.nsi into dist/Throttle-v<version>-windows-x64-setup.exe and
# writes the matching .sha256 next to it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="${VERSION:-$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)}"
if [[ -z "$version" ]]; then
  echo "error: could not read the version from Cargo.toml" >&2
  exit 1
fi

nsis="${NSIS_MAKENSIS:-}"
if [[ -z "$nsis" ]]; then
  for candidate in \
    "/c/Program Files (x86)/NSIS/makensis.exe" \
    "/c/Program Files/NSIS/makensis.exe" \
    "$(command -v makensis 2>/dev/null || true)" \
    "$(command -v makensis.exe 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      nsis="$candidate"
      break
    fi
  done
fi
if [[ -z "$nsis" ]]; then
  echo "error: makensis not found; install NSIS 3 or set NSIS_MAKENSIS" >&2
  exit 1
fi

# NSIS decodes a BOM-less script as the system code page, which would garble
# the Chinese strings. Fail early instead of shipping mojibake.
if [[ "$(head -c 3 installer/Throttle.nsi | xxd -p)" != "efbbbf" ]]; then
  echo "error: installer/Throttle.nsi must be UTF-8 with a BOM" >&2
  exit 1
fi

# NSIS is a native Windows binary: it needs Windows paths (and it is not the
# MSYS shell's idea of a path when a drive letter is involved).
winpath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

echo "==> building throttle.exe (release, v$version)"
cargo build --release

stage="$root/dist/stage"
rm -rf "$stage"
mkdir -p "$stage"
cp target/release/throttle.exe "$stage/"
cp vendor/WinDivert-2.2.2-A/x64/WinDivert.dll "$stage/"
cp vendor/WinDivert-2.2.2-A/x64/WinDivert64.sys "$stage/"
cp LICENSE THIRD_PARTY_NOTICES.md "$stage/"

out="$root/dist/Throttle-v${version}-windows-x64-setup.exe"
echo "==> compiling installer"
# MSYS would rewrite /V2 and /D... as POSIX paths, so turn that off for this
# one native command.
MSYS2_ARG_CONV_EXCL='*' "$nsis" /V2 /NOCD \
  "/DVERSION=$version" \
  "/DSOURCE_DIR=$(winpath "$stage")" \
  "/DOUT_FILE=$(winpath "$out")" \
  "/DICON_FILE=$(winpath "$root/assets/throttle.ico")" \
  "$(winpath "$root/installer/Throttle.nsi")"

hash="$(sha256sum "$out" | cut -d' ' -f1)"
printf '%s  %s\n' "$hash" "$(basename "$out")" > "$out.sha256"

echo "==> done"
ls -lh "$out" "$out.sha256"
