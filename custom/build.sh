#!/usr/bin/env bash
# Usage: custom/build.sh <win32-x64|linux-x64|linux-arm64>
# Builds node-av against the pinned shared FFmpeg and writes artifacts/node-av-v<version>-<target>.zip
set -euo pipefail

target="${1:?usage: custom/build.sh <win32-x64|linux-x64|linux-arm64>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=custom/ffmpeg.env
source custom/ffmpeg.env

FFMPEG_LIBS=(avcodec avformat avfilter avdevice avutil swscale swresample)

key="$(echo "$target" | tr 'a-z-' 'A-Z_')"
asset_var="FFMPEG_ASSET_$key"
hash_var="FFMPEG_SHA256_$key"
asset="${!asset_var:-}"
expected_hash="${!hash_var:-}"
[[ -n "$asset" && -n "$expected_hash" ]] || { echo "unknown target: $target" >&2; exit 1; }

version="$(node -p "require('./package.json').version")"
out="artifacts/node-av-v${version}-${target}.zip"

download_ffmpeg() {
  local archive="work/dl/$asset"
  mkdir -p work/dl
  if [[ ! -f "$archive" ]] || ! echo "$expected_hash  $archive" | sha256sum -c --status; then
    curl -fL --retry 3 -o "$archive" \
      "https://github.com/$FFMPEG_REPO/releases/download/$FFMPEG_RELEASE/$asset"
  fi
  echo "$expected_hash  $archive" | sha256sum -c
}

extract_ffmpeg() {
  local archive="work/dl/$asset"
  rm -rf work/ffmpeg
  mkdir -p work/ffmpeg
  case "$asset" in
    *.zip) unzip -q "$archive" -d work/ffmpeg ;;
    *.tar.xz) tar -xJf "$archive" -C work/ffmpeg ;;
    *) echo "unsupported archive: $asset" >&2; exit 1 ;;
  esac
  local dirs=(work/ffmpeg/*/)
  [[ ${#dirs[@]} -eq 1 ]] || { echo "expected one top-level folder in $asset" >&2; exit 1; }
  ffmpeg_dir="$(cd "${dirs[0]}" && pwd)"
}

build_binding() {
  cp binding-shared.gyp binding.gyp
  trap 'git checkout -- binding.gyp' EXIT
  npx node-gyp rebuild
  git checkout -- binding.gyp
  trap - EXIT
  [[ -f build/Release/node-av.node ]] || { echo "node-av.node was not built" >&2; exit 1; }
}

stage_windows() {
  local lib
  for lib in "${FFMPEG_LIBS[@]}"; do
    compgen -G "$ffmpeg_dir/bin/$lib-*.dll" > /dev/null || { echo "missing $lib DLL" >&2; exit 1; }
    cp "$ffmpeg_dir"/bin/"$lib"-*.dll work/stage/
  done
  cp "$ffmpeg_dir/bin/ffmpeg.exe" "$ffmpeg_dir/bin/ffprobe.exe" work/stage/
}

stage_linux() {
  local lib soname
  for lib in "${FFMPEG_LIBS[@]}"; do
    soname="$(readelf -d "$ffmpeg_dir/lib/lib$lib.so" | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')"
    [[ -n "$soname" ]] || { echo "no SONAME in lib$lib.so" >&2; exit 1; }
    cp -L "$ffmpeg_dir/lib/lib$lib.so" "work/stage/$soname"
  done
  cp "$ffmpeg_dir/bin/ffmpeg" "$ffmpeg_dir/bin/ffprobe" work/stage/
  patchelf --set-rpath '$ORIGIN' work/stage/ffmpeg work/stage/ffprobe
  chmod 755 work/stage/ffmpeg work/stage/ffprobe
}

make_zip() {
  local zip_out="$root/$out"
  mkdir -p artifacts
  rm -f "$zip_out"
  cd work/stage
  if command -v zip > /dev/null; then
    zip -q -r "$zip_out" .
  elif command -v 7z > /dev/null; then
    7z a -tzip -bd -bso0 "$zip_out" ./*
  else
    "$(cygpath -u "$SYSTEMROOT")/System32/tar.exe" -a -c -f "$(cygpath -m "$zip_out")" *
  fi
  cd "$root"
  [[ -s "$out" ]] || { echo "zip was not written" >&2; exit 1; }
}

download_ffmpeg
extract_ffmpeg
if [[ "$target" == win32-x64 ]]; then
  export FFMPEG_DIR="$(cygpath -m "$ffmpeg_dir")"
else
  export FFMPEG_DIR="$ffmpeg_dir"
fi
build_binding

rm -rf work/stage
mkdir -p work/stage
cp build/Release/node-av.node work/stage/
if [[ "$target" == win32-x64 ]]; then stage_windows; else stage_linux; fi
cp "$ffmpeg_dir/LICENSE.txt" work/stage/FFMPEG-LICENSE.txt
cp LICENSE.md work/stage/LICENSE.md

make_zip
echo "wrote $out"
