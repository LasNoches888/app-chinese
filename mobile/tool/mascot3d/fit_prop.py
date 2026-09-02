"""Work out where a bone-attached prop actually has to sit.

Mascot3DProp's offsets are expressed in the target bone's own local space,
which is not the model's space and not guessable by eye -- the panda's Head
bone is rotated 22 degrees about X, so "up" and "forward" for the prop are
not up and forward for the character. The first pass at the glasses was a
hand-guessed offset and they ended up inside the skull.

This measures instead: it finds the vertices the bone actually drives,
expresses them in that bone's frame, and reports where the front of the
face is and how wide it is, so a prop can be placed and scaled against real
numbers.

    python fit_prop.py [bone] [prop.glb]

Defaults to the panda's Head bone and props/glasses.glb.
"""
import json
import os
import struct
import sys

import numpy as np

import preview as P

BONE = sys.argv[1] if len(sys.argv) > 1 else "Head"
PROP = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(P.GLB), "props", "glasses.glb")

IDLE = 10


def prop_bounds(path):
    with open(path, "rb") as f:
        data = f.read()
    off, chunks = 12, {}
    while off < len(data):
        clen, ctype = struct.unpack("<I4s", data[off:off + 8])
        chunks[ctype] = data[off + 8:off + 8 + clen]
        off += 8 + clen
    g = json.loads(chunks[b"JSON"])
    lo = np.full(3, np.inf)
    hi = np.full(3, -np.inf)
    for m in g["meshes"]:
        for p in m["primitives"]:
            a = g["accessors"][p["attributes"]["POSITION"]]
            lo = np.minimum(lo, a["min"])
            hi = np.maximum(hi, a["max"])
    return lo, hi


# --- where the bone is, and what it drives -------------------------------
pose = P.sample(IDLE, 0.5)
world = P.globals_for(pose)
nodes = P.gltf["nodes"]
bone_node = next(i for i, n in enumerate(nodes) if n.get("name") == BONE)
M = world[bone_node]
to_bone = np.linalg.inv(M)

skin = P.gltf["skins"][0]
joint_slot = skin["joints"].index(bone_node)

# Vertices this bone is the dominant influence for, posed, then expressed
# in the bone's own frame -- which is what a prop's transform is relative to.
pts = []
for ni, node in enumerate(nodes):
    if "mesh" not in node:
        continue
    for prim in P.gltf["meshes"][node["mesh"]]["primitives"]:
        a = prim["attributes"]
        posed, _, _ = P.skinned(IDLE, 0.5)
        break
    break
posed_all, _, _ = P.skinned(IDLE, 0.5)

# Recover per-vertex joint weights in the same concatenation order.
weights = []
for ni, node in enumerate(nodes):
    if "mesh" not in node:
        continue
    for prim in P.gltf["meshes"][node["mesh"]]["primitives"]:
        a = prim["attributes"]
        J = P.acc(a["JOINTS_0"]).astype(int)
        W = P.acc(a["WEIGHTS_0"])
        w = np.where(J == joint_slot, W, 0).sum(1)
        weights.append(w)
weights = np.concatenate(weights)

mask = weights > 0.5
sel = posed_all[mask]
local = (to_bone @ np.concatenate([sel, np.ones((len(sel), 1))], 1).T).T[:, :3]

print(f"bone {BONE!r}: {mask.sum()} vertices driven, world position "
      f"{np.round(M[:3, 3], 3)}")
print("\nthose vertices in the BONE'S OWN frame (what prop offsets mean):")
for ax, name in enumerate("XYZ"):
    print(f"  {name}  {local[:, ax].min():+.3f} .. {local[:, ax].max():+.3f}"
          f"   centre {local[:, ax].mean():+.3f}")

width = local[:, 0].max() - local[:, 0].min()
print(f"\nhead width across X: {width:.3f}")

lo, hi = prop_bounds(PROP)
print(f"\nprop {os.path.basename(PROP)} raw bounds:")
for ax, name in enumerate("XYZ"):
    print(f"  {name}  {lo[ax]:+.3f} .. {hi[ax]:+.3f}   size {hi[ax]-lo[ax]:.3f}")

# Fit: match the prop's width to the head's, then sit it on the face.
prop_w = hi[0] - lo[0]
scale = width / prop_w * 0.92          # a little inside the silhouette
centre = (lo + hi) / 2
print(f"\nsuggested scale {scale:.3f}  (prop width {prop_w:.3f} -> "
      f"{prop_w * scale:.3f} against a {width:.3f} head)")
print(f"prop centre offset to cancel: {np.round(-centre * scale, 3)}")
print("\nPick the face-front axis from the ranges above, then set offsets so"
      "\nthe prop lands just outside it at eye height.")
