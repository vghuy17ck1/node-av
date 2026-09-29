#!/usr/bin/env bash
# Usage: custom/test.sh <win32-x64|linux-x64|linux-arm64>
# Extracts the built binary zip and checks that it loads and works.
set -euo pipefail

target="${1:?usage: custom/test.sh <win32-x64|linux-x64|linux-arm64>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="$(node -p "require('./package.json').version")"
zip_file="artifacts/node-av-v${version}-${target}.zip"
[[ -f "$zip_file" ]] || { echo "missing $zip_file" >&2; exit 1; }

check_linux_deps() {
  local allowed='^(libc\.so|libm\.so|libdl\.so|libpthread\.so|librt\.so|libmvec\.so|ld-linux|libgcc_s\.so|libstdc\+\+\.so|libav(codec|format|filter|device|util)\.so|libsw(scale|resample)\.so)'
  local file needed bad=0
  for file in "$test_dir"/*.so.* "$test_dir/node-av.node" "$test_dir/ffmpeg" "$test_dir/ffprobe"; do
    needed="$(readelf -d "$file" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p')"
    while read -r lib; do
      [[ -z "$lib" ]] && continue
      if ! [[ "$lib" =~ $allowed ]]; then
        echo "unexpected dependency of $(basename "$file"): $lib" >&2
        bad=1
      fi
    done <<< "$needed"
  done
  [[ "$bad" -eq 0 ]] || exit 1

  readelf -d "$test_dir/node-av.node" | grep -E 'RUNPATH|RPATH' | grep -q '\$ORIGIN' \
    || { echo "node-av.node has no \$ORIGIN RUNPATH" >&2; exit 1; }
  echo "highest GLIBC needed by node-av.node:   $(objdump -T "$test_dir/node-av.node" | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1)"
  echo "highest GLIBCXX needed by node-av.node: $(objdump -T "$test_dir/node-av.node" | grep -o 'GLIBCXX_[0-9.]*' | sort -V | tail -1 || true)"
}

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
unzip -q "$zip_file" -d "$test_dir"

[[ -f dist/index.js ]] || bash custom/build-dist.sh

ext=""
[[ "$target" == win32-x64 ]] && ext=".exe"
"$test_dir/ffmpeg$ext" -version | head -1
"$test_dir/ffprobe$ext" -version | head -1

if [[ "$target" != win32-x64 ]]; then
  check_linux_deps
fi

if [[ "$target" == win32-x64 ]]; then
  NODE_AV_BINARY="$(cygpath -m "$test_dir")/node-av.node" node custom/smoke-test.mjs
else
  NODE_AV_BINARY="$test_dir/node-av.node" node custom/smoke-test.mjs
fi
echo "tests passed for $target"
