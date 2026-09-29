#!/usr/bin/env bash
# Usage: custom/build-dist.sh
# Builds dist/ without the generator step, which needs the jellyfin-ffmpeg submodule.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
npx rimraf dist
npx tsc -p tsconfig.build.json
npx cpy --flat "src/api/data/*" dist/api/data --parents
[[ -f dist/index.js ]] || { echo "dist/index.js was not built" >&2; exit 1; }
