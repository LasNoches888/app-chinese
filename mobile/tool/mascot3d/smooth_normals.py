"""Soften a model's shading by averaging its vertex normals.

pug.glb is 100% flat-shaded -- every one of its 241 (and 127) distinct
positions carries a different normal per adjoining face -- which is what
makes it read as sharp and faceted next to the panda, whose mesh is
already smooth across 82% of its positions.

Nothing about the geometry has to change to fix that. Averaging the
normals of the faces meeting at a position makes the shading continuous
across them, so the same triangles read as a rounded form. Edges meeting
at more than [--angle] degrees are left alone, so genuinely sharp
features (the muzzle against the skull, the base of an ear) stay sharp
instead of smearing.

Normals are written back over the existing accessor -- same count, same
layout -- so the file's structure is untouched.

    python smooth_normals.py [model.glb] [--angle 66] [--check]
"""
import json
import os
import struct
import sys

import numpy as np

ASSETS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "mascot_3d",
)

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    with open(path, "rb") as f:
        data = bytearray(f.read())
    off, chunks = 12, []
    while off < len(data):
        clen, ctype = struct.unpack("<I4s", data[off:off + 8])
        chunks.append([ctype, off + 8, clen])
        off += 8 + clen
    return data, chunks


def accessor_view(gltf, data, bin_off, idx):
    """(offset, stride, fmt, ncomp, count) for an accessor, into `data`."""
    a = gltf["accessors"][idx]
    fmt, size = COMP[a["componentType"]]
    n = NC[a["type"]]
    bv = gltf["bufferViews"][a["bufferView"]]
    start = bin_off + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride") or n * size
    return start, stride, fmt, n, a["count"], size


def read_acc(gltf, data, bin_off, idx):
    start, stride, fmt, n, count, size = accessor_view(gltf, data, bin_off, idx)
    out = np.empty((count, n), dtype=np.float64)
    for i in range(count):
        o = start + i * stride
        out[i] = struct.unpack("<" + fmt * n, data[o:o + n * size])
    return out


def write_acc(gltf, data, bin_off, idx, values):
    start, stride, fmt, n, count, size = accessor_view(gltf, data, bin_off, idx)
    assert values.shape == (count, n), "normals must keep their layout"
    for i in range(count):
        o = start + i * stride
        data[o:o + n * size] = struct.pack("<" + fmt * n, *values[i])


def smooth(path, angle_deg, check_only):
    data, chunks = read_glb(path)
    json_chunk = next(c for c in chunks if c[0] == b"JSON")
    bin_chunk = next(c for c in chunks if c[0] == b"BIN\x00")
    gltf = json.loads(bytes(data[json_chunk[1]:json_chunk[1] + json_chunk[2]]))
    bin_off = bin_chunk[1]
    cos_limit = np.cos(np.radians(angle_deg))
    changed = 0

    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            if "NORMAL" not in attrs or "POSITION" not in attrs:
                continue
            pos = read_acc(gltf, data, bin_off, attrs["POSITION"])
            nrm = read_acc(gltf, data, bin_off, attrs["NORMAL"])
            idx = read_acc(gltf, data, bin_off, prim["indices"])[:, 0].astype(int)
            tris = idx.reshape(-1, 3)

            tv = pos[tris]
            fn = np.cross(tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0])
            fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)

            # Vertices at the same position are the same surface point even
            # when duplicated for UVs, so group by position, not by index.
            keys = {}
            for i, p in enumerate(map(tuple, np.round(pos, 5))):
                keys.setdefault(p, []).append(i)

            faces_at = {}
            for t, tri in enumerate(tris):
                for v in tri:
                    faces_at.setdefault(v, []).append(t)

            out = nrm.copy()
            for group in keys.values():
                incident = sorted({t for v in group for t in faces_at.get(v, [])})
                if not incident:
                    continue
                for v in group:
                    own = [t for t in faces_at.get(v, [])]
                    if not own:
                        continue
                    ref = fn[own].sum(0)
                    ref /= max(np.linalg.norm(ref), 1e-12)
                    # Only fold in faces that aren't across a hard edge.
                    keep = [t for t in incident if float(np.dot(fn[t], ref)) >= cos_limit]
                    acc = fn[keep].sum(0)
                    norm = np.linalg.norm(acc)
                    if norm > 1e-9:
                        out[v] = acc / norm
            moved = int((np.abs(out - nrm) > 1e-4).any(1).sum())
            changed += moved
            print(f"  {os.path.basename(path)} {mesh.get('name')}: "
                  f"{moved} of {len(nrm)} normals softened")
            if not check_only:
                write_acc(gltf, data, bin_off, attrs["NORMAL"], out)

    if changed and not check_only:
        with open(path, "wb") as f:
            f.write(bytes(data))
    return changed


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    angle = 66.0
    if "--angle" in sys.argv:
        angle = float(sys.argv[sys.argv.index("--angle") + 1])
    check = "--check" in sys.argv
    target = args[0] if args else os.path.join(ASSETS, "pug.glb")
    n = smooth(target, angle, check)
    print(f"\n{'would soften' if check else 'softened'} {n} normals "
          f"(hard edges kept above {angle:.0f} degrees)")
