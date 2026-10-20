"""`arms.py step mass`: widen both hands' flanks (plan hands-blender-review phase 2, D24/D25).

Skin vertices past the inner limit l(s) = l_side x smoothstep(0.5, 0.875, s) move outward along
lat by (f_side(s) - 1)(|lat| - l(s)) x (1 - DEF-thumb weight); a vertex weighted 0.5 or more to
the finger bones (webs and fingers are other parts) stays. The pinky side grows to T7 .123, the
index side's slab 8 to .088. Measured exactly as Godot's `shape()` (ShapeFrame, 9 slabs, p95).
Args: `wrist` (f = 1 to s 1/8, f1 at 3/16: the wrist_step fallback), `t7=<m>` (default .123).
Per side, up to two fallback rounds (f_k += (T_k - measured)/(W_k - l), a shallower root raises
that flank's l_side by its shaft), then one fresh run at T7 .119; the outcome is printed.
"""

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

from arm_names import FINGERS, VG_HAND, VG_PALM, VG_FING_FMT, VG_FING_ROOT, VG_THUMB_FMT, SKIN, FINGERS_PART, RIG
import arms_step_bl as S  # noqa: E402
from arms_frame_bl import shape_frame  # noqa: E402

L_SIDE = {"index": .0526, "pinky": .0918}
SHAFT = {"index": .0274, "middle": .0333, "ring": .0270, "pinky": .0239}
ROOT_SIDE = {"index": "index", "middle": "index", "ring": "pinky", "pinky": "pinky"}
T8_INDEX = .088
# research 03: root s / lat (pinky side +), R W per side (index / pinky), slabs 0..8
ROOTS_REF = {"index": (1.002, -.0526), "middle": (1.051, 0.0), "ring": (1.061, .0507),
             "pinky": (.885, .0918)}
W_REF = {"index": [.070, .075, .087, .089, .091, .081, .095, .091, .078],
         "pinky": [.074, .081, .088, .093, .107, .115, .117, .114, .107]}
PROOF_W7 = .085


def sstep(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def p95(lats, areas):
    o = np.argsort(lats, kind="stable")
    acc = np.cumsum(areas[o])
    i = int(np.searchsorted(acc, 0.95 * acc[-1] - 1e-15))
    return float(lats[o][min(i, len(o) - 1)])


class Hand:
    def __init__(self, side, parts):
        self.side = side
        self.sk, self.fg = parts[side + SKIN], parts[side + FINGERS_PART]
        self.fr = shape_frame(side)
        sk = self.sk
        self.tw = sk.wt(*[(VG_THUMB_FMT + ".%s") % (i, side) for i in (1, 2, 3)])
        self.fw = sk.wt(*[(VG_FING_FMT + ".%s") % (f, i, side) for f in FINGERS for i in (1, 2, 3)])
        wsum = sum(sk.w.values())
        hand = sk.wt(VG_HAND + "." + side, *[n for n in sk.w if n.startswith(VG_PALM)])
        self.share = (wsum > 0) & (hand >= 0.30 * wsum)

    def coords(self, co):
        d = co - np.array(self.fr.H)
        return d @ np.array(self.fr.axis) / self.fr.span, d @ np.array(self.fr.lat)

    def measure(self, co):
        """{side: [W0..W8]} area-weighted p95 of |lat| per slab, as Godot's `shape()`."""
        s, lat = self.coords(co)
        k = np.floor(s * 8 + 0.5).astype(int)
        ok = self.share & (k >= 0) & (k <= 8) & (np.abs(s - k / 8) <= 1 / 16 + 1e-12)
        area = self.sk.area(co)
        out = {}
        for name, m in (("index", lat <= 0), ("pinky", lat > 0)):
            out[name] = [p95(np.abs(lat[ok & m & (k == kk)]), area[ok & m & (k == kk)])
                         for kk in range(9)]
        return out

    def root_depths(self, co):
        """Per finger: the shallowest depth (m, + inside) of its `.01` root ring in the skin."""
        sk = self.sk
        bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(t) for t in sk.tri])
        res = {}
        for f in FINGERS:
            bone = bpy.data.objects[RIG].data.bones[(VG_FING_ROOT + ".%s") % (f, self.side)]
            h = np.array(bone.head_local)
            a = np.array(bone.tail_local - bone.head_local)
            a /= np.linalg.norm(a)
            idx = np.nonzero(self.fg.w[(VG_FING_ROOT + ".%s") % (f, self.side)] > 0.5)[0]
            t = (self.fg.co[idx] - h) @ a
            ring = idx[t <= t.min() + 1e-4]
            best = 9.0
            for i in ring:
                loc, nrm, _, dist = bvh.find_nearest(tuple(self.fg.co[i]))
                inside = (np.array(self.fg.co[i]) - np.array(loc)) @ np.array(nrm) < 0
                best = min(best, dist if inside else -dist)
            res[f] = best
        return res

    def apply(self, W, prm):
        """New skin positions for params `prm` (t7, df, lside, wrist); returns (co, f, T)."""
        s, lat = self.coords(self.sk.co)
        new = self.sk.co.copy()
        Lt = np.array(self.fr.lat)
        fs_, ts_ = {}, {}
        for sg, name in ((1, "pinky"), (-1, "index")):
            w, lk = np.array(W[name]), prm["lside"][name] * sstep(.5, .875, np.arange(9) / 8)
            T = w.copy()
            if name == "pinky":
                T[:8] = w[0] + (prm["t7"] - w[0]) * (1 - (1 - np.arange(8) / 7) ** 1.5)
                T[8] = T[7]
            else:
                T[8] = T8_INDEX
            f = 1 + (T - w) / np.maximum(w - lk, 0.01) + prm["df"][name]
            if name == "pinky":
                f[0], f[8] = 1.0, f[7]
            else:
                f[:8] = 1.0
            xs, fv = ([1 / 8, 3 / 16], [1.0, f[1]]) if prm["wrist"] else ([1 / 16, 1 / 8], [1.0, f[1]])
            xs += [k / 8 for k in range(2, 9)] + [17 / 16, 19 / 16]
            fv += [f[k] for k in range(2, 9)] + [f[8], 1.0]
            fx = np.interp(s, xs, fv)
            lv = prm["lside"][name] * sstep(.5, .875, s)
            a = sg * lat
            m = (a > lv) & (self.fw < 0.5)
            dl = np.where(m, (fx - 1) * (a - lv) * (1 - self.tw), 0.0) * sg
            new += dl[:, None] * Lt
            fs_[name], ts_[name] = f, T
        new = self.sk.co + self.sk.grouped(new - self.sk.co)
        return new, fs_, ts_


def fmt(v):
    return " ".join("%.4f" % x for x in v)


def gates(W):
    """(failing growth rows, jump): pinky mono 0..7, jump, W7 peak; index W8. Empty when ok."""
    pk, ix = W["pinky"], W["index"]
    why = []
    if any(pk[k] < pk[k - 1] for k in range(1, 8)):
        why.append("pinky-not-monotone")
    jump = max(pk[k] - pk[k - 1] for k in range(1, 8)) / max((pk[7] - pk[0]) / 7, 1e-4)
    if jump > 1.6:
        why.append("pinky-jump %.2f" % jump)
    if pk[7] < max(pk[:7]) + 0.002:
        why.append("pinky-W7<peak+.002")
    if abs(ix[8] - T8_INDEX) > 0.002:
        why.append("index-W8 %.4f" % ix[8])
    return why, jump


def edit_hand(h, lines, args):
    side = h.side
    wrist = "wrist" in args
    t7 = next((float(a[3:]) for a in args if a.startswith("t7=")), .123)
    W0 = h.measure(h.sk.co)
    r0 = h.root_depths(h.sk.co)
    lines.append("%s measured before:" % side)
    for n in ("index", "pinky"):
        lines.append("  W %s %s (research R %s)" % (n, fmt(W0[n]), fmt(W_REF[n])))
    lines.append("  pinky W7 %.4f beside the phase-1 proof's %.3f" % (W0["pinky"][7], PROOF_W7))
    s_, lat = h.coords(np.array([np.array(r) for r in h.fr.roots]))
    for i, n in enumerate(FINGERS):
        lines.append("  root .01 %s s %.4f lat %.4f (research %.3f / %.4f)"
                     % (n, s_[i], lat[i], *ROOTS_REF[n]))
        if abs(s_[i] - ROOTS_REF[n][0]) > 0.002 or abs(lat[i] - ROOTS_REF[n][1]) > 0.002:
            raise SystemExit("Error: %s root %s differs from research 03 by over .002" % (side, n))
    if side == "R":
        for n in ("index", "pinky"):
            if max(abs(a - b) for a, b in zip(W0[n], W_REF[n])) > 0.002:
                raise SystemExit("Error: R W %s differs from research 03 by over .002" % n)
    lines.append("  roots before " + " ".join("%s %.5f" % kv for kv in r0.items()))
    prm = {"t7": t7, "wrist": wrist, "lside": dict(L_SIDE),
           "df": {"index": np.zeros(9), "pinky": np.zeros(9)}}
    rounds, final = 0, None
    for rnd in range(4):
        new, f, T = h.apply(W0, prm)
        Wa, ra = h.measure(new), h.root_depths(new)
        bad_roots = [n for n in FINGERS if ra[n] < min(r0[n], 0.0005) - 1e-9]
        why, jump = gates(Wa)
        lines.append("  round %d t7 %.3f: f pinky %s | f index8 %.4f" % (rnd, prm["t7"], fmt(f["pinky"]), f["index"][8]))
        lines.append("    W after pinky %s index %s%s" % (fmt(Wa["pinky"]), fmt(Wa["index"]),
                                                            " " + " ".join(why) if why else " growth ok"))
        lines.append("    roots after " + " ".join("%s %.5f" % kv for kv in ra.items())
                     + (" SHALLOWER " + ",".join(bad_roots) if bad_roots else " roots ok"))
        score = (len(why) + len(bad_roots), jump)
        if final is None or score < final[2]:
            final = (new, rnd, score)
        if not why and not bad_roots:
            break
        if rnd == 3:
            lines.append("  UNRESOLVED after t7 .119: round %d (closest) saved" % final[1])
            break
        if rnd < 2:
            for n in ("index", "pinky"):
                lk = prm["lside"][n] * sstep(.5, .875, np.arange(9) / 8)
                dd = (T[n] - np.array(Wa[n])) / np.maximum(np.array(W0[n]) - lk, 0.01)
                if n == "index":
                    dd[:8] = 0
                else:
                    dd[0] = 0
                prm["df"][n] = prm["df"][n] + dd
            for n in bad_roots:
                sd = ROOT_SIDE[n]
                prm["lside"][sd] = L_SIDE[sd] + SHAFT[sd]
        else:
            prm = {"t7": .119, "wrist": wrist, "lside": dict(L_SIDE),
                   "df": {"index": np.zeros(9), "pinky": np.zeros(9)}}
    lines.append("  %s saved round %d (rounds 1-2 fallback, 3 the T7 .119 re-run)" % (side, final[1]))
    n = h.sk.write(final[0])
    lines.append("  moved %d skin vertices, seam_moved %d groups" % (n, h.sk.seam_moved))


def crush_and_shard(parts, lines) -> None:
    """Hook, called last by the step: smooths the posed crush and tip-shard targets (D15)."""
    import arms_crush_bl
    arms_crush_bl.crush(parts, lines)


def main(args) -> None:
    S.prepare("mass")
    parts = {p: S.Part(p) for p in S.PARTS if p.endswith((SKIN, FINGERS_PART))}
    lines = []
    for side in "LR":
        edit_hand(Hand(side, parts), lines, args)
    crush_and_shard(parts, lines)
    print("\n".join("MASS " + ln for ln in lines))
    S.finish()
