"""Traces the owner's fist photo onto our hands' meshes and checks the four practical gates (no bpy).

`py -3 arms_veintrace.py <veindump dir>` prints per hand each path, the mesh edge beside the vein
width, the snapped stretches, the dropped points and the fails per gate (research 05). Needs numpy
like the research 04 mesh table. trace(side, mesh) returns the paths for arms_veinsplice."""
import importlib.util
import math
import os
import sys

import numpy as np

from arm_names import HERE
from arms_veingates import HEADS, SPAN  # noqa: E402
from arms_veintrace_gates import (VEIN_MAX, W_TO_R, _bad, _fails, _length, _ok_a, _ok_c,  # noqa: E402
                                  _pack, _push_b, _push_shared, _slide)
from arms_veinsplice import PALM, pack_of, read_old  # noqa: E402
import arms_veintrace_data as D  # noqa: E402
from arms_veintrace_smooth import _taper, smooth  # noqa: E402

MESH_TABLE = os.path.normpath(os.path.join(
    HERE, "..", "..", ".claude", "plans", "research", "hands-blender-review-04", "mesh_table.py"))
STEP = 0.06  # s between samples on the hand back
STEP_LOW = 0.16  # s between samples on the forearm (s < 0): long gentle ropes, coarse is invisible
_HL = sorted((h[1], h[0]) for h in HEADS.values())  # (lat, knuckle-row s) for K(lat)
_CTX = {}


def load_mesh(path: str):
    """The research 04 MeshTable over a veindump directory, imported by path."""
    spec = importlib.util.spec_from_file_location("mesh_table", MESH_TABLE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MeshTable(path)


class Ctx:
    """One hand's dumped tables, reshaped for the trace."""

    def __init__(self, mesh, side: str):
        t = mesh.d[side]
        ids = t["ids"]
        self.t, self.mesh, self.side = t, mesh, side
        self.S, self.L = t["s"][ids], t["lat"][ids]
        self.dorsal = t["tw"] < 0.5
        self.smin = float(self.S[self.dorsal].min())
        self.xy = t["dxy"]
        self.oxy = np.array(list(t["fingers"]) + list(t["webs"])) * [SPAN, 1.0]
        self.wt = np.maximum(t["fw"], t["tw"])
        e, axy = t["edges"], t["axy"]
        inids = np.zeros(len(axy), dtype=bool)
        inids[ids] = True
        e = e[inids[e[:, 0]] & inids[e[:, 1]]]
        a, b = axy[e[:, 0]], axy[e[:, 1]]
        ln = np.hypot(*(a - b).T)
        ok = ln <= 0.030  # the 180 mm edges are seam artefacts
        self.emid, self.elen = ((a + b) / 2)[ok], ln[ok]
        ds, dl = self.S[self.dorsal], self.L[self.dorsal]
        self.grid = np.round(np.arange(-1.95, 1.06, 0.01), 3)
        lohi = []
        for g in self.grid:
            m = np.abs(ds - g) < 0.03
            lohi.append((dl[m].min(), dl[m].max()) if m.any() else (np.nan, np.nan))
        lohi = np.array(lohi)
        ok = ~np.isnan(lohi[:, 0])
        lohi = np.stack([np.interp(self.grid, self.grid[ok], lohi[ok, i]) for i in (0, 1)], 1)
        # min/max per bin, then a running median over +-.2 s: the L skin is sparse and lopsided
        self.lohi = np.array([np.median(lohi[max(0, i - 20):i + 21], axis=0)
                              for i in range(len(self.grid))])
        self.wk = 2 * self.frame(0.95)[1]

    def frame(self, s: float) -> tuple:
        """(c, h): centre and half-width of the dorsal skin at s (smoothed min/max of lat)."""
        lo = float(np.interp(s, self.grid, self.lohi[:, 0]))
        hi = float(np.interp(s, self.grid, self.lohi[:, 1]))
        return (lo + hi) / 2, (hi - lo) / 2

    def place(self, s_n: float, n: float) -> tuple:
        """(s, lat) of the photo point (s_n, n) on our hand."""
        s = s_n
        if s_n >= 0:
            c, h = self.frame(s_n)
            s = s_n * float(np.interp(c - n * h, [p[0] for p in _HL], [p[1] for p in _HL]))
        c, h = self.frame(s)
        return s, c - n * h

    def snap_s(self, s: float, lat: float) -> float:
        """s_n of a hand point: s over the knuckle-row s of its lat."""
        return s / float(np.interp(lat, [p[0] for p in _HL], [p[1] for p in _HL])) if s > 0 else s


def ctx_of(mesh, side: str) -> Ctx:
    if (id(mesh), side) not in _CTX:
        _CTX[(id(mesh), side)] = Ctx(mesh, side)
    return _CTX[(id(mesh), side)]


def _ts(p1: list, p2: list, low: float) -> list:
    """Sample parameters of one segment: STEP, or low only on the part below s 0 (split there)."""
    n = max(1, math.ceil(_length(p1, p2) / STEP))
    if not low:
        return [k / n for k in range(n)]
    a, b = p1[0], p2[0]
    tc = (0.0 - a) / (b - a) if a != b else 2.0
    if not 0.0 < tc < 1.0:
        step = low if (a + b) / 2 < 0.0 else STEP
        n = max(1, math.ceil(_length(p1, p2) / step))
        return [k / n for k in range(n)]
    ts = []
    for lo, hi in ((0.0, tc), (tc, 1.0)):
        step = low if (lo + hi) / 2 * (b - a) + a < 0.0 else STEP
        m = max(1, math.ceil(_length(p1, p2) * (hi - lo) / step))
        ts += [lo + (hi - lo) * k / m for k in range(m)]
    return ts


def _spline(ctrl: list, low: float) -> list:
    """Catmull-Rom through the control points [s, lat, r, key], one sample per STEP."""
    out = []
    for i in range(len(ctrl) - 1):
        p1, p2 = ctrl[i], ctrl[i + 1]
        p0, p3 = ctrl[max(i - 1, 0)], ctrl[min(i + 2, len(ctrl) - 1)]
        ts = _ts(p1, p2, low)
        for k, t in enumerate(ts):
            q = [0.5 * (2 * p1[j] + (p2[j] - p0[j]) * t
                        + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                        + (3 * p1[j] - p0[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)]
            out.append([q[0], q[1], p1[2] + (p2[2] - p1[2]) * t, p1[3] if k == 0 else None])
    out.append(list(ctrl[-1]))
    return out


def _edge_bins(cx: Ctx, pts: list) -> dict:
    """bin (per 0.1 s) -> [mean skin edge m, mean w_vis m, point indices]."""
    acc = {}
    for i, p in enumerate(pts):
        q = np.array([p[0] * SPAN, p[1]])
        wv = p[2] * W_TO_R
        d = np.hypot(*(cx.emid - q).T)
        sel = np.nonzero(d <= wv)[0]
        if not len(sel):
            sel = np.argpartition(d, 3)[:3]
        b = acc.setdefault(math.floor(p[0] / 0.1 + 1e-9), [[], [], []])
        b[0].extend(cx.elen[sel])
        b[1].append(wv)
        b[2].append(i)
    return {k: [float(np.mean(v[0])), float(np.mean(v[1])), v[2]] for k, v in acc.items()}


def _snap_widen(cx: Ctx, name: str, pts: list, protected: set, notes: list,
                snap: bool = True) -> list:
    """D76: where the mean edge beats w_vis, note it and (snap) move points onto skin vertices;
    r is not widened (the per-pixel render does not need it, and it made branches fat)."""
    bins = _edge_bins(cx, pts)
    rows = [(name, k * 0.1, e, w) for k, (e, w, _) in sorted(bins.items())]
    hot = {k: v for k, v in bins.items() if v[0] > v[1]}
    hot_idx = {i: v[0] / W_TO_R for v in hot.values() for i in v[2]}
    keep, last = [], None
    for i, p in enumerate(pts):
        if snap and i in hot_idx and p[3] not in protected and 0 < i < len(pts) - 1:
            m = (np.abs(cx.S - p[0]) <= 0.05) & (np.abs(cx.L - p[1]) <= 0.1 * cx.frame(p[0])[1])
            if m.any():
                j = np.nonzero(m)[0][np.argmin(np.hypot(*(cx.xy[m] - [p[0] * SPAN, p[1]]).T))]
                if j == last:
                    continue
                last = j
                p[0], p[1] = float(cx.S[j]), float(cx.L[j])
        else:
            last = None
        keep.append(p)
    pts[:] = keep
    for k, v in sorted(hot.items()):
        notes.append((name, round(k * 0.1, 2), round(k * 0.1 + 0.1, 2), v[0] * 1000, v[1] * 1000))
    return rows


def trace(side: str, mesh, low: float = STEP_LOW, snap: bool = False) -> dict:
    """{"side", "paths": {name: {"pts": [(s, lat, r)], "free": (a, b)}}, "joins", "dropped",
    "snapped", "edges"} for one hand; low resamples the forearm below s 0 every low;
    snap=False skips the vertex snap and keeps the widening."""
    cx = ctx_of(mesh, side)
    dropped, snapped, edges, joins = [], [], {}, list(D.JOINS[side])
    count = {}
    for _, pts, _ in D.PATHS[side]:
        for p in pts:
            count[p[:2]] = count.get(p[:2], 0) + 1
    protected = {k for k, c in count.items() if c > 1}
    paths = {}
    for name, pts, free in D.PATHS[side]:
        ctrl = []
        for s_n, n, w in pts:
            s, lat = cx.place(s_n, n)
            if s < cx.smin + 0.05:
                dropped.append((name, s_n, n, s))
                continue
            ctrl.append([s, lat, w * cx.wk / W_TO_R, (s_n, n)])
        smp = _spline(ctrl, low)
        smooth(smp, protected)
        edges[name] = _snap_widen(cx, name, smp, protected, snapped, snap)
        smooth(smp, protected, 2, (2,))
        _taper(smp, free)  # after the widening, which would otherwise undo it
        paths[name] = {"pts": [(p[0], p[1], p[2]) for p in smp], "free": free}
    for br, end, trunk in D.JOINS[side]:  # a branch never outgrows its trunk where they meet
        j = paths[br]["pts"][end]
        cap = min(paths[trunk]["pts"], key=lambda p: math.hypot((p[0] - j[0]) * SPAN, p[1] - j[1]))[2]
        paths[br]["pts"] = [(p[0], p[1], min(p[2], cap)) for p in paths[br]["pts"]]
    rn, a, b, s_t, w = D.RUNGS[side]
    ends = [min(paths[x]["pts"], key=lambda p: abs(p[0] - s_t)) for x in (a, b)]
    r = w * cx.wk / W_TO_R
    mid = ((ends[0][0] + ends[1][0]) / 2, (ends[0][1] + ends[1][1]) / 2, r)
    paths[rn] = {"pts": [(ends[0][0], ends[0][1], r * 0.6), mid,
                         (ends[1][0], ends[1][1], r * 0.6)], "free": (0, 0)}
    joins += [(rn, 0, a), (rn, -1, b)]
    start_r = {n: pts[0][2] * cx.wk / W_TO_R for n, pts, _ in D.PATHS[side]}
    return {"side": side, "paths": paths, "joins": joins, "start_r": start_r, "dropped": dropped,
            "snapped": snapped, "edges": edges, "low": low}


def gates(res: dict, mesh) -> tuple:
    """Runs G-a..G-d, the fallback once per failing point, then again: (fails per gate, pack)."""
    cx = ctx_of(mesh, res["side"])
    dup = {}
    for q in res["paths"].values():
        for p in q["pts"]:
            dup[p[:2]] = dup.get(p[:2], 0) + 1
    for gate in ("a", "c", "b"):
        if gate == "b":
            _push_shared(cx, res, dup)
        for name, q in res["paths"].items():
            pts, tried = list(q["pts"]), set()
            while True:
                bad = [i for i, p in enumerate(pts) if p[:2] not in tried and dup.get(p[:2], 0) < 2
                       and _bad(cx, gate, pts, i, q["free"])]
                if not bad:
                    break
                i = bad[-1]
                tried.add(pts[i][:2])
                if gate == "b":
                    _push_b(cx, pts, i)
                else:
                    _slide(cx, pts, i, _ok_a if gate == "a" else _ok_c)
            q["pts"] = pts
    return _fails(cx, res), _pack(cx, res)


def run(side: str, mesh) -> tuple:
    """(result, fails, pack): trace at STEP on the hand back and STEP_LOW on the forearm, gates."""
    res = trace(side, mesh)
    fails, pk = gates(res, mesh)
    return res, fails, pk


def pack_split(res: dict, mesh) -> tuple:
    """(palm, hand back, forearm) slots; a path's own overhead goes to the hand back if it reaches s 0."""
    old, oflags, _ = read_old(res["side"])
    palm = pack_of([old[i] for i in PALM[res["side"]]], [oflags[i] for i in PALM[res["side"]]])
    back = fore = 0
    for q in res["paths"].values():
        pts = q["pts"]
        cost = pack_of([[mesh.chart(res["side"], p[:2]) + (p[2],) for p in pts]],
                       [q["free"][0] | (q["free"][1] << 1)])
        nb = sum(1 for p in pts if p[0] >= 0)
        extra = cost - len(pts)
        back += nb + (extra if nb else 0)
        fore += len(pts) - nb + (0 if nb else extra)
    return palm, back, fore


def report(res: dict, fails: dict, pk: int, split: tuple = ()) -> None:
    print("== %s: %d paths, %d points, pack %d%s" % (
        res["side"], len(res["paths"]), sum(len(q["pts"]) for q in res["paths"].values()), pk,
        " (forearm stride %.2f)" % res["low"] if res["low"] else ""))
    if split:
        print("-- pack split: palm %d + hand back %d + forearm %d = %d" % (*split, sum(split)))
    for name, q in res["paths"].items():
        pts = q["pts"]
        ln = sum(math.hypot((b[0] - a[0]) * SPAN, b[1] - a[1]) for a, b in zip(pts, pts[1:]))
        rs = [p[2] for p in pts]
        print("%s: %d pts free %s r %.5f..%.5f len %.0f mm s %.2f..%.2f"
              % (name, len(pts), q["free"], min(rs), max(rs), ln * 1000, pts[0][0], pts[-1][0]))
        print("   " + " ".join("(%.3f,%.4f,%.5f)" % p for p in pts))
    print("-- mean edge | w_vis in mm per 0.1 s")
    for name, rows in res["edges"].items():
        print("%s: " % name + " ".join("%.1f:%.1f|%.1f" % (s, e * 1000, w * 1000)
                                       for _, s, e, w in rows))
    print("-- snapped (path, s lo, s hi, edge mm, w_vis mm): %d" % len(res["snapped"]))
    for r in res["snapped"]:
        print("   %s %.2f..%.2f edge %.1f w_vis %.1f" % r)
    print("-- dropped: %d" % len(res["dropped"]))
    for r in res["dropped"]:
        print("   %s (s_n %.2f, n %.2f) s %.3f" % r)
    for g in "abcd":
        print("-- G-%s fails %d %s" % (g, len(fails[g]), fails[g][:20]))


def main(path: str) -> None:
    mesh = load_mesh(path)
    for side in "LR":
        res, fails, pk = run(side, mesh)
        report(res, fails, pk, pack_split(res, mesh))


if __name__ == "__main__":
    main(sys.argv[1])
