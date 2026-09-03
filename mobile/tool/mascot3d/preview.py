"""Offline preview of the mascot exactly as the Flutter app frames it.

Mirrors mascot_3d_stage.dart / mascot_3d_companion.dart:
  * loads the same GLB and poses it with the same glTF animation clip
  * applies the same normalization (scale 1/height, recentre on Y and Z)
  * uses the same camera model thermion ends up with:
      - camera.lookAt(pos) with focus (0,0,0), up (0,1,0)
      - Filament setLensProjection(focalLength: 28mm) => vertical FOV
        2*atan(0.5 * 24mm / 28mm) = 46.4 deg, horizontal widened by aspect
so the framing it shows is the framing the device will show.
"""
import io
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image

_ASSETS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "mascot_3d",
)
GLB = os.environ.get("MASCOT_GLB", os.path.join(_ASSETS, "panda.glb"))
SENSOR_MM = 24.0          # Filament Camera.cpp: SENSOR_SIZE = 0.024 m
FOCAL_MM = 28.0           # thermion kFocalLength


# ---------------------------------------------------------------- glTF load
def load(path):
    with open(path, "rb") as f:
        data = f.read()
    off, chunks = 12, {}
    while off < len(data):
        clen, ctype = struct.unpack("<I4s", data[off:off + 8])
        chunks[ctype] = data[off + 8:off + 8 + clen]
        off += 8 + clen
    return json.loads(chunks[b"JSON"]), chunks[b"BIN\x00"]


gltf, blob = load(GLB)
COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def acc(i):
    a = gltf["accessors"][i]
    fmt, size = COMP[a["componentType"]]
    n = NC[a["type"]]
    bv = gltf["bufferViews"][a["bufferView"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride") or n * size
    raw = np.frombuffer(blob, dtype=np.dtype(fmt), count=a["count"] * (stride // size),
                        offset=start) if stride == n * size else None
    if raw is not None:
        return raw.reshape(a["count"], n).astype(np.float64)
    out = np.empty((a["count"], n))
    for k in range(a["count"]):
        o = start + k * stride
        out[k] = struct.unpack("<" + fmt * n, blob[o:o + n * size])
    return out


# ------------------------------------------------------------- node maths
def trs(t, r, s):
    """glTF quaternion is [x,y,z,w]."""
    x, y, z, w = r
    m = np.eye(4)
    m[:3, :3] = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]) @ np.diag(s)
    m[:3, 3] = t
    return m


def slerp(a, b, u):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        return a + u * (b - a)
    th = math.acos(max(-1.0, min(1.0, d)))
    return (math.sin((1 - u) * th) * a + math.sin(u * th) * b) / math.sin(th)


def sample(anim_idx, t):
    """Return {node: (T,R,S)} for the clip at time t, defaulting to bind pose."""
    nodes = gltf["nodes"]
    pose = {}
    for i, n in enumerate(nodes):
        pose[i] = [np.array(n.get("translation", [0, 0, 0]), float),
                   np.array(n.get("rotation", [0, 0, 0, 1]), float),
                   np.array(n.get("scale", [1, 1, 1]), float)]
    if anim_idx is None:
        return pose
    anim = gltf["animations"][anim_idx]
    for ch in anim["channels"]:
        node = ch["target"].get("node")
        if node is None:
            continue
        smp = anim["samplers"][ch["sampler"]]
        times = acc(smp["input"])[:, 0]
        vals = acc(smp["output"])
        tt = times[0] + (t % (times[-1] - times[0])) if times[-1] > times[0] else times[0]
        j = int(np.searchsorted(times, tt).clip(1, len(times) - 1))
        t0, t1 = times[j - 1], times[j]
        u = 0.0 if t1 == t0 else (tt - t0) / (t1 - t0)
        path = ch["target"]["path"]
        slot = {"translation": 0, "rotation": 1, "scale": 2}.get(path)
        if slot is None:
            continue
        pose[node][slot] = (slerp(vals[j - 1], vals[j], u) if slot == 1
                            else vals[j - 1] + u * (vals[j] - vals[j - 1]))
    return pose


def globals_for(pose):
    nodes = gltf["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    out = {}

    def walk(i):
        if i in out:
            return out[i]
        local = trs(*pose[i])
        out[i] = local if i not in parent else walk(parent[i]) @ local
        return out[i]

    for i in range(len(nodes)):
        walk(i)
    return out


# --------------------------------------------------------------- skinning
def skinned(anim_idx, t):
    pose = sample(anim_idx, t)
    g = globals_for(pose)
    verts, cols, tris = [], [], []
    nverts = 0  # running vertex count -- len(verts) counts arrays, not vertices
    # Not every model is textured: pug.glb has no image at all and colours
    # its primitives with plain baseColorFactor materials instead.
    images = gltf.get("images")
    if images:
        atlas_bv = gltf["bufferViews"][images[0]["bufferView"]]
        atlas = Image.open(io.BytesIO(blob[atlas_bv.get("byteOffset", 0):
                                           atlas_bv.get("byteOffset", 0) + atlas_bv["byteLength"]])).convert("RGB")
        px = np.asarray(atlas)
        ah, aw, _ = px.shape
    else:
        px = None

    for ni, node in enumerate(gltf["nodes"]):
        if "mesh" not in node:
            continue
        skin = gltf["skins"][node["skin"]] if "skin" in node else None
        joints = skin["joints"] if skin else []
        ibm = acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1) if skin else None
        # glTF stores matrices column-major; transpose to row-major.
        jm = np.stack([g[joints[k]] @ ibm[k] for k in range(len(joints))]) if skin else None
        inv_node = np.linalg.inv(g[ni])

        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            a = prim["attributes"]
            p = acc(a["POSITION"])
            base = nverts
            nverts += len(p)
            if skin:
                J = acc(a["JOINTS_0"]).astype(int)
                W = acc(a["WEIGHTS_0"])
                ph = np.concatenate([p, np.ones((len(p), 1))], 1)
                out = np.zeros((len(p), 4))
                for k in range(4):
                    m = jm[J[:, k]]                      # (n,4,4)
                    out += W[:, k, None] * np.einsum("nij,nj->ni", m, ph)
                world = (inv_node @ g[ni] @ out.T).T     # == out (node is identity)
            else:
                world = (g[ni] @ np.concatenate([p, np.ones((len(p), 1))], 1).T).T
            verts.append(world[:, :3])

            if px is not None:
                uv = acc(a["TEXCOORD_0"]) if "TEXCOORD_0" in a else np.zeros((len(p), 2))
                u = np.clip((uv[:, 0] * aw).astype(int), 0, aw - 1)
                v = np.clip((uv[:, 1] * ah).astype(int), 0, ah - 1)
                cols.append(px[v, u].astype(np.float64) / 255.0)
            else:
                mat = gltf["materials"][prim["material"]] if "material" in prim else {}
                rgba = mat.get("pbrMetallicRoughness", {}).get(
                    "baseColorFactor", [0.8, 0.8, 0.8, 1])
                cols.append(np.tile(np.array(rgba[:3]), (len(p), 1)))

            idx = acc(prim["indices"])[:, 0].astype(int).reshape(-1, 3) + base
            tris.append(idx)
    return np.concatenate(verts), np.concatenate(cols), np.concatenate(tris)


# ------------------------------------------------- app-side normalization
# What MascotService._modelBounds declares for each model. Keep in sync —
# measured_bounds() below re-derives them from the GLB, and
# check_framing.py fails if the two disagree, which is how the pug's were
# caught being short by a factor of 2.53 (camera ended up inside the dog).
DECLARED_BOUNDS = {
    "panda.glb": (3.334, 1.665, -0.204),
    "pug.glb": (2.659, 1.312, 0.282),
}
HEIGHT, CENTER_Y, CENTER_Z = DECLARED_BOUNDS.get(
    os.path.basename(GLB), DECLARED_BOUNDS["panda.glb"]
)

# MascotService._idleAnimationIndex, keyed the same way as DECLARED_BOUNDS —
# fit_prop.py and other tools that need to pose a model before measuring it
# read this rather than hardcoding the panda's index 10.
IDLE_ANIMATION_INDEX = {"panda.glb": 10, "pug.glb": 0}
IDLE = IDLE_ANIMATION_INDEX.get(os.path.basename(GLB), 0)

# MascotService.stageCameraDistance -- how far the podium's camera sits, per
# character. Sharing the panda's own 1.60 with the pug looked fine from a
# couple of angles but was never swept through a full turn: a pug is low
# and long nose-to-tail rather than roughly as wide as tall like the panda
# standing upright, so at the rotations where that length faces across the
# frame it clips the edge by as much as 9%. check_framing.py sweeps every
# model's own distance through a full turn now specifically because of that
# miss.
STAGE_CAMERA_DISTANCE = {"panda.glb": 1.60, "pug.glb": 2.0}
STAGE_EYE = (0.0, 0.23, STAGE_CAMERA_DISTANCE.get(os.path.basename(GLB), 1.60))


def measured_bounds(anim_idx=None, t=0.0):
    """Height and centre actually present in the GLB, for comparison with
    what the Dart declares."""
    v, _, _ = skinned(anim_idx, t)
    return (
        float(v[:, 1].max() - v[:, 1].min()),
        float((v[:, 1].max() + v[:, 1].min()) / 2),
        float((v[:, 2].max() + v[:, 2].min()) / 2),
    )


def normalize(v, spin_deg=0.0):
    s = 1.0 / HEIGHT
    v = v * s
    v = v + np.array([0.0, -s * CENTER_Y, -s * CENTER_Z])
    if spin_deg:
        a = math.radians(spin_deg)
        c, sn = math.cos(a), math.sin(a)
        R = np.array([[c, 0, sn], [0, 1, 0], [-sn, 0, c]])
        v = v @ R.T
    return v


# ------------------------------------------------------------- rasterizer
def render(v, cols, tris, eye, W, H, bg=(0.902, 0.898, 0.890)):
    eye = np.array(eye, float)
    fwd = -eye / np.linalg.norm(eye)                 # focus is the origin
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    view = np.array([right, up, -fwd])
    cam = (v - eye) @ view.T

    half_v = math.atan(0.5 * SENSOR_MM / FOCAL_MM)   # Filament lens projection
    ty = math.tan(half_v)
    aspect = W / H
    z = np.clip(-cam[:, 2], 1e-6, None)
    ndc = np.stack([cam[:, 0] / (z * ty * aspect), cam[:, 1] / (z * ty)], 1)
    sx = (ndc[:, 0] + 1) * 0.5 * W
    sy = (1 - ndc[:, 1]) * 0.5 * H

    # Flat-ish shading: a key light plus fill, matching the app's intent of
    # "lit from enough directions that nothing reads as unlit".
    n = np.zeros_like(v)
    tv = v[tris]
    fn = np.cross(tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-9)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    key = np.array([0.6, 1.0, 0.2]); key /= np.linalg.norm(key)
    lam = np.clip(n @ key, 0, 1)
    shade = (0.62 + 0.38 * lam)[:, None]
    vcol = np.clip(cols * shade, 0, 1)

    img = np.tile(np.array(bg), (H, W, 1))
    zbuf = np.full((H, W), np.inf)
    order = np.argsort(-z[tris].mean(1))
    for tri in tris[order]:
        x0, x1, x2 = sx[tri]; y0, y1, y2 = sy[tri]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        lo_x = max(int(math.floor(min(x0, x1, x2))), 0)
        hi_x = min(int(math.ceil(max(x0, x1, x2))), W - 1)
        lo_y = max(int(math.floor(min(y0, y1, y2))), 0)
        hi_y = min(int(math.ceil(max(y0, y1, y2))), H - 1)
        if lo_x > hi_x or lo_y > hi_y:
            continue
        xs = np.arange(lo_x, hi_x + 1)
        ys = np.arange(lo_y, hi_y + 1)
        px_, py_ = np.meshgrid(xs + 0.5, ys + 0.5)
        w0 = ((x1 - x0) * (py_ - y0) - (px_ - x0) * (y1 - y0)) / area
        w1 = ((px_ - x0) * (y2 - y0) - (x2 - x0) * (py_ - y0)) / area
        w2 = 1 - w0 - w1
        m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not m.any():
            continue
        zz = w2 * z[tri[0]] + w1 * z[tri[1]] + w0 * z[tri[2]]
        sub = zbuf[lo_y:hi_y + 1, lo_x:hi_x + 1]
        m &= zz < sub
        if not m.any():
            continue
        c = (w2[..., None] * vcol[tri[0]] + w1[..., None] * vcol[tri[1]]
             + w0[..., None] * vcol[tri[2]])
        sub[m] = zz[m]
        img[lo_y:hi_y + 1, lo_x:hi_x + 1][m] = c[m]
    return Image.fromarray((img * 255).astype(np.uint8))


def fill_fraction(v, eye):
    """Share of frame height the character occupies -- the number the camera
    is actually being tuned against."""
    eye = np.array(eye, float)
    d = np.linalg.norm(eye)
    visible_h = 2 * d * math.tan(math.atan(0.5 * SENSOR_MM / FOCAL_MM))
    return (v[:, 1].max() - v[:, 1].min()) / visible_h


if __name__ == "__main__":
    v0, cols, tris = skinned(IDLE, 0.5)
    v = normalize(v0)
    print(f"posed height {v[:,1].max()-v[:,1].min():.3f}  "
          f"Y {v[:,1].min():+.3f}..{v[:,1].max():+.3f}  "
          f"X {v[:,0].min():+.3f}..{v[:,0].max():+.3f}")
    for label, eye, W, H in [
        ("stage-now", (0.4, 1.15, 2.6), 330, 260),
        ("companion-now", (1.3, 1.3, 2.6), 232, 232),
    ]:
        d = np.linalg.norm(eye)
        elev = math.degrees(math.asin(eye[1] / d))
        print(f"{label:16s} d={d:.2f} elev={elev:.1f}deg fill={fill_fraction(v, eye)*100:.0f}%")
        render(v, cols, tris, eye, W, H).save(f"{label}.png")
