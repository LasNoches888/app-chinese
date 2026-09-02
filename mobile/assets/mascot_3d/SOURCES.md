Both models are by [Quaternius](https://quaternius.com/), Public Domain (CC0 1.0) — attribution isn't required, kept here only for provenance.

- `panda.glb` — from ["Panda"](https://poly.pizza/m/q1uJ28Hs8T), Nov 2023, converted from the original FBX to GLB with Blender.
- `pug.glb` — from ["Pug"](https://poly.pizza/m/1gXKv15ik8) (part of the Farm Animal Pack), Aug 2021, converted from the original FBX to GLB with Blender.
- `props/glasses.glb` — from ["Glasses"](https://poly.pizza/m/j3xPyO1mvt) by iPoly3D, CC0 1.0, Aug 2022, converted the same way. Attached to the panda's `Head` bone as the first (pilot) test of real bone-attached 3D outfits — see MascotService.propForOutfit.

`panda.glb`'s 30 animation clips (Quaternius's Universal Animation Library)
are cleanly named in the GLB's own glTF `animations[]` array — read them
with a small script that parses the GLB's JSON chunk directly, not by
opening the file in Blender: Blender's glTF importer renames every action
to a generic `Chara.NNN` when the source name collides with the armature's
own name after truncation, which is exactly what happened here and is why
an earlier pass picked animation indices "by eye" against the wrong order.
The real order (index: name, duration):

10 Idle (1.03s) · 28 Wave (1.7s) · 14 No (1.7s) · 7 Duck (1.7s) ·
29 Yes (1.7s) · 20 Run (0.6s) · 27 Walk (1.03s) · 11 Jump (0.3s) ·
6 Death (0.8s) · 18 Punch (0.73s) · 25 Sword (0.9s) · 8 HitReact (0.63s) ·
23 (unnamed, 3.37s — the longest clip, used as the "correct answer" dance)

— see MascotService's `_idleAnimationIndex`/`_cueAnimationIndex`.

Both GLBs came out of the FBX conversion with transparency settings their
meshes don't use, and both had to be corrected — `tool/mascot3d/fix_materials.py`
does it, and `--check` guards against a re-export bringing it back. The
panda's material was `alphaMode: BLEND`; the pug's was `alphaMode: MASK`
with `baseColorFactor` alpha 0. Neither model is actually transparent: the
panda's atlas is alpha 255 everywhere and its `COLOR_0` alpha is 1.0
everywhere.

This matters far more than it sounds. `BLEND` puts the mesh in Filament's
transparent pass, which doesn't write depth and draws triangles in
submission order instead of by depth, and these materials are also
`doubleSided`, so back faces aren't culled either. The far side of the
body then draws over the near side and the character renders as torn
planes in the right colours. That is what the long-running "shredded
mesh" was, and — read back — what the first report in this whole thread,
"dark/see-through patches on the model", already was. It was misread as a
lighting problem at the time and chased through several rounds of camera,
lighting and viewer-lifetime changes before anyone checked the material.
The tell was that it looked equally wrong everywhere the model appeared:
a bug in a widget can't do that; a bug in the asset can.

`doubleSided` is deliberately left as it is. It only did damage alongside
`BLEND`, where nothing was depth-sorted; against an opaque material, back
faces just lose the depth test. Turning culling on would be a small win
and a real risk — any single-sided surface in these meshes would vanish
from one side.

The panda's texture is a single 512x512 atlas the GLB names `Sushi_Atlas`.
That name is a red herring: Quaternius ships one shared palette atlas per
pack, so it's named after the pack, not this character, and every mesh
just samples flat colours out of it. Don't conclude from the name that the
wrong texture got packed in — check the UVs instead. Sampling the atlas at
the panda's own UVs gives a white-and-black head (`#e9e9e9`/`#242424`) with
a navy `#403c57` body, a green `#84b717` sash and an orange `#ec8742`
headband. That's the character's design — Quaternius's panda is already
dressed in a kung-fu outfit — not a texture mix-up.

The two 3D widgets' `initialCameraPosition` values are derived, not
eyeballed. thermion never calls `setLensProjection` with an explicit lens,
so the camera keeps the default 28mm `kFocalLength` against Filament's
24mm sensor height: a fixed vertical FOV of 2*atan(12/28) = 46.4°, which
`ThermionViewerFFI.setViewport` preserves across resizes because it reads
`getFocalLength()` back before reprojecting. `ViewerWidget` always points
the camera at the origin (`camera.lookAt(position)` with a null focus,
which defaults to `Vector3.zero()`), and both widgets normalize the model
to 1 unit tall centred there, so the character fills
`1 / (2 * distance * tan(23.2°))` of the frame height. That's the number
the camera positions are tuned against — see the comments in
mascot_3d_stage.dart and mascot_3d_companion.dart.

`env/default_env_ibl.ktx` — thermion_flutter's own generic example IBL
(`examples/assets/default_env_ibl.ktx` in [nmfisher/thermion](https://github.com/nmfisher/thermion)),
not anything scene-specific. Direct lights alone leave any face they
don't hit fully black (no ambient term without an IBL loaded); this
supplies that. Its matching skybox wasn't taken along, since we render
our own solid app-themed background instead — see mascot_3d_stage.dart
and mascot_3d_companion.dart.
