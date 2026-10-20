"""Posed-crush and tip-shard smoothing of the `mass` step (plan hands-blender-review, D15).

Targets are the hunt's posed clusters read from crush_ids.txt (`part kind bone s ids=...`, ids
are the stored vertex ids). Each target is its vertices plus one ring: skin weights smoothed
(factor .5, 2 repeats, limit 4 groups, normalised); spike/hole targets also get positions
smoothed, with the 12 vertices nearest each claw seat and the knots0 vertices pinned. Targets
whose 0-based line number is in crush_strong.txt (one per line, optional) use factor 1.0 x 4.
"""
import os
import sys

import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import arms_hunt_bl as H  # noqa: E402
from arms_bl import _stored_ids  # noqa: E402

SCR = "C:/Users/Traff/AppData/Local/Temp/vg-hbr/"
IDS = SCR + "crush_ids.txt"
STRONG = SCR + "crush_strong.txt"
KNOTS = SCR + "knots0.txt"
TIP = ("DEF-f_index.03.", "DEF-f_middle.03.", "DEF-f_ring.03.", "DEF-f_pinky.03.", "DEF-thumb.03.")
PIN = 12


def knot_ids(part) -> list:
    """Vertex indices whose ring height passes the hunt's spike test right now."""
    bm = bmesh.new()
    bm.from_mesh(part.ob.data)
    bm.verts.ensure_lookup_table()
    out = []
    for v in bm.verts:
        info = H.ring_info(v)
        if info and info[0] > H.SPIKE_K * info[1]:
            out.append((v.index, v.co.copy(), info[0], info[1]))
    bm.free()
    return out


def write_knots(parts) -> dict:
    lines = []
    knots = {}
    for name in sorted(parts):
        ks = knot_ids(parts[name])
        knots[name] = [i for i, _, _, _ in ks]
        for i, c, h, e in ks:
            lines.append("%s %d (%.5f %.5f %.5f) h %.5f ratio %.2f" % (name, i, c.x, c.y, c.z, h, h / e))
    with open(KNOTS, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return knots


def adjacency(part):
    t = part.tri
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    e = np.concatenate([e, e[:, ::-1]])
    return e[:, 0], e[:, 1]


def smooth_set(part, sel, fac, reps, pins, wmat, co, adj) -> None:
    """Smooth rows `sel` of the weight matrix and, when pins is not None, positions."""
    a, b = adj
    n = len(co)
    cnt = np.maximum(np.bincount(a, minlength=n), 1)
    free = sel.copy()
    if pins is not None:
        free &= ~(np.bincount(part.gid, pins, minlength=n) > 0)[part.gid]
    cg = np.bincount(part.gid)
    for _ in range(reps):
        for arr in (wmat, co) if pins is not None else (wmat,):
            mean = np.stack([np.bincount(a, arr[b, k], n) for k in range(arr.shape[1])], 1) / cnt[:, None]
            sm = np.where(free[:, None] if arr is co else sel[:, None], (1 - fac) * arr + fac * mean, arr)
            d = sm - arr
            d = np.stack([np.bincount(part.gid, d[:, k]) / cg for k in range(d.shape[1])], 1)[part.gid]
            arr[:] = arr + d


def limit4(w):
    idx = np.argsort(-w, axis=1)[:, 4:]
    np.put_along_axis(w, idx, 0.0, axis=1)
    s = w.sum(axis=1)
    return np.where(s[:, None] > 0, w / np.maximum(s, 1e-12)[:, None], w)


def pins_for(part, fg, side):
    """The PIN skin vertices nearest each fingertip's claw seat (the finger tube's tip)."""
    pin = np.zeros(len(part.co), dtype=bool)
    for t in TIP:
        name = t + side
        w = fg.w.get(name, np.zeros(len(fg.co)))
        tube = np.where(w > .5)[0]
        if not len(tube):
            continue
        axis = fg.co[tube].mean(axis=0)
        far = tube[np.argsort(-np.linalg.norm(fg.co[tube] - axis, axis=1))[:PIN]]
        seat = fg.co[far].mean(axis=0)
        mine = np.where(part.w.get(name, np.zeros(len(part.co))) > .5)[0]
        if len(mine):
            pin[mine[np.argsort(np.linalg.norm(part.co[mine] - seat, axis=1))[:PIN]]] = True
    return pin


def apply_weights(part, names, w0, wm) -> int:
    ch = np.where(np.abs(wm - w0).max(axis=1) > 0)[0]
    vgs = [part.ob.vertex_groups[nm] for nm in names]
    for i in ch:
        for g, vg in enumerate(vgs):
            if wm[i, g] > 0:
                vg.add([int(i)], float(wm[i, g]), "REPLACE")
            elif w0[i, g] > 0:
                vg.remove([int(i)])
    for g, nm in enumerate(names):
        part.w[nm] = wm[:, g].copy()
    return len(ch)


def read_targets() -> list:
    out = []
    with open(IDS) as fh:
        for ln in fh:
            p = ln.split()
            if len(p) >= 5 and p[-1].startswith("ids="):
                out.append((p[0], p[1], [int(x) for x in p[-1][4:].split(",")]))
    return out


def crush(parts, lines) -> None:
    if not os.path.exists(IDS):
        print("CRUSH none")
        return
    knots = write_knots(parts)
    strong = set()
    if os.path.exists(STRONG):
        with open(STRONG) as fh:
            strong = {int(x) for x in fh.read().split()}
    targets = read_targets()
    for name in sorted({t[0] for t in targets}):
        part = parts[name]
        fg = parts[name[0] + "_fingers"]
        side = name[0]
        stored = _stored_ids(part.ob)
        by_id = {v: i for i, v in stored.items()}
        names = sorted(part.w)
        n = len(part.co)
        w0 = np.stack([part.w[k] for k in names], 1)
        wm = w0.copy()
        co0 = part.co.copy()
        co = co0.copy()
        adj = adjacency(part)
        tipmask = pins_for(part, fg, side)
        kmask = np.zeros(n, dtype=bool)
        kmask[knots[name]] = True
        for ti, (tn, kind, ids) in enumerate(targets):
            if tn != name:
                continue
            sel = np.zeros(n, dtype=bool)
            sel[[by_id[i] for i in ids if i in by_id]] = True
            sel[adj[1][sel[adj[0]]]] = True
            sel = (np.bincount(part.gid, sel, minlength=n) > 0)[part.gid]
            fac, reps = (1.0, 4) if ti in strong else (.5, 2)
            pins = None
            if kind in ("spike", "hole"):
                pins = tipmask | kmask
            smooth_set(part, sel, fac, reps, pins, wm, co, adj)
            wm[sel] = limit4(wm[sel])
        moved = int((np.linalg.norm(co - co0, axis=1) > 0).sum())
        nw = apply_weights(part, names, w0, wm)
        part.write(part.co + part.grouped(co - part.co))
        print("CRUSH %s weights=%d moved=%d" % (name, nw, moved))
