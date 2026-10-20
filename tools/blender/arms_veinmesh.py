"""VeinMesh: the gates.py mesh interface over one hand's skin vertices (chart, s, lat, weights).

Shared by arms_veinpaths_bl, arms_veindump_bl and arms_veinpaint_bl.
"""
import bpy
import numpy as np
from mathutils.kdtree import KDTree

from arm_names import SKIN, VG_FING, VG_THUMB
from arms_frame_bl import chart, hand_frame

WRAP = 2 * np.pi * 0.035  # chart v is 0.035 atan2: it jumps by this across the seam


class VeinMesh:
    """The gates.py mesh interface over one hand's skin vertices."""

    def __init__(self, side: str):
        ob = bpy.data.objects[side + SKIN]
        ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.data
        fr = hand_frame(side)
        n = len(me.vertices)
        co = np.zeros(n * 3)
        me.vertices.foreach_get("co", co)
        mw = np.array(ev.matrix_world)
        w = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
        nrm = np.zeros(n * 3)
        me.vertices.foreach_get("normal", nrm)
        nrm = nrm.reshape(-1, 3) @ mw[:3, :3].T
        nrm /= np.linalg.norm(nrm, axis=1)[:, None] + 1e-12
        self.ch = np.array(chart(ev))
        d = w - np.array(fr.H)
        self.s = d @ np.array(fr.axis) / fr.span
        self.lat = d @ np.array(fr.lat)
        self.span = fr.span
        dors = nrm @ np.array(fr.dors) > 0.3
        # The set is drawn on the continuous chart: past the seam on the ulnar flank v keeps
        # rising (R) or falling (L), so carry those dorsal vertices across it.
        sg = 1.0 if side == "R" else -1.0
        past = dors & (self.ch[:, 1] * -sg > 0) & (self.lat < -0.03)
        self.ch[past, 1] += sg * WRAP
        self.tree = KDTree(int(dors.sum()))
        self.ids = np.nonzero(dors)[0]
        for k, i in enumerate(self.ids):
            self.tree.insert((self.s[i] * fr.span, self.lat[i], 0.0), k)
        self.tree.balance()
        self.all = KDTree(n)
        for i in range(n):
            self.all.insert((self.s[i] * fr.span, self.lat[i], 0.0), i)
        self.all.balance()
        names = {g.index: g.name for g in ob.vertex_groups}
        fw, tw = np.zeros(n), np.zeros(n)
        for v in ob.data.vertices:
            for g in v.groups:
                nm = names[g.group]
                if nm.startswith(VG_THUMB + ".0") and nm.endswith("." + side):
                    tw[v.index] += g.weight
                elif nm.startswith(VG_FING) and nm.endswith("." + side) and nm[-4] == "0":
                    fw[v.index] += g.weight
        self.fw, self.tw = fw, tw
        self.wmax = np.maximum(fw, tw)
        self.cxy = self.ch[:, :2]

    def _q(self, p) -> tuple:
        return (p[0] * self.span, p[1], 0.0)

    def chart(self, side: str, p) -> tuple:
        near = self.tree.find_n(self._q(p), 4)
        wts = [1.0 / (d + 1e-9) for _, _, d in near]
        tot = sum(wts)
        v0 = self.ch[self.ids[near[0][1]]][1]
        vs = [self.ch[self.ids[k]][1] for _, k, _ in near]
        vs = [v - WRAP * round((v - v0) / WRAP) for v in vs]  # unwrap beside the seam
        x = sum(w * self.ch[self.ids[k]][0] for w, (_, k, _) in zip(wts, near)) / tot
        v = sum(w * u for w, u in zip(wts, vs)) / tot
        return (x, v)

    def weight(self, side: str, p) -> float:
        _, i, _ = self.all.find(self._q(p))
        return float(self.wmax[i])

    def cover(self, side: str, chart_pts, r: float) -> int:
        hit = np.zeros(len(self.cxy), dtype=bool)
        for c in chart_pts:
            dv = self.cxy[:, 1] - c[1]
            dv -= WRAP * np.round(dv / WRAP)
            hit |= np.hypot(self.cxy[:, 0] - c[0], dv) <= 2.26 * r
        return int(hit.sum())

    def near_ids(self, p, n: int = 2) -> list:
        return [i for _, i, _ in self.all.find_n(self._q(p), n)]
