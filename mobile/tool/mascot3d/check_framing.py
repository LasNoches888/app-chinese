"""Does the framing ever clip the character?

Projects the mesh itself (not a rendered image) so the answer is exact:
  * stage  -- idle, swept through a full 360 deg of the auto-spin
  * lesson -- every clip the companion actually plays, against the CIRCULAR
              crop (ClipRRect radius = size/2), not just the square frame

Run this after changing a camera position, a model, or a cue clip:

    python check_framing.py

Keep the two eye positions below in sync with `_cameraPosition` in
lib/components/mascot_3d_stage.dart and mascot_3d_companion.dart -- this
check is only meaningful if it's checking what actually ships.
"""
import math
import os

import numpy as np

import preview as P
from preview import measured_bounds

TY = math.tan(math.atan(0.5 * P.SENSOR_MM / P.FOCAL_MM))

STAGE_EYE = (0.0, 0.23, 1.60)    # mascot_3d_stage.dart
LESSON_EYE = (0.80, 0.26, 1.71)  # mascot_3d_companion.dart


def ndc(v, eye, aspect):
    eye = np.array(eye, float)
    fwd = -eye / np.linalg.norm(eye)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    cam = (v - eye) @ np.array([right, up, -fwd]).T
    z = np.clip(-cam[:, 2], 1e-6, None)
    return np.stack([cam[:, 0] / (z * TY * aspect), cam[:, 1] / (z * TY)], 1)


def report(label, v, eye, aspect, circular):
    p = ndc(v, eye, aspect)
    x, y = p[:, 0], p[:, 1]
    out_rect = (np.abs(x) > 1) | (np.abs(y) > 1)
    msg = (f"    x {x.min():+.2f}..{x.max():+.2f}  y {y.min():+.2f}..{y.max():+.2f}"
           f"  margin {min(1-np.abs(x).max(), 1-np.abs(y).max()):+.2f}")
    bad = out_rect.sum()
    if circular:
        # square viewport clipped to its inscribed circle: |p| must stay <= 1
        r = np.hypot(x, y)
        bad = (r > 1.0).sum()
        msg += f"  r_max {r.max():.2f}"
    flag = "CLIPPED" if bad else "ok"
    print(f"  {label:22s} {flag:8s} {msg}" + (f"  ({bad} verts out)" if bad else ""))
    return bad


worst = 0

# The numbers MascotService normalizes by, against the ones actually in the
# GLB. Getting these wrong doesn't fail loudly — it just scales the model
# to the wrong size, and the camera ends up somewhere inside it.
print("BOUNDS  declared (MascotService) vs measured (GLB)")
_measured = measured_bounds()
for name, value, got in zip(("height", "centerY", "centerZ"),
                            (P.HEIGHT, P.CENTER_Y, P.CENTER_Z), _measured):
    off = abs(value - got)
    bad = off > max(0.02, abs(got) * 0.02)
    worst += 1 if bad else 0
    print(f"  {name:8s} declared {value:+.3f}  measured {got:+.3f}  "
          f"{'MISMATCH' if bad else 'ok'}")

IS_PANDA = os.path.basename(P.GLB) == "panda.glb"
if not IS_PANDA:
    # The clip indices below are the panda's; other models have their own.
    print("\n(skipping the spin/cue checks — they're keyed to panda.glb)")
    print("\nCLEAN" if worst == 0 else f"\n{worst} problem(s) found")
    raise SystemExit(1 if worst else 0)

print(f"\nSTAGE  eye={STAGE_EYE}  aspect=330/260  idle, swept through the spin")
for ang in range(0, 360, 30):
    v, _, _ = P.skinned(10, 0.5)
    n = P.normalize(v, spin_deg=ang)
    worst += report(f"spin {ang:3d}deg", n, STAGE_EYE, 330 / 260, False)

print(f"\nLESSON  eye={LESSON_EYE}  aspect=1  circular crop")
for label, idx, t in [("idle 10", 10, 0.5),
                      ("hello / Wave 28", 28, 0.85),
                      ("correct / Jump 11", 11, 0.10),
                      ("correct / Jump 11", 11, 0.20),
                      ("incorrect / No 14", 14, 0.85)]:
    v, _, _ = P.skinned(idx, t)
    worst += report(label, P.normalize(v), LESSON_EYE, 1.0, True)


def clip_duration(i):
    return max(P.acc(s["input"])[:, 0].max() for s in P.gltf["animations"][i]["samplers"])


def motion(i):
    """Peak distance a vertex travels over the clip, model normalized to 1
    unit tall. Idle sits at 0.06; anything near that won't read as a
    reaction however long it's held."""
    d = clip_duration(i)
    frames = np.stack([P.normalize(P.skinned(i, d * k / 5 * 0.999)[0]) for k in range(6)])
    return (frames.max(0) - frames.min(0)).max()


# MascotService._cueAnimationIndex / _cueDuration for the panda. A cue whose
# timer is shorter than its clip gets cut off mid-motion; one that's much
# longer leaves the model frozen on the last frame before idle resumes.
CUES = [("hello", 28, 1950), ("correct", 11, 550), ("incorrect", 14, 1950)]
IDLE_MOTION = motion(10)

print(f"\nCUES  (idle motion = {IDLE_MOTION:.3f} -- the floor a reaction must clear)")
for label, idx, ms in CUES:
    dur_ms = clip_duration(idx) * 1000
    name = P.gltf["animations"][idx]["name"].split("|")[-1]
    m = motion(idx)
    why = []
    if ms < dur_ms:
        why.append(f"timer {ms}ms cuts off a {dur_ms:.0f}ms clip")
    if m < IDLE_MOTION * 2:
        why.append(f"motion {m:.3f} barely above idle -- reads as standing still")
    worst += len(why)
    print(f"  {label:10s} {idx:2d} {name:10s} clip {dur_ms:6.0f}ms  timer {ms:5d}ms  "
          f"motion {m:.3f}  {'BAD: ' + '; '.join(why) if why else 'ok'}")

print("\nCLEAN" if worst == 0 else f"\n{worst} problem(s) found")
