"""Build a simple primitive prop GLB: spheres, cylinders, cones, boxes in
flat colours.

For a prop this simple (an eye, a hat, a headband, a cup) a generative
image-to-3D pipeline is the wrong tool -- it buys unpredictable topology
and a photoreal texture for a model that's supposed to read as a few flat
colour blobs, which is what every other material in these two GLBs
already is (see SOURCES.md on the panda's atlas, and the pug's plain
baseColorFactor materials). A parametric mesh is simpler, exact, and
matches the house style for free.

Coordinates are in the TARGET BONE's own frame, the same one
`fit_prop.py` reports and `Mascot3DProp`'s offsets are expressed in --
copy them straight from fit_prop.py's output, no conversion needed. Each
shape gets its own centre, size and colour, and pieces combine (a hat is a
cylinder crown plus a squashed sphere top, say).

    python make_prop.py out.glb \\
        --sphere   cx cy cz  rx ry rz        color \\
        --cylinder cx cy cz  radius height   color [axis] \\
        --cone     cx cy cz  radius height   color [axis] \\
        --box      cx cy cz  sx sy sz        color

`axis` (cylinder/cone only) is which local axis the shape's height runs
along -- x, y, or z (default z, matching trimesh's own convention before
recentring).

Example (the pug's two eyes):

    python make_prop.py ../../assets/mascot_3d/props/pug_eyes.glb \\
        --sphere -0.55 1.05 0.50  0.16 0.18 0.14  "#1a1410" \\
        --sphere  0.55 1.05 0.50  0.16 0.18 0.14  "#1a1410"
"""
import argparse
import os

import numpy as np
import trimesh


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _colour(mesh, color):
    r, g, b = hex_rgb(color)
    material = trimesh.visual.material.PBRMaterial(
        baseColorFactor=[r, g, b, 1.0], metallicFactor=0.0, roughnessFactor=0.6,
    )
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def _axis_align(mesh, axis):
    """trimesh's cylinder/cone are built along Z; rotate onto x or y."""
    if axis == "z":
        return mesh
    ang = np.pi / 2
    rot = trimesh.transformations.rotation_matrix(
        ang, [0, 1, 0] if axis == "x" else [1, 0, 0]
    )
    mesh.apply_transform(rot)
    return mesh


def make_sphere(center, radii, color, subdivisions=3):
    mesh = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    mesh.vertices *= np.array(radii)
    mesh.vertices += np.array(center)
    return _colour(mesh, color)


def make_cylinder(center, radius, height, color, axis="z", sections=24):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh = _axis_align(mesh, axis)
    mesh.vertices += np.array(center)
    return _colour(mesh, color)


def make_cone(center, radius, height, color, axis="z", sections=24):
    mesh = trimesh.creation.cone(radius=radius, height=height, sections=sections)
    # trimesh's cone has its base at z=0 and apex at z=height; recentre
    # like the cylinder so `center` means the shape's own middle.
    mesh.vertices[:, 2] -= height / 2
    mesh = _axis_align(mesh, axis)
    mesh.vertices += np.array(center)
    return _colour(mesh, color)


def make_box(center, size, color):
    mesh = trimesh.creation.box(extents=size)
    mesh.vertices += np.array(center)
    return _colour(mesh, color)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--sphere", nargs=7, action="append",
                    metavar=("cx", "cy", "cz", "rx", "ry", "rz", "color"), default=[])
    ap.add_argument("--cylinder", nargs="+", action="append",
                    metavar="cx cy cz radius height color [axis]", default=[])
    ap.add_argument("--cone", nargs="+", action="append",
                    metavar="cx cy cz radius height color [axis]", default=[])
    ap.add_argument("--box", nargs=7, action="append",
                    metavar=("cx", "cy", "cz", "sx", "sy", "sz", "color"), default=[])
    args = ap.parse_args()

    parts = []
    for cx, cy, cz, rx, ry, rz, color in args.sphere:
        parts.append(make_sphere(
            (float(cx), float(cy), float(cz)), (float(rx), float(ry), float(rz)), color))
    for vals in args.cylinder:
        cx, cy, cz, radius, height, color = vals[:6]
        axis = vals[6] if len(vals) > 6 else "z"
        parts.append(make_cylinder(
            (float(cx), float(cy), float(cz)), float(radius), float(height), color, axis))
    for vals in args.cone:
        cx, cy, cz, radius, height, color = vals[:6]
        axis = vals[6] if len(vals) > 6 else "z"
        parts.append(make_cone(
            (float(cx), float(cy), float(cz)), float(radius), float(height), color, axis))
    for cx, cy, cz, sx, sy, sz, color in args.box:
        parts.append(make_box(
            (float(cx), float(cy), float(cz)), (float(sx), float(sy), float(sz)), color))

    if not parts:
        raise SystemExit("no shapes given -- pass at least one --sphere/--cylinder/--cone/--box")

    scene = trimesh.Scene(parts)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    scene.export(args.out)
    total_verts = sum(len(p.vertices) for p in parts)
    print(f"wrote {args.out}  ({len(parts)} shape(s), {total_verts} verts)")
