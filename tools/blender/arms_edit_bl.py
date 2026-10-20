"""Hand edits for the arms glb, run inside Blender by arms_bl.py after every build.

These steps predate the baked source: they were written for the raw CC0 ArmL/ArmR (now in
the `archive_` collection), arms_bl.py no longer calls `apply`, and every step is off.
Builds used to start from the hidden `cc0` copies of the two meshes, so the numbers
below never compound. Steps run in table order; set a step's "on" to False to skip it.
"""
import re

import bpy
from mathutils import Vector, kdtree
from arm_names import VG_HAND, VG_PALM, VG_PALM1, VG_FOREARM, VG_THUMB1, VG_INDEX1, VG_MIDDLE1, VG_PINKY1, RIG

# One table of edit numbers per step (phase 4: wrist, seam, width).
EDITS: dict = {
    # D55: ArmL's wrist weights copied from ArmR's mirror partner (band is s along the hand axis).
    "wrist_mirror": {"on": False, "band": (-0.25, 1.0), "tol": 1e-4},
    # Relax the weights of the hand/palm/forearm-end set near the wrist seam.
    "seam_smooth": {"on": False, "radius": 0.06, "factor": 0.5, "repeats": 2},
    # Hand width (D59/D60): lateral offset scale per slab k=0..8 (s = k/8), linear between slabs.
    # Slims only the mid-hand bulge. Target T_k = W0 + (W7-W0)(1-(1-k/7)^1.5) on the no-edit R
    # W_k (.074 .081 .088 .093 .107 .115 .111 .107), k 0..7:
    # T .074 .0808 .0871 .0927 .0977 .102 .1052 .107; f_k = min(1, T_k/W_k), f8 = 1 (knuckles held).
    "width": {"on": False, "f": (1.0, 0.998, 0.99, 0.997, 0.913, 0.887, 0.948, 1.0, 1.0)},
}

_FOREARM_END = re.compile("^" + VG_FOREARM + r".*\.001$")


def _movable(name: str) -> bool:
    return name.startswith(VG_HAND) or name.startswith(VG_PALM) or bool(_FOREARM_END.match(name))


def _weights(ob) -> list:
    names = [g.name for g in ob.vertex_groups]
    return [{names[g.group]: g.weight for g in v.groups} for v in ob.data.vertices]


def _store(ob, i: int, w: dict) -> None:
    for g in ob.vertex_groups:
        try:
            g.remove([i])
        except RuntimeError:
            pass
    for name, val in w.items():
        if val <= 0.0:
            continue
        vg = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
        vg.add([i], val, "REPLACE")


def _top(w: dict) -> str:
    return max(w, key=w.get) if w else ""


def _frame(rig, side: str) -> dict:
    """Slab frame of one hand from the rig's rest bones (world space)."""
    rw = rig.matrix_world
    bones = rig.data.bones

    def head(b):
        return rw @ bones[b + "." + side].head_local
    h = head(VG_HAND)
    m = head(VG_MIDDLE1)
    length = (m - h).length
    axis = (m - h).normalized()
    lat = head(VG_INDEX1) - head(VG_PINKY1)
    lat = (lat - axis * lat.dot(axis)).normalized()
    up = Vector((0, 0, 1))
    dors = (up - axis * up.dot(axis)).normalized()
    return {"head": h, "axis": axis, "len": length, "lat": lat, "dorsal": dors}


def _s(fr: dict, p: Vector) -> float:
    return (p - fr["head"]).dot(fr["axis"]) / fr["len"]


def _world(ob) -> list:
    return [ob.matrix_world @ v.co for v in ob.data.vertices]


def _wrist_mirror(arm_l, arm_r, rig, cfg: dict) -> None:
    fl = _frame(rig, "L")
    pl, pr = _world(arm_l), _world(arm_r)
    wl, wr = _weights(arm_l), _weights(arm_r)
    kd = kdtree.KDTree(len(pr))
    for i, p in enumerate(pr):
        kd.insert(p, i)
    kd.balance()
    key = (VG_THUMB1, VG_PALM1)

    def has(w: dict, side: str) -> bool:
        return any(k + "." + side in w for k in key)
    lo, hi = cfg["band"]
    changed = unmatched = 0
    for i, p in enumerate(pl):
        if not lo <= _s(fl, p) <= hi:
            continue
        co, j, d = kd.find(Vector((-p.x, p.y, p.z)))
        if d > cfg["tol"]:
            if has(wl[i], "L"):
                unmatched += 1
            continue
        if not (has(wl[i], "L") or has(wr[j], "R")):
            continue
        new = {re.sub(r"\.R(?=\.|$)", ".L", k): v for k, v in wr[j].items()}
        _store(arm_l, i, new)
        changed += 1
    print("EDIT wrist_mirror changed", changed, "unmatched", unmatched)


def _limit_norm(w: dict, n: int = 4) -> dict:
    keep = sorted(w.items(), key=lambda kv: -kv[1])[:n]
    tot = sum(v for _, v in keep)
    return {k: v / tot for k, v in keep} if tot > 0 else dict(keep)


def _seam_smooth(ob, rig, side: str, cfg: dict) -> None:
    me = ob.data
    head = rig.matrix_world @ rig.data.bones[VG_HAND + "." + side].head_local
    fore = [b for b in rig.data.bones if b.name.startswith(VG_FOREARM) and b.name.endswith(".001")
            and ("." + side + ".") in b.name + "."]
    flen = fore[0].length
    print("EDIT forearm bone", fore[0].name, flen)
    w = _weights(ob)
    pw = _world(ob)
    nb = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].append(b)
        nb[b].append(a)
    sel = [i for i, x in enumerate(w)
           if _movable(_top(x)) and (pw[i] - head).length <= cfg["radius"] * flen]
    bones = {n for i in sel for n in w[i] if _movable(n)}
    for _ in range(cfg["repeats"]):
        new = {}
        for i in sel:
            if not nb[i]:
                continue
            cur = dict(w[i])
            for b in bones:
                avg = sum(w[j].get(b, 0.0) for j in nb[i]) / len(nb[i])
                cur[b] = w[i].get(b, 0.0) * (1 - cfg["factor"]) + avg * cfg["factor"]
            new[i] = cur
        for i, x in new.items():
            w[i] = x
    for i in sel:
        _store(ob, i, _limit_norm(w[i]))
    dd = sorted(((pw[i] - head).length, _top(w[i])) for i in range(len(w)))[:4]
    print("EDIT seam_smooth", ob.name, "verts", len(sel), "nearest", dd, "r", cfg["radius"] * flen)


def _width(ob, rig, side: str, cfg: dict) -> None:
    me = ob.data
    fr = _frame(rig, side)
    w = _weights(ob)
    f = cfg["f"]
    mw = ob.matrix_world
    inv = mw.inverted()
    moved = set()
    for i, v in enumerate(me.vertices):
        if not _movable(_top(w[i])):
            continue
        p = mw @ v.co
        s = _s(fr, p)
        if not 0.0 <= s <= 1.0:
            continue
        k = min(int(s * 8), 7)
        t = s * 8 - k
        fs = f[k] * (1 - t) + f[k + 1] * t
        l = (p - fr["head"]).dot(fr["lat"])
        v.co = inv @ (p + fr["lat"] * (l * (fs - 1.0)))
        moved.add(i)
    ring = set(moved)
    for e in me.edges:
        a, b = e.vertices
        if a in moved or b in moved:
            ring.update((a, b))
    custom = me.has_custom_normals
    if custom:
        old = [Vector(n.vector) for n in me.corner_normals]
    me.update()
    if custom:
        vn = [v.normal.copy() for v in me.vertices]
        out = [vn[lp.vertex_index] if lp.vertex_index in ring else old[li]
               for li, lp in enumerate(me.loops)]
        me.normals_split_custom_set(out)
    print("EDIT width", ob.name, "moved", len(moved), "ring", len(ring), "custom_normals", custom)


def apply(arm_l, arm_r):
    """Apply EDITS to the freshly rebuilt ArmL and ArmR objects."""
    rig = bpy.data.objects[RIG]
    cfg = EDITS["wrist_mirror"]
    if cfg["on"]:
        _wrist_mirror(arm_l, arm_r, rig, cfg)
    cfg = EDITS["seam_smooth"]
    if cfg["on"]:
        _seam_smooth(arm_l, rig, "L", cfg)
        _seam_smooth(arm_r, rig, "R", cfg)
    cfg = EDITS["width"]
    if cfg["on"]:
        _width(arm_l, rig, "L", cfg)
        _width(arm_r, rig, "R", cfg)
