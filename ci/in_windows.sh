#!/bin/bash
# Runs INSIDE the godot-windows build container (godotengine/build-containers, MinGW), from ci/build.sh, after
# in_linux.sh (whose C# glue it uses): the Windows x86_64 Mono editor and its GodotSharp assemblies, then the
# export templates (debug and release, each with separate debug symbols). Mounts: /root/godot, /root/accesskit,
# /root/winrt, /root/angle, /root/mesa, /root/out.
set -euo pipefail
trap 'chown -R "${HOST_UID:-0}:${HOST_GID:-0}" /root/godot /root/out' EXIT

SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no precision=double"
OPTIONS="production=yes use_mingw=yes angle_libs=/root/angle mesa_libs=/root/mesa d3d12=yes"
OPTIONS="${OPTIONS} accesskit_sdk_path=/root/accesskit/accesskit-c winrt_path=/root/winrt module_mono_enabled=yes"
SYMBOLS="debug_symbols=yes separate_debug_symbols=yes"
export TERM=xterm

cd /root/godot
if [ ! -d modules/mono/glue/GodotSharp/GodotSharp/Generated ]; then
  echo "No C# glue: run in_linux.sh first (it generates it)." >&2
  exit 1
fi
drop() { find . \( -name "*.windows.$1.*.o" -o -name "*.windows.$1.*.a" \) -delete; }

$SCONS platform=windows arch=x86_64 $OPTIONS target=editor
./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=windows --precision=double
mkdir -p /root/out/windows/tools-mono
cp -rp bin/* /root/out/windows/tools-mono/
rm -rf bin
drop editor

$SCONS platform=windows arch=x86_64 $OPTIONS $SYMBOLS target=template_debug
$SCONS platform=windows arch=x86_64 $OPTIONS $SYMBOLS target=template_release
mkdir -p /root/out/windows/templates-mono
cp -rp bin/* /root/out/windows/templates-mono/
rm -rf bin
drop template_debug
drop template_release
echo "Windows build done"
