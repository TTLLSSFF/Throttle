#!/usr/bin/env bash
# Build every release artifact: NSIS setup, portable zip and single-file
# portable launcher, each with a .sha256 checksum in dist/.
#
#   ./installer/build-all.sh
#
# Used by .github/workflows/release.yml. Individual entry points are
# build-installer.sh, build-zip.sh and build-portable.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/common.sh"
export VERSION

bash "$here/build-installer.sh"
bash "$here/build-zip.sh"
bash "$here/build-portable.sh"

echo "==> release artifacts for v$VERSION"
ls -lh "$DIST"/Throttle-v"$VERSION"-windows-x64-*
