#!/bin/bash
# Godot's source at a tag, with our patches/ applied, and the prebuilt libraries the Windows and Linux builds link.
#
#   ci/fetch_source.sh <godot tag, e.g. 4.7.2-stable> <work dir>
#
# Leaves <work dir>/godot (the patched source) and <work dir>/deps/{accesskit,winrt,angle,mesa}. A patch that no
# longer applies stops here, before hours of build: rebase it on the new tag (git diff in a clone of the tag).
set -euo pipefail

tag="${1:?godot tag, e.g. 4.7.2-stable}"
work="${2:?work dir}"
here="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${work}"
cd "${work}"

rm -rf godot
git clone --quiet --depth 1 --branch "${tag}" https://github.com/godotengine/godot.git godot
for patch_file in "${here}"/patches/*.patch; do
  echo "Applying $(basename "${patch_file}")"
  git -C godot apply --check "${patch_file}"
  git -C godot apply "${patch_file}"
done

# The libraries of godotengine/godot-build-scripts build.sh, branch 4.7 (the official 4.7.x builds): keep them in
# step with it when moving to another Godot branch (4.7.2 does not build with accesskit 0.18).
mkdir -p deps
fetch() {  # fetch <dir> <url> [<url>...]: each zip unpacked in deps/<dir>, once
  local dir="deps/$1"
  shift
  [ -d "${dir}" ] && return 0
  mkdir -p "${dir}.tmp"
  for url in "$@"; do
    curl -sSfL -o "${dir}.tmp/dl.zip" "${url}"
    unzip -q -o "${dir}.tmp/dl.zip" -d "${dir}.tmp"
    rm -f "${dir}.tmp/dl.zip"
  done
  mv "${dir}.tmp" "${dir}"
}

fetch accesskit https://github.com/godotengine/godot-accesskit-c-static/releases/download/0.22.3/accesskit-c-0.22.3.zip
if [ ! -d deps/accesskit/accesskit-c ]; then
  mv deps/accesskit/accesskit-c-* deps/accesskit/accesskit-c
fi
fetch winrt https://github.com/godotengine/winrt-mingw/releases/download/72/winrt-headers.zip
fetch angle \
  "https://github.com/godotengine/godot-angle-static/releases/download/chromium%2F7578/godot-angle-static-x86_64-gcc-13-release.zip"
fetch mesa \
  "https://github.com/godotengine/godot-nir-static/releases/download/25.3.1-3/godot-nir-static-x86_64-gcc-release.zip"

echo "Source ready: ${work}/godot ($(git -C godot log --oneline -1))"
