#!/usr/bin/env bash
# Usage: custom/pack.sh
# Builds dist/ and writes the npm package tarball to artifacts/.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash custom/build-dist.sh
mkdir -p artifacts
npm pack --ignore-scripts --pack-destination artifacts

version="$(node -p "require('./package.json').version")"
tarball="artifacts/node-av-${version}.tgz"
[[ -f "$tarball" ]] || { echo "missing $tarball" >&2; exit 1; }

files="$(tar -tzf "$tarball")"
grep -q '^package/install/custom-binary.js$' <<< "$files" || { echo "tarball lacks install/custom-binary.js" >&2; exit 1; }
grep -q '^package/dist/index.js$' <<< "$files" || { echo "tarball lacks dist/index.js" >&2; exit 1; }
if grep -E '^package/(binary/|build/)|\.node$' <<< "$files"; then
  echo "tarball contains native files" >&2
  exit 1
fi
echo "packed $tarball"
