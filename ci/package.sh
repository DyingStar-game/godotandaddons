#!/bin/bash
# The release files from <work dir>/out, named as Godot's official ones (what DyingStar's CI and Dockerfile
# download): the x86_64 subset of godot-build-scripts' build-release.sh, Mono only.
#
#   ci/package.sh <godot tag, e.g. 4.7.2-stable> <work dir>
#
# <work dir>/release/:
#   Godot_v<v>_mono_linux_x86_64.zip                      editor + GodotSharp/ (assemblies, Tools/nupkgs)
#   Godot_v<v>_mono_win64.zip                             editor, console wrapper + GodotSharp/
#   Godot_v<v>_mono_export_templates.tpz                  Linux and Windows x86_64 templates, version.txt
#   Godot_v<v>_mono_release_templates_debugsymbols.zip    the release templates' DWARF (crash dumps)
#   Godot_v<v>_mono_debug_templates_debugsymbols.zip      the debug templates' DWARF (diagnostic build)
#   SHA512-SUMS.txt
set -euo pipefail

tag="${1:?godot tag, e.g. 4.7.2-stable}"
work="$(cd "${2:?work dir}" && pwd)"
out="${work}/out"
rel="${work}/release"
base="Godot_v${tag}"
# 4.7.2-stable -> 4.7.2.stable: the editor installs the templates under <this>.mono.double.
templates_version="${tag/-/.}"

rm -rf "${rel}" "${work}/pack"
mkdir -p "${rel}" "${work}/pack"
cd "${work}/pack"

# Linux editor
name="${base}_mono_linux_x86_64"
mkdir -p "${name}"
cp "${out}/linux/tools-mono/godot.linuxbsd.editor.double.x86_64.mono" "${name}/${base}_mono_linux.x86_64"
cp -rp "${out}/linux/tools-mono/GodotSharp" "${name}/"
zip -q -9 -r "${rel}/${name}.zip" "${name}"

# Windows editor
name="${base}_mono_win64"
mkdir -p "${name}"
cp "${out}/windows/tools-mono/godot.windows.editor.double.x86_64.mono.exe" "${name}/${name}.exe"
cp "${out}/windows/tools-mono/godot.windows.editor.double.x86_64.mono.console.exe" "${name}/${name}_console.exe"
cp -rp "${out}/windows/tools-mono/GodotSharp" "${name}/"
zip -q -9 -r "${rel}/${name}.zip" "${name}"

# Export templates
mkdir -p templates
lt="${out}/linux/templates-mono/godot.linuxbsd"
wt="${out}/windows/templates-mono/godot.windows"
cp "${lt}.template_debug.double.x86_64.mono" templates/linux_debug.x86_64
cp "${lt}.template_release.double.x86_64.mono" templates/linux_release.x86_64
cp "${wt}.template_debug.double.x86_64.mono.exe" templates/windows_debug_x86_64.exe
cp "${wt}.template_debug.double.x86_64.mono.console.exe" templates/windows_debug_x86_64_console.exe
cp "${wt}.template_release.double.x86_64.mono.exe" templates/windows_release_x86_64.exe
cp "${wt}.template_release.double.x86_64.mono.console.exe" templates/windows_release_x86_64_console.exe
if [ -f "${work}/godot/thirdparty/icu4c/icudt_godot.dat" ]; then
  cp "${work}/godot/thirdparty/icu4c/icudt_godot.dat" templates/
fi
echo "${templates_version}.mono" > templates/version.txt
zip -q -9 -r -D "${rel}/${base}_mono_export_templates.tpz" templates/*

# Debug symbols of the release templates
sym="${base}_mono_release_templates_debugsymbols"
mkdir -p "${sym}"
cp "${lt}.template_release.double.x86_64.mono.debugsymbols" "${sym}/linux_release.x86_64.debugsymbols"
cp "${wt}.template_release.double.x86_64.mono.exe.debugsymbols" "${sym}/windows_release_x86_64.exe.debugsymbols"
if [ -f "${wt}.template_release.double.x86_64.mono.console.exe.debugsymbols" ]; then
  cp "${wt}.template_release.double.x86_64.mono.console.exe.debugsymbols" \
    "${sym}/windows_release_x86_64_console.exe.debugsymbols"
fi
zip -q -9 -r "${rel}/${sym}.zip" "${sym}"

# Debug symbols of the debug templates: DyingStar's diagnostic build (a debug export) ships the Windows one
# beside its exe, as DyingStar.exe.debugsymbols, for Godot's crash handler to print named frames in the log.
sym="${base}_mono_debug_templates_debugsymbols"
mkdir -p "${sym}"
cp "${lt}.template_debug.double.x86_64.mono.debugsymbols" "${sym}/linux_debug.x86_64.debugsymbols"
cp "${wt}.template_debug.double.x86_64.mono.exe.debugsymbols" "${sym}/windows_debug_x86_64.exe.debugsymbols"
if [ -f "${wt}.template_debug.double.x86_64.mono.console.exe.debugsymbols" ]; then
  cp "${wt}.template_debug.double.x86_64.mono.console.exe.debugsymbols" \
    "${sym}/windows_debug_x86_64_console.exe.debugsymbols"
fi
zip -q -9 -r "${rel}/${sym}.zip" "${sym}"

cd "${rel}"
sha512sum Godot_* > SHA512-SUMS.txt
rm -rf "${work}/pack"
ls -la "${rel}"
