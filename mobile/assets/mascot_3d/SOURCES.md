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

`env/default_env_ibl.ktx` — thermion_flutter's own generic example IBL
(`examples/assets/default_env_ibl.ktx` in [nmfisher/thermion](https://github.com/nmfisher/thermion)),
not anything scene-specific. Direct lights alone leave any face they
don't hit fully black (no ambient term without an IBL loaded); this
supplies that. Its matching skybox wasn't taken along, since we render
our own solid app-themed background instead — see mascot_3d_stage.dart
and mascot_3d_companion.dart.
