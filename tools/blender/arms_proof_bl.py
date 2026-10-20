"""TEMPORARY (phase 6 deletes it): `arms.py proof <dir>`, a crude preview of plan phases 2-4.

Runs as `blender -b --factory-startup arms.blend --python arms_proof_bl.py -- <dir>`.
Copies the six live parts in memory into archive_ as `proof_<part>` (the look's left half),
dials the live parts (flank mass, four cords, zig-zag fingers, two left wrecks, knuckle heads
and knots; existing vertices only, coincident ones move by their mean) and renders the look
(right half). Never saves arms.blend, never exports. Writes <dir>/proof.txt.
Crude on purpose: no gates, fallbacks or Godot checks; the cords use a 3D falloff (r 0.006 m,
height 0.0028 m, q = d / 2.26 r) instead of the CUSTOM0 chart.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import arms_look_bl as look  # noqa: E402
from arms_frame_bl import hand_frame  # noqa: E402

PARTS = look.PARTS
FING = ("index", "middle", "ring", "pinky")
AMP = {"index": 1.0, "middle": 0.7, "ring": 0.85, "pinky": 1.15}
SIGN = {"index": 1, "middle": 1, "ring": 1, "pinky": -1}  # +1 toward the thumb (+lat)
KNUCK = {"index": 1.10, "middle": 1.08, "ring": 1.06, "pinky": 1.09}
G = {"index": (.04, .06), "middle": (.06, .03), "ring": (.03, .05), "pinky": (.05, .02)}


def sstep(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


class Part:
    def __init__(self, name):
        self.ob = bpy.data.objects[name]
        me = self.ob.data
        n = len(me.vertices)
        # local co is used as world: relies on identity matrix_world (checked for rig and all six parts)
        self.co = np.empty(n * 3, dtype=np.float64)
        me.vertices.foreach_get("co", self.co)
        self.co = self.co.reshape(n, 3)
        nr = np.empty(n * 3, dtype=np.float64)
        me.vertices.foreach_get("normal", nr)
        self.nrm = nr.reshape(n, 3)
        names = {g.index: g.name for g in self.ob.vertex_groups}
        self.w = {}
        for v in me.vertices:
            for g in v.groups:
                self.w.setdefault(names[g.group], np.zeros(n))[v.index] = g.weight
        key = np.round(self.co * 1e6).astype(np.int64)
        _, self.gid = np.unique(key, axis=0, return_inverse=True)
        self.gid = self.gid.reshape(-1)

    def wt(self, *names):
        out = np.zeros(len(self.co))
        for nm in names:
            out += self.w.get(nm, 0)
        return out

    def move(self, new):
        """Set positions to `new`, coincident vertices by their mean displacement."""
        d = new - self.co
        cnt = np.bincount(self.gid)
        m = np.stack([np.bincount(self.gid, d[:, k]) / cnt for k in range(3)], axis=1)
        self.co = self.co + m[self.gid]


def rot_toward(axis, ang, u, toward):
    m = Matrix.Rotation(ang, 3, axis)
    if (m @ u).dot(toward) < u.dot(toward):
        m = Matrix.Rotation(-ang, 3, axis)
    return np.array(m)


def turn(X, w, c, m):
    """Weight-blended rotation m about c of the rows of X."""
    return X + w[:, None] * ((X - c) @ m.T + c - X)


def mass(fr, parts, side, out):
    sk = parts[side + "_skin"]
    A, Lt, Dr = (np.array(v) for v in (fr.axis, fr.lat, fr.dors))
    d = sk.co - np.array(fr.H)
    # lat from the middle .01 head, as the plan's root lines (pinky -.092, index +.053)
    s, lat = d @ A / fr.span, d @ Lt - (fr.head("DEF-f_middle.01") - fr.H).dot(fr.lat)
    tw = sk.wt(*["DEF-thumb.0%d.%s" % (i, side) for i in (1, 2, 3)])
    fw = sk.wt(*["DEF-f_%s.0%d.%s" % (f, i, side) for f in FING for i in (1, 2, 3)])
    base = (tw < 0.2) & (s >= 0) & (s < 9 / 8) & (abs(lat) < 0.2)
    ks = np.minimum((s * 8).astype(int), 8)
    new = sk.co.copy()
    for sg, lside, name in ((-1, .0918, "pinky"), (1, .0526, "index")):
        W = np.array([np.percentile(sg * lat[base & (ks == k) & (sg * lat > 0)], 95)
                      for k in range(9)])
        lk = lside * sstep(.5, .875, np.arange(9) / 8)
        T = W.copy()
        if sg < 0:
            T[:8] = W[0] + (.123 - W[0]) * (1 - (1 - np.arange(8) / 7) ** 1.5)
            T[8] = T[7]
        else:
            T[8] = .088
        # crude: my W reads below the plan's near the root lines, so cap f at 1.4
        f = np.clip(1 + (T - W) / np.maximum(W - lk, 0.03), 1.0, 1.4)
        xs, fs = [1 / 16, 1 / 8, 3 / 16], [1, f[1], f[1]]
        for k in range(2, 8):
            xs.append((2 * k + 1) / 16)
            fs.append(f[k])
        xs += [1, 17 / 16, 19 / 16]
        fs += [f[8] if sg > 0 else f[7]] * 2 + [1]
        fv = np.interp(s, xs, fs)
        lv = lside * sstep(.5, .875, s)
        m = (sg * lat > lv) & (fw < 0.5) & (s >= 0)
        na = sg * lat + (fv - 1) * (sg * lat - lv)
        new[m] += ((na - sg * lat)[m] * (1 - tw[m]) * sg)[:, None] * Lt
        out.append("%s side W_k %s" % (name, np.round(W, 4).tolist()))
        out.append("%s side T_k %s" % (name, np.round(T, 4).tolist()))
        out.append("%s side f_k %s" % (name, np.round(f, 3).tolist()))
    sk.move(new)


def cords(fr, parts, side, out):
    sk = parts[side + "_skin"]
    A, Lt, Dr = (np.array(v) for v in (fr.axis, fr.lat, fr.dors))
    d = sk.co - np.array(fr.H)
    x, y = d @ A, d @ Lt
    tw = sk.wt(*["DEF-thumb.0%d.%s" % (i, side) for i in (1, 2, 3)])
    fw = sk.wt(*["DEF-f_%s.0%d.%s" % (f, i, side) for f in FING for i in (1, 2, 3)])
    ok = (sk.nrm @ Dr > 0.3) & (fw < 0.5) & (tw < 0.5)
    segs = []
    for f in FING:
        hd = np.array(fr.head("DEF-f_%s.01" % f) - fr.H)
        segs.append(((0.15 * hd) @ A, (0.15 * hd) @ Lt, hd @ A, hd @ Lt))
    best = np.zeros(len(x))
    for i, (xa, ya, xb, yb) in enumerate(segs):
        t = np.clip((x - xa) / (xb - xa), 0, 1)
        lats = np.array([sg[1] + t * (sg[3] - sg[1]) for sg in segs])
        tt = np.clip(np.maximum(t, 0.5), 0, 1)
        lat_h = np.array([sg[1] + tt * (sg[3] - sg[1]) for sg in segs])
        gap = np.where(np.arange(4)[:, None] == i, 9, abs(lat_h - lat_h[i]))
        r = np.minimum(0.006, gap.min(axis=0) / 4.52)
        q = abs(y - lats[i]) / (2.26 * r)
        h = np.where((q < 1) & (x >= xa) & (x <= xb), (1 - q * q) ** 2, 0.0)
        best = np.maximum(best, h)
    best = np.where(ok, best, 0.0)
    sk.move(sk.co + (0.0028 * best)[:, None] * sk.nrm)
    out.append("cords: 3D falloff r 0.006, height 0.0028 m, %d vertices lifted" % (best > 0).sum())


def fingers(fr, parts, side, out):
    rig = bpy.data.objects["rig"]
    A, Lt, Dr = fr.axis, fr.lat, fr.dors
    for f in FING:
        nm = ["DEF-f_%s.0%d.%s" % (f, i, side) for i in (1, 2, 3)]
        P = [fr.head(n[:-2]) for n in nm]
        E = rig.matrix_world @ rig.data.bones[nm[2]].tail_local
        u = (E - P[0]).normalized()
        a2, a3, aE = ((p - P[0]).dot(u) for p in (P[1], P[2], E))
        npP = [np.array(p) for p in P]
        # shaft: median distance of the finger tube's .01 vertices to the .01 axis
        fp = parts[side + "_fingers"]
        m1 = fp.wt(nm[0]) > 0.5
        rel = fp.co[m1] - npP[0]
        along = rel @ np.array(u)
        shaft = float(np.median(np.linalg.norm(rel - along[:, None] * np.array(u), axis=1)))
        Rk = 1.2 * shaft
        g2, g3 = G[f]
        dirv = Lt * SIGN[f]
        kb = 3 if f == "middle" else 2
        wreck = side == "L" and f in ("index", "ring")
        ang = np.radians(15 * AMP[f])
        for pn in PARTS:
            if not pn.startswith(side):
                continue
            pt = parts[pn]
            X = pt.co.copy()
            w = [pt.wt(n) for n in nm]
            wf = w[0] + w[1] + w[2]
            # knuckle head (K, R = 1.2 shaft)
            rel = X - npP[0]
            dist = np.linalg.norm(rel, axis=1)
            wk = np.where(dist <= 0.6 * Rk, 1.0, 1 - sstep(0.6 * Rk, Rk, dist))
            wk = np.where(dist < Rk, wk, 0) * sstep(0, 0.3 * Rk, rel @ np.array(Dr))
            X = npP[0] + rel * (1 + (KNUCK[f] - 1) * wk)[:, None]
            # knots at .02 and .03 (ring radius x (1 + g a d s))
            joints = ((a2, g2, -1 if kb == 2 else 0), (a3, g3, 1 if kb == 2 else -1))
            relk = X - npP[0]
            ax = relk @ np.array(u)
            rv = relk - ax[:, None] * np.array(u)
            rho = np.linalg.norm(rv, axis=1)
            rh = rv / np.maximum(rho, 1e-9)[:, None]
            dn = sstep(0, 0.5 * np.maximum(rho, 1e-9), rv @ np.array(Dr))
            for aj, g, conv in joints:
                av = 1 - sstep(0, 0.5 * shaft, abs(ax - aj))
                cv = np.array(dirv) * conv if conv else np.array(Lt)
                sv = 0.75 + 0.25 * np.clip(rh @ cv, -1, 1)
                X = X + rv * (g * av * dn * sv * (wf >= 0.5))[:, None]
            # zig-zag
            R = rot_toward(Dr, ang, u, dirv)
            if kb == 2:
                X = turn(X, w[1], npP[1], R)
                P3n = npP[1] + R @ (npP[2] - npP[1])
                X = X + (w[2][:, None] * (P3n - npP[2]))
            else:
                X = turn(X, w[2], npP[2], R)
                P3n = npP[2]
            Ev = np.array(E)
            En = Ev + (P3n - npP[2]) if kb == 2 else npP[2] + R @ (Ev - npP[2])
            e = En - npP[0]
            ue = np.array(u)
            ca = np.arctan2(np.cross(e, ue) @ np.array(Dr), e @ ue)
            if not wreck:
                X = turn(X, wf, npP[0], np.array(Matrix.Rotation(ca, 3, Dr)))
            else:
                if f == "index":
                    Rw = rot_toward(Dr, np.radians(30), u, Lt)
                else:
                    Rw = rot_toward(Lt, np.radians(40), u, -Dr)
                X = turn(X, w[2], P3n, Rw)
            pt.move(X)
        out.append("%s%s K %.2f shaft %.4f R %.4f g.02 %.2f g.03 %.2f a %.1f deg %s%s" % (
            side, f, KNUCK[f], shaft, Rk, g2, g3, np.degrees(ang),
            "kink .03" if kb == 3 else "kink .02", " wreck" if wreck else ""))


def main() -> None:
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    arch = bpy.data.collections["archive_"]
    for p in PARTS:
        ob = bpy.data.objects[p]
        cp = ob.copy()
        cp.data = ob.data.copy()
        cp.name = "proof_" + p
        arch.objects.link(cp)
    parts = {p: Part(p) for p in PARTS}
    lines = []
    for side in "LR":
        fr = hand_frame(side)
        mass(fr, parts, side, lines)
        cords(fr, parts, side, lines)
        fingers(fr, parts, side, lines)
    # Live edit: dials the live parts in memory on purpose (archive copies = the before half; nothing is saved).
    for p in PARTS:
        me = parts[p].ob.data
        me.vertices.foreach_set("co", parts[p].co.ravel())
        me.update()
    with open(os.path.join(out, "proof.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    look.main([out, "proof"])


main()
