# godotandaddons

DyingStar's engine: Godot, double precision, Mono (C#), with our engine patches. It is built on DyingStar's CI
runner and published as releases that the game's CI and server image download (`GODOT_RELEASE` in DyingStar's
workflows and `.docker/Dockerfile`).

A release is named `<godot tag>-ds<N>`, e.g. `4.7.2-stable-ds1`. The files in it keep Godot's official names
(`Godot_v4.7.2-stable_mono_linux_x86_64.zip`...):

| File | Content |
|---|---|
| `Godot_v<v>_mono_linux_x86_64.zip` | Linux editor + `GodotSharp/` (assemblies, `Tools/nupkgs`) |
| `Godot_v<v>_mono_win64.zip` | Windows editor, console wrapper + `GodotSharp/` |
| `Godot_v<v>_mono_export_templates.tpz` | Linux and Windows x86_64 export templates |
| `Godot_v<v>_mono_release_templates_debugsymbols.zip` | DWARF of the release templates, to read players' crash dumps |

Only x86_64 Linux and Windows: what the game ships and its CI uses.

## Engine patches

`patches/*.patch` are applied in name order to the Godot tag before building. A patch that no longer applies stops
the build at once.

- `0001-xr-multiview-far-plane-large-worlds.patch`: in VR, the culling frustum of the two eyes put its far plane
  through the point nearest the world's origin. About 4e10 m from it, the frame was culled with an identity
  frustum, depending on where the head looked (buildings vanishing).
- `0002-billboards-large-worlds.patch`: BaseMaterial3D billboards (Label3D, Sprite3D, fixed size, particles) took
  their origin from two float translations that nearly cancel far from the origin. A billboard near the camera
  was drawn kilometres away. The patch keeps `MODELVIEW_MATRIX[3]`, which is exact with double precision.
- `0003-dynamic-bvh-exact-update.patch`: `DynamicBVH::update` skipped a move within a relative 1e-5. That is
  150 to 750 km at 85 million km from the star. The rendering tree kept instances where they had been, and the
  omni and spot lights, which find their shadow casters through it, drew empty shadows (DyingStar #512).
- `0004-nav-second-pass-polygon-budget.patch`: when a path target is unreachable, the navigation search runs a
  second pass towards the closest reachable polygon, but kept counting polygons from the first pass. A reachable
  area of more than half of `path_search_max_polygons` (4096) then ran out of budget, printed "It's not expect to
  not find the most reachable polygons" and returned a path that never left the begin polygon: an NPC asked for an
  unreachable goal stood still instead of walking to the closest point (2D and 3D).

To add one, write it against the tag with `git diff` in a clone of godotengine/godot. Put a comment in the code
saying why. Then publish a new release, with N + 1.

## Building

**On CI:** `.github/workflows/build.yml`, on the `dyingstar-runners` runner.
- Push a tag `<godot tag>-ds<N>`: it builds that Godot tag and publishes the release.
- Or run it by hand from the Actions tab, as a draft first.
- A pull request that changes `patches/`, `ci/` or the workflow builds Godot without publishing anything (only
  for this repository's branches: the runner never runs a fork's code).

**On a workstation** with docker or podman:

```
IMAGE_PREFIX="" ci/build.sh 4.7.2-stable /tmp/godot-work    # local images godot-linux / godot-windows
```

The build runs in Godot's official build containers (`godotengine/build-containers`, Fedora 44, the toolchains of
the official releases). Their images `godot-linux` and `godot-windows`, tag `4.7-f44`, are in Harbor under
`harbor.dyingstar-game.space/dyingstar/`.

| Script | Does |
|---|---|
| `ci/build.sh` | Runs the steps below (`STEPS` picks some) |
| `ci/fetch_source.sh` | Clones the Godot tag, applies the patches, downloads accesskit, WinRT, ANGLE and Mesa |
| `ci/in_linux.sh` | Linux editor, C# glue, GodotSharp, templates (in `godot-linux`) |
| `ci/in_windows.sh` | Windows editor, GodotSharp, templates (in `godot-windows`, MinGW) |
| `ci/package.sh` | The release files and `SHA512-SUMS.txt` |

Releases before 4.7.2 were built by hand with a fork of godotengine/godot-build-scripts.
