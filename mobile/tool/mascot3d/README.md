# Mascot 3D preview tools

Renders the mascot the way the app does, on this machine, in seconds —
so camera, lighting, model and animation changes get checked *before* a
build instead of through the build → install → screenshot loop. That loop
is what made earlier passes at the 3D mascot expensive and, more than
once, wrong.

```bash
pip install numpy pillow          # the only dependencies
python preview.py                 # renders the current cameras
python check_framing.py           # exact clipping check, prints CLEAN or not
MASCOT_GLB=../../assets/mascot_3d/pug.glb python preview.py   # other model
```

## What it reproduces

Everything that decides what ends up on screen, taken from the same
sources the app uses:

- the GLB itself, skinned through the same glTF animation clip
- `MascotService.modelBounds` normalization (scale `1/height`, recentre)
- `ViewerWidget`'s camera: `lookAt(position)` with focus `(0,0,0)`, and
  Filament's default 28mm lens against a 24mm sensor — a fixed 46.4°
  vertical FOV that `setViewport` preserves across resizes

so the fraction of the frame the character fills is
`height / (2 * distance * tan(23.2°))`, which `fill_fraction()` reports
and the camera positions in the Dart are tuned against.

## What it does *not* reproduce

Shading is an approximation — a single key plus ambient, not Filament's
PBR with the real IBL. Use it to judge **framing, pose, silhouette and
motion**, not exact colour. For lighting balance the useful output is the
ratio, not the pixels: see `MascotService.iblIntensity`.

## Gotchas worth not rediscovering

- The panda's atlas is named `Sushi_Atlas`. That's the *pack* name, not a
  wrong texture — Quaternius ships one shared palette per pack. Check UVs
  before concluding anything from a texture name.
- Blender's glTF importer renames colliding actions to `Chara.NNN`, so
  animation indices read in Blender are not the file's. Parse the GLB's
  JSON chunk directly, as `preview.py` does.
- `ViewerWidget.transformToUnitCube` is a no-op in thermion 0.5.0: it's
  stored and compared, but `_configure()` never calls it. Both widgets
  normalize the model themselves.
- thermion distinguishes a glTF asset from its instances, and its own API
  is inconsistent about which one it wants: `addAnimationComponent()`
  silently redirects to `instances[0]`, while `playGltfAnimation()` and
  the bone getters use the receiver's handle as-is. Call them on what
  `loadGltf` returns and the animator is registered on one native object
  while "play" goes to another, so nothing drives the skeleton and the
  mesh renders as torn geometry with intact materials. Use
  `poseTarget()` (lib/components/mascot_3d_instance.dart) for anything
  touching animation, bones or the pose transform.
- Meshes are concatenated when rendering, so index buffers need offsetting
  by the running **vertex** count. (`panda.glb` has two meshes, `Headband`
  first at 200 verts — getting this wrong silently shreds the topology
  into stretched triangles rather than erroring.)
