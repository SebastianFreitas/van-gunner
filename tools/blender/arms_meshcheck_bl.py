"""Blender side of `arms.py check`: mesh health counts of the six exported parts vs a baseline.

Read-only (never saves). `check [--bless]`: any bad count above arms_mesh.baseline.json, or a part
or UV map gone, fails; vertex and face counts changing is only printed. `--bless` rewrites it.
"""
import json
import os

import bmesh
import bpy
from mathutils.bvhtree import BVHTree

import arm_names as N
import bl_result

BASELINE = os.path.join(N.HERE, "arms_mesh.baseline.json")
BAD = ("nonmanifold_edges", "flipped_edges", "inside_out_faces", "zero_area_faces", "loose_verts",
       "no_weight_verts", "bad_sum_verts", "over4_verts")
MAX_HITS = 40


def _inside_out(bm: bmesh.types.BMesh) -> int:
    """Faces whose outward ray crosses the surface an odd number of times (normal points inward)."""
    tree = BVHTree.FromBMesh(bm)
    n = 0
    for f in bm.faces:
        if f.calc_area() < 1e-12:
            continue
        o, d, hits = f.calc_center_median(), f.normal, 0
        o = o + d * 1e-4
        while hits < MAX_HITS:
            loc, _nrm, _i, _dist = tree.ray_cast(o, d)
            if loc is None:
                break
            hits += 1
            o = loc + d * 1e-4
        n += hits % 2
    return n


def _count(ob) -> dict:
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    c = {"verts": len(bm.verts), "faces": len(bm.faces)}
    c["nonmanifold_edges"] = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
    flipped = 0
    for e in bm.edges:
        ls = e.link_loops
        if len(ls) == 2 and ls[0].vert == ls[1].vert:
            flipped += 1
    c["flipped_edges"] = flipped
    c["inside_out_faces"] = _inside_out(bm)
    c["zero_area_faces"] = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    c["loose_verts"] = sum(1 for v in bm.verts if not v.link_edges)
    bm.free()
    rig = bpy.data.objects[N.RIG]
    deform = {b.name for b in rig.data.bones if b.use_deform}
    idx = {g.index for g in ob.vertex_groups if g.name in deform}
    none = badsum = over = 0
    for v in ob.data.vertices:
        w = [g.weight for g in v.groups if g.group in idx and g.weight > 0.0]
        if not w:
            none += 1
            continue
        if abs(sum(w) - 1.0) > 0.01:
            badsum += 1
        if len(w) > 4:
            over += 1
    c["no_weight_verts"], c["bad_sum_verts"], c["over4_verts"] = none, badsum, over
    c["uv_maps"] = sorted(u.name for u in ob.data.uv_layers)
    return c


def _compare(now: dict, base: dict) -> tuple:
    errors, notes = [], []
    for part, b in base.items():
        c = now.get(part)
        if c is None:
            errors.append("%s: part missing" % part)
            continue
        for k in BAD:
            if c[k] > b[k]:
                errors.append("%s: %s %d -> %d" % (part, k, b[k], c[k]))
        for u in b["uv_maps"]:
            if u not in c["uv_maps"]:
                errors.append("%s: uv map %s missing" % (part, u))
        for k in ("verts", "faces"):
            if c[k] != b[k]:
                notes.append("%s: %s %d -> %d" % (part, k, b[k], c[k]))
    return errors, notes


def main() -> None:
    args = bl_result.args()
    bl_result.check_names()
    now = {p: _count(bpy.data.objects[p]) for p in N.PARTS}
    if "--bless" in args:
        with open(BASELINE, "w", encoding="utf-8") as f:
            json.dump(now, f, indent=1, sort_keys=True)
            f.write("\n")
        print("BLESSED", BASELINE)
        errors, notes = [], []
    else:
        with open(BASELINE, encoding="utf-8") as f:
            errors, notes = _compare(now, json.load(f))
    for p, c in now.items():
        print("MESH %s %s" % (p, " ".join("%s=%s" % (k, v) for k, v in c.items() if k != "uv_maps")))
    for n in notes:
        print("NOTE", n)
    bad = sum(c[k] for c in now.values() for k in BAD)
    bl_result.write("check", ok=not errors, errors=errors, parts=len(now), bad_total=bad,
                    notes=notes)


if __name__ == "__main__":
    main()
