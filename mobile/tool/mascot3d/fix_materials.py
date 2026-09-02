"""Mark the mascot GLBs' materials opaque.

Both models came out of an FBX -> GLB conversion in Blender carrying blend
settings the meshes don't actually use:

  panda.glb  alphaMode BLEND, doubleSided true
  pug.glb    alphaMode MASK,  doubleSided true, baseColorFactor alpha 0

Neither is transparent in its data -- the panda's atlas is alpha 255
everywhere and its COLOR_0 alpha is 1.0 everywhere. But BLEND puts the
mesh in Filament's transparent pass, which does not write depth and draws
triangles in submission order rather than by depth; with doubleSided on
top of that, back faces aren't culled either. The far side of the body
then draws over the near side and the character renders as torn planes
with correct colours -- the "shredded mesh" this fixes. (See the README:
this is also what the early "dark/see-through patches" report was, which
was misread as a lighting problem at the time.)

Idempotent: run it again and it reports nothing to do.

    python fix_materials.py [--check]

--check exits non-zero if anything still needs fixing, without writing --
suitable for guarding against a future re-export bringing this back.
"""
import json
import os
import struct
import sys

ASSETS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "mascot_3d",
)
TARGETS = ["panda.glb", "pug.glb"]


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, _ = struct.unpack("<4sII", data[:12])
    if magic != b"glTF":
        raise ValueError(f"{path} is not a GLB")
    offset, chunks = 12, []
    while offset < len(data):
        clen, ctype = struct.unpack("<I4s", data[offset:offset + 8])
        chunks.append((ctype, data[offset + 8:offset + 8 + clen]))
        offset += 8 + clen
    return version, chunks


def write_glb(path, version, chunks):
    body = b""
    for ctype, payload in chunks:
        # glTF requires each chunk to be 4-byte aligned: JSON pads with
        # spaces, BIN with zeros.
        pad = (-len(payload)) % 4
        payload += (b" " if ctype == b"JSON" else b"\x00") * pad
        body += struct.pack("<I4s", len(payload), ctype) + payload
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", version, 12 + len(body)) + body)


def fix(path, check_only):
    version, chunks = read_glb(path)
    gltf = json.loads(next(p for t, p in chunks if t == b"JSON"))
    changes = []

    for i, mat in enumerate(gltf.get("materials", [])):
        name = mat.get("name", f"#{i}")
        if mat.get("alphaMode", "OPAQUE") != "OPAQUE":
            changes.append(f"{name}: alphaMode {mat['alphaMode']} -> OPAQUE")
            # OPAQUE is glTF's default, so drop the key rather than set it.
            mat.pop("alphaMode", None)
        mat.pop("alphaCutoff", None)
        # doubleSided is deliberately left alone. It only made things worse
        # in combination with BLEND, where nothing was depth-sorted; once
        # the material is opaque, back faces simply lose the depth test.
        # Turning culling on would be a small win and a real risk: any
        # single-sided surface in these meshes would vanish from one side.
        factor = mat.get("pbrMetallicRoughness", {}).get("baseColorFactor")
        if factor is not None and len(factor) == 4 and factor[3] != 1:
            changes.append(f"{name}: baseColorFactor alpha {factor[3]} -> 1")
            factor[3] = 1

    if not changes:
        print(f"  {os.path.basename(path)}: already opaque")
        return []
    for c in changes:
        print(f"  {os.path.basename(path)}: {c}")
    if not check_only:
        payload = json.dumps(gltf, separators=(",", ":")).encode()
        write_glb(path, version, [(b"JSON", payload)]
                  + [(t, p) for t, p in chunks if t != b"JSON"])
    return changes


if __name__ == "__main__":
    check_only = "--check" in sys.argv
    pending = []
    for name in TARGETS:
        pending += fix(os.path.join(ASSETS, name), check_only)
    if check_only and pending:
        print(f"\n{len(pending)} material setting(s) still need fixing")
        sys.exit(1)
    print("\nOK" if not pending else f"\nfixed {len(pending)} material setting(s)")
