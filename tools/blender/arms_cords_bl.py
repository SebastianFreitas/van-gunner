"""Finger-cord geometry on the real skin chart, shared by `arms.py relief` and the veins step.

Mirrors ArmSkinFolds.apply (tendon from the hand head toward each `.01` head). The chart
helpers are wrap-aware: chart v is 0.035 atan2, so differences reduce modulo WRAP.
"""
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from arms_frame_bl import chart, hand_frame  # noqa: E402

WRAP = 2 * math.pi * 0.035
FING = ("index", "middle", "ring", "pinky")
TENDON_START = 0.15
TENDON_HALF = 0.42


class Skin:
    """World positions, normals, chart and graph of one `<S>_skin` (or archive copy)."""

    def __init__(self, ob, live: bool = True):
        self.ob = ob
        ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()) if live else ob
        me = ev.data
        n = len(me.vertices)
        co = np.zeros(n * 3)
        me.vertices.foreach_get("co", co)
        mw = np.array(ev.matrix_world)
        self.pos = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
        nrm = np.zeros(n * 3)
        me.vertices.foreach_get("normal", nrm)
        nrm = nrm.reshape(-1, 3) @ mw[:3, :3].T
        self.nrm = nrm / (np.linalg.norm(nrm, axis=1)[:, None] + 1e-12)
        self.ch = np.array(chart(ev))
        self.ring = [[] for _ in range(n)]
        for e in me.edges:
            a, b = e.vertices
            self.ring[a].append(b)
            self.ring[b].append(a)
        self.groups = {g.index: g.name for g in ob.vertex_groups}
        self.mesh = ob.data
        self.polys = [tuple(pl.vertices) for pl in me.polygons]
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in self.pos], self.polys)
        self.misses = 0

    def weights(self, name: str) -> np.ndarray:
        w = np.zeros(len(self.pos))
        for v in self.mesh.vertices:
            for g in v.groups:
                if self.groups[g.group] == name:
                    w[v.index] = g.weight
        return w

    def dorsal(self, up) -> np.ndarray:
        return (self.nrm @ up > 0.3) & (self.ch[:, 2] > 0)

    def project(self, p, dors, cand) -> tuple:
        """Chart of the skin surface hit by a ray from 3D point p along dors (barycentric on
        the hit triangle, wrap-aware); the nearest dorsal vertex's chart on a miss."""
        hit = self.bvh.ray_cast(Vector(p), Vector(dors))
        if hit[0] is None:
            self.misses += 1
            return tuple(self.ch[cand[int(np.argmin(np.linalg.norm(self.pos[cand] - p, axis=1)))], :2])
        q = np.array(hit[0])
        vs = self.polys[hit[2]]
        best = None
        for k in range(1, len(vs) - 1):
            a, b, c = (self.pos[vs[0]], self.pos[vs[k]], self.pos[vs[k + 1]])
            m = np.array((b - a, c - a)).T
            w = np.linalg.lstsq(m, q - a, rcond=None)[0]
            w = np.clip(w, 0, None)
            w = w / max(w.sum(), 1e-12) if w.sum() > 1 else w
            err = float(np.linalg.norm(m @ w - (q - a)))
            if best is None or err < best[0]:
                best = (err, (vs[0], vs[k], vs[k + 1]), (1 - w.sum(), w[0], w[1]))
        _, tri, bw = best
        v0 = self.ch[tri[0], 1]
        x = sum(wt * self.ch[i, 0] for wt, i in zip(bw, tri))
        v = sum(wt * (self.ch[i, 1] - WRAP * round((self.ch[i, 1] - v0) / WRAP))
                for wt, i in zip(bw, tri))
        return (float(x), float(v))

    def dist(self, c) -> np.ndarray:
        """Chart distance of every vertex to chart point c."""
        dv = self.ch[:, 1] - c[1]
        dv -= WRAP * np.round(dv / WRAP)
        return np.hypot(self.ch[:, 0] - c[0], dv)

    def ratio(self, i: int) -> float:
        """Local chart/3D ratio at vertex i: median over its one ring."""
        out = []
        for j in self.ring[i]:
            d3 = float(np.linalg.norm(self.pos[j] - self.pos[i]))
            if d3 > 1e-9:
                out.append(float(self.dist(self.ch[i])[j]) / d3)
        return float(np.median(out)) if out else 1.0


def polyline(ch, pts, rs=None) -> tuple:
    """Per chart vertex: (distance to the polyline, arc fraction of the nearest point,
    unit direction there, interpolated r). pts are (x, v) chart points, wrap-aware."""
    n = len(ch)
    best = np.full(n, 1e9)
    arc = np.zeros(n)
    dirs = np.zeros((n, 2))
    rr = np.zeros(n)
    lens = []
    for a, b in zip(pts, pts[1:]):
        dv = b[1] - a[1]
        lens.append(math.hypot(b[0] - a[0], dv - WRAP * round(dv / WRAP)))
    total = sum(lens) + 1e-12
    done = 0.0
    for k, (a, b) in enumerate(zip(pts, pts[1:])):
        dvb = b[1] - a[1]
        ab = np.array((b[0] - a[0], dvb - WRAP * round(dvb / WRAP)))
        dv = ch[:, 1] - a[1]
        dv -= WRAP * np.round(dv / WRAP)
        rel = np.stack((ch[:, 0] - a[0], dv), axis=1)
        t = np.clip(rel @ ab / (ab @ ab + 1e-18), 0.0, 1.0)
        d = np.hypot(*(rel - t[:, None] * ab).T)
        better = d < best
        best = np.where(better, d, best)
        arc = np.where(better, (done + t * lens[k]) / total, arc)
        dirs[better] = ab / (np.linalg.norm(ab) + 1e-12)
        if rs is not None:
            rr = np.where(better, rs[k] + t * (rs[k + 1] - rs[k]), rr)
        done += lens[k]
    return best, arc, dirs, rr


def centre(sk: Skin, pts, rs=None) -> tuple:
    """(indices, directions) of the mask > 0 vertices within 0.002 of the polyline's
    middle 40 % (arc 0.30..0.70)."""
    d, arc, dirs, _ = polyline(sk.ch[:, :2], pts, rs)
    ok = (d <= 0.002) & (arc >= 0.30) & (arc <= 0.70) & (sk.ch[:, 2] > 0)
    idx = np.nonzero(ok)[0]
    return idx, dirs[idx]


def cords(side: str, sk: Skin = None) -> list:
    """Per finger: (name, three chart points, (r at t 0, .5, 1), (A, B) world segment)."""
    sk = sk or Skin(bpy.data.objects[side + "_skin"])
    rig = bpy.data.objects["rig"]
    rw = rig.matrix_world
    bones = rig.data.bones
    H = np.array(rw @ bones["DEF-hand." + side].head_local)
    up = np.array((0.0, 0.0, 1.0))
    dors = np.array(hand_frame(side).dors)
    cand = np.nonzero(sk.dorsal(up))[0]
    out = []
    for f in FING:
        b = bones["DEF-f_%s.01.%s" % (f, side)]
        head = np.array(rw @ b.head_local)
        tail = np.array(rw @ b.tail_local)
        A = H + (head - H) * TENDON_START
        ids = []
        for t in (0.0, 0.5, 1.0):
            p = A + (head - A) * t
            ids.append(int(cand[np.argmin(np.linalg.norm(sk.pos[cand] - p, axis=1))]))
        cpts = [sk.project(A + (head - A) * t, dors, cand) for t in (0.0, 0.5, 1.0)]
        w = sk.weights("DEF-f_%s.01.%s" % (f, side))
        ax = tail - head
        L = np.linalg.norm(ax)
        ax /= L
        tt = (sk.pos - head) @ ax / L
        sel = (w >= 0.5) & (np.abs(tt - 0.5) <= 0.15)
        rad = np.linalg.norm((sk.pos[sel] - head) - np.outer(tt[sel] * L, ax), axis=1)
        fr = float(rad.mean()) if len(rad) else 0.0
        r = 0.42 * fr * sk.ratio(ids[1]) / 2.26
        r = r if 0.004 <= r <= 0.008 else 0.006
        out.append([f, cpts, r, (A, head)])
    for k, c in enumerate(out):
        r5 = c[2]
        sp = []
        for t in (1, 2):
            gaps = []
            for j in (k - 1, k + 1):
                if 0 <= j < len(out):
                    dv = c[1][t][1] - out[j][1][t][1]
                    gaps.append(abs(dv - WRAP * round(dv / WRAP)))
            sp.append(min(gaps) / 4.52 if gaps else 1e9)
        r1 = min(r5, sp[1])
        r5 = min(r5, sp[0])
        out[k] = (c[0], c[1], (r5, r5, r1), c[3])
    return out
