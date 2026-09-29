#!/usr/bin/env bash
# Usage: custom/publish-release.sh <artifact dir>
# Creates the GitHub release v<version> from the built zips and npm tarball. Never replaces a release.
set -euo pipefail

artifact_dir="${1:?usage: custom/publish-release.sh <artifact dir>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=custom/ffmpeg.env
source custom/ffmpeg.env

version="$(node -p "require('./package.json').version")"
upstream_version="${version%-custom.*}"
tag="v$version"

if gh release view "$tag" > /dev/null 2>&1 || git ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null 2>&1; then
  echo "release or tag $tag already exists. Bump the version instead." >&2
  exit 1
fi

files=("node-av-$version.tgz")
for target in win32-x64 linux-x64 linux-arm64; do
  files+=("node-av-v$version-$target.zip")
done
cd "$artifact_dir"
for file in "${files[@]}"; do
  [[ -f "$file" ]] || { echo "missing $file in $artifact_dir" >&2; exit 1; }
done
sha256sum "${files[@]}" > SHA256SUMS

notes="$(mktemp)"
cat > "$notes" <<NOTES
node-av $upstream_version built against shared FFmpeg 8.1.

FFmpeg: release \`$FFMPEG_RELEASE\` of $FFMPEG_REPO
- win32-x64: $FFMPEG_ASSET_WIN32_X64
- linux-x64: $FFMPEG_ASSET_LINUX_X64
- linux-arm64: $FFMPEG_ASSET_LINUX_ARM64

NVENC:
- win32-x64 uses NVENC SDK 12.2 headers. Tested on driver 566.36.
- Linux uses NVENC SDK 13.0 headers and needs driver 570 or newer.

Linux needs a glibc based distribution. Alpine is not supported.

Install:

    npm install https://github.com/${GITHUB_REPOSITORY:-vghuy17ck1/node-av}/releases/download/$tag/node-av-$version.tgz
NOTES

gh release create "$tag" "${files[@]}" SHA256SUMS \
  --target "${GITHUB_SHA:-custom}" \
  --title "node-av $version" \
  --notes-file "$notes" \
  --latest
rm -f "$notes"
