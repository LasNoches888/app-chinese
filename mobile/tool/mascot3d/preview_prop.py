"""Render a character wearing a bone-attached prop, using the exact
transform chain the app uses, so the fit can be checked before shipping.

App chain: prop vertices are placed by Mascot3DProp's offset+scale in the
target bone's local space, the bone's world matrix carries them onto the
posed model, and the model-wide normalization scales the lot. This mirrors
that chain exactly against $MASCOT_GLB (defaults to panda.glb).

    python preview_prop.py prop.glb bone offX offY offZ scale [out.png]

    python preview_prop.py props/glasses.glb Head 0 0.53 0.60 0.67
    MASCOT_GLB=../../assets/mascot_3d/pug.glb \\
        python preview_prop.py props/pug_eyes.glb Head 0 0 0 1 pug-eyes.png
"""
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

import preview as P


def load_prop(path):
    """Vertices/colours/triangles of a small unskinned glTF, node
    transforms applied."""
    with open(path, "rb") as f:
        data = f.read()
    off, chunks = 12, {}
    while off < len(data):
        clen, ctype = struct.unpack("<I4s", data[off:off + 8])
        chunks[ctype] = data[off + 8:off + 8 + clen]
        off += 8 + clen
    g = json.loads(chunks[b"JSON"])
    blob = chunks[b"BIN\x00"]

    saved = (P.gltf, P.blob)
    P.gltf, P.blob = g, blob
    try:
        pose = P.sample(None, 0.0)
        world = P.globals_for(pose)
        verts, cols, tris = [], [], []
        n = 0
        for ni, node in enumerate(g["nodes"]):
            if "mesh" not in node:
                continue
            for prim in g["meshes"][node["mesh"]]["primitives"]:
                p = P.acc(prim["attributes"]["POSITION"])
                base = n
                n += len(p)
                w = (world[ni] @ np.concatenate([p, np.ones((len(p), 1))], 1).T).T
                verts.append(w[:, :3])
                mat = g["materials"][prim["material"]] if "material" in prim else {}
                rgba = mat.get("pbrMetallicRoughness", {}).get(
                    "baseColorFactor", [0.1, 0.1, 0.12, 1])
                cols.append(np.tile(np.array(rgba[:3]), (len(p), 1)))
                idx = P.acc(prim["indices"])[:, 0].astype(int).reshape(-1, 3) + base
                tris.append(idx)
        return np.concatenate(verts), np.concatenate(cols), np.concatenate(tris)
    finally:
        P.gltf, P.blob = saved


def render_fitted(prop_path, bone_name, offset, scale, eye=(0.0, 0.23, 1.60),
                  size=(460, 420)):
    body_v, body_c, body_t = P.skinned(P.IDLE, 0.5)
    pose = P.sample(P.IDLE, 0.5)
    world = P.globals_for(pose)
    bone = next(i for i, nd in enumerate(P.gltf["nodes"]) if nd.get("name") == bone_name)
    M = world[bone]

    prop_v, prop_c, prop_t = load_prop(prop_path)
    local = np.array(offset) + prop_v * scale
    placed = (M @ np.concatenate([local, np.ones((len(local), 1))], 1).T).T[:, :3]

    all_v = np.vstack([body_v, placed])
    all_c = np.vstack([body_c, prop_c])
    all_t = np.vstack([body_t, prop_t + len(body_v)])
    n = P.normalize(all_v)
    return P.render(n, all_c, all_t, eye, *size)


if __name__ == "__main__":
    if len(sys.argv) < 7:
        print(__doc__)
        raise SystemExit(1)
    prop_path, bone = sys.argv[1], sys.argv[2]
    offset = tuple(float(x) for x in sys.argv[3:6])
    scale = float(sys.argv[6])
    out = sys.argv[7] if len(sys.argv) > 7 else "prop-fit.png"

    img = render_fitted(prop_path, bone, offset, scale)
    img.save(out)
    print(f"wrote {out}")
