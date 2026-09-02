"""Render the panda wearing the glasses, using the exact transform chain
the app uses, so the prop's offset/scale can be checked before shipping.

App chain: prop vertices are placed by Mascot3DProp's offset+scale in the
target bone's local space, the bone's world matrix carries them onto the
posed head, and the model-wide normalization scales the lot.
"""
import json
import os
import struct

import numpy as np
from PIL import Image, ImageDraw

import preview as P

GLASSES = os.path.join(os.path.dirname(P.GLB), "props", "glasses.glb")
IDLE = 10


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


# --- the panda, posed ----------------------------------------------------
pv, pc, pt = P.skinned(IDLE, 0.5)
pose = P.sample(IDLE, 0.5)
world = P.globals_for(pose)
head = next(i for i, nd in enumerate(P.gltf["nodes"]) if nd.get("name") == "Head")
M = world[head]

# --- the glasses, placed the way Mascot3DProp places them ---------------
gv, gc, gt = load_prop(GLASSES)


def place(offset, scale):
    local = np.array(offset) + gv * scale
    return (M @ np.concatenate([local, np.ones((len(local), 1))], 1).T).T[:, :3]


CANDIDATES = [
    ("shipping now\noffset (0, 0.30, 0.15)  scale 0.70", (0, 0.30, 0.15), 0.70),
    ("measured fit\noffset (0, 0.53, 0.60)  scale 0.67", (0, 0.53, 0.60), 0.67),
]

W, H = 460, 420
panels = []
for label, off, sc in CANDIDATES:
    placed = place(off, sc)
    allv = np.vstack([pv, placed])
    allc = np.vstack([pc, gc])
    allt = np.vstack([pt, gt + len(pv)])
    n = P.normalize(allv)
    panels.append((label, P.render(n, allc, allt, (0.0, 0.23, 1.60), W, H)))

TOP, PAD = 52, 18
sheet = Image.new("RGB", (PAD + (W + PAD) * len(panels), H + TOP + PAD), (255, 255, 255))
dr = ImageDraw.Draw(sheet)
x = PAD
for label, im in panels:
    dr.multiline_text((x, 8), label, fill=(20, 20, 20), spacing=3)
    sheet.paste(im, (x, TOP))
    dr.rectangle([x - 1, TOP - 1, x + W, TOP + H], outline=(200, 200, 205))
    x += W + PAD
sheet.save("glasses-fit.png")
print("wrote glasses-fit.png")
