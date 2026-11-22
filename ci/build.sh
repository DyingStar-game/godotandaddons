#!/bin/bash
# The whole DyingStar engine build: patched source, Linux then Windows x86_64 Mono (double precision) in the
# official build containers, then the release files. The same on the CI runner and on a workstation:
#
#   ci/build.sh <godot tag> <work dir>          e.g.  ci/build.sh 4.7.2-stable /tmp/godot-work
#
# Environment:
#   IMAGE_PREFIX   where the build containers are, before "godot-linux:<IMAGE_VERSION>"
#                  (default harbor.dyingstar-game.space/dyingstar/; "" for local images)
#   IMAGE_VERSION  build container version (default 4.7-f44: godotengine/build-containers, Fedora 44)
#   NUM_CORES      parallel jobs (default: nproc)
#   DOCKER         docker or podman (default docker)
#   STEPS          which steps, any of "fetch linux windows package" (default all)
#
# Output: <work dir>/release/ (see ci/package.sh).
set -euo pipefail

tag="${1:?godot tag, e.g. 4.7.2-stable}"
work="$(mkdir -p "${2:?work dir}" && cd "$2" && pwd)"
here="$(cd "$(dirname "$0")" && pwd)"

IMAGE_PREFIX="${IMAGE_PREFIX-harbor.dyingstar-game.space/dyingstar/}"
IMAGE_VERSION="${IMAGE_VERSION:-4.7-f44}"
NUM_CORES="${NUM_CORES:-$(nproc)}"
DOCKER="${DOCKER:-docker}"
STEPS="${STEPS:-fetch linux windows package}"

step() { [[ " ${STEPS} " == *" $1 "* ]]; }

# run_in <image> <script> <mounts...>: a build script of ci/ inside a build container.
run_in() {
  local image="$1" script="$2"
  shift 2
  local mounts=(-v "${work}/godot:/root/godot" -v "${work}/out:/root/out" -v "${here}:/root/ci:ro")
  for dep in "$@"; do
    mounts+=(-v "${work}/deps/${dep}:/root/${dep}:ro")
  done
  mkdir -p "${work}/out"
  "${DOCKER}" run --rm \
    --env BUILD_NAME=custom_build --env GODOT_VERSION_STATUS=stable --env NUM_CORES="${NUM_CORES}" \
    --env HOST_UID="$(id -u)" --env HOST_GID="$(id -g)" \
    "${mounts[@]}" -w /root "${IMAGE_PREFIX}${image}:${IMAGE_VERSION}" bash "/root/ci/${script}"
}

if step fetch; then
  "${here}/fetch_source.sh" "${tag}" "${work}"
fi
if step linux; then
  run_in godot-linux in_linux.sh accesskit
fi
if step windows; then
  run_in godot-windows in_windows.sh accesskit winrt angle mesa
fi
if step package; then
  "${here}/package.sh" "${tag}" "${work}"
fi
