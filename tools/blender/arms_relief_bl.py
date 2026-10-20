"""`arms.py relief <dir>`: vein crest net of the hand's convexity floor, cord gate and cord_off per hand, read-only.

Runs as `blender -b --factory-startup arms.blend --python arms_relief_bl.py -- <dir>`.
Writes <dir>/relief.txt; never saves arms.blend or any .tres, moves no vertex.
"""
import math
import os
import re

import bpy
import numpy as np

import bl_result  # noqa: E402
from arms_frame_bl import hand_frame  # noqa: E402
from arms_cords_bl import WRAP, Skin, centre, cords, polyline  # noqa: E402
from arms_veinsplice import NAME, PALM, RES  # noqa: E402
from arm_names import SKIN


def read_paths(path: str) -> list:
    """The paths of a vein set .tres as lists of (x, v, r)."""
    with open(path) as fh:
        text = fh.read()
    body = re.search(r"^paths = Array\[PackedVector3Array\]\(\[(.*)\]\)$", text, re.M).group(1)
    out = []
    for p in re.findall(r"PackedVector3Array\(([^)]*)\)", body):
        v = [float(x) for x in p.split(",")]
        out.append([tuple(v[i:i + 3]) for i in range(0, len(v), 3)])
    return out


def sets_of(side: str) -> tuple:
    """(old paths, new paths): the live set whole, and the `_next` set minus its verbatim
    palm paths (the first len(PALM) of it)."""
    nm = NAME[side]
    old = os.path.join(RES, "archive", "vein_set_%s_baked.tres" % nm)
    if not os.path.exists(old):
        old = os.path.join(RES, "vein_set_%s.tres" % nm)
    old = read_paths(old)
    new = read_paths(os.path.join(RES, "vein_set_%s_next.tres" % nm))
    return old, new[len(PALM[side]):]


def crest_of(sk: Skin, pts, idx, dirs, before=None) -> list:
    """Per centre vertex: (p_i - b) . n_i, b the mean of the skin vertices 0.016..0.020 chart
    off the centreline on both flanks at chart x +-0.002 of the vertex; with `before` the
    vertex's own move (v - v_before) . n."""
    if before is not None:
        return [float((sk.pos[i] - before[i]) @ sk.nrm[i]) for i in idx]
    off = polyline(sk.ch[:, :2], pts)[0]
    band = (off >= 0.016) & (off <= 0.020)
    out = []
    for i, d in zip(idx, dirs):
        dv = sk.ch[:, 1] - sk.ch[i, 1]
        dv -= WRAP * np.round(dv / WRAP)
        dx = sk.ch[:, 0] - sk.ch[i, 0]
        ac = -dx * d[1] + dv * d[0]
        ok = band & (np.abs(dx) <= 0.002)
        if (ok & (ac > 0)).any() and (ok & (ac < 0)).any():
            out.append(float((sk.pos[i] - sk.pos[ok].mean(axis=0)) @ sk.nrm[i]))
    return out


def cord_off(sk: Skin, cand, dors, pts, seg) -> tuple:
    """Max chart distance between the cord polyline and the 3D segment's chart, both ways."""
    proj = [sk.project(seg[0] + (seg[1] - seg[0]) * k / 20, dors, cand) for k in range(21)]
    far = 0.0
    for c in proj:
        far = max(far, float(polyline(np.array([c]), pts)[0][0]))
    dense = []
    for p, q in zip(pts, pts[1:]):
        dv = q[1] - p[1]
        dv -= WRAP * round(dv / WRAP)
        for k in range(21):
            dense.append((p[0] + (q[0] - p[0]) * k / 20, p[1] + dv * k / 20))
    for c in dense:
        far = max(far, float(polyline(np.array([c]), [tuple(x) for x in proj])[0][0]))
    return far, proj


def covered(sk: Skin, pts, rs) -> np.ndarray:
    d, _, _, r = polyline(sk.ch[:, :2], pts, rs)
    return (d <= 2.26 * r) & (sk.ch[:, 2] > 0)


def med(v: list) -> float:
    return float(np.median(v)) if v else 0.0


def set_med(sk: Skin, paths: list) -> float:
    """Median over the paths of each path's median crest on `sk`."""
    out = []
    for p in paths:
        pts = [(q[0], q[1]) for q in p]
        idx, dirs = centre(sk, pts)
        c = crest_of(sk, pts, idx, dirs)
        if c:
            out.append(med(c))
    return med(out)


def main(args) -> None:
    out = args[0]
    vein = float(args[args.index("--vein") + 1]) / 1000.0 if "--vein" in args else 0.0015
    cord = float(args[args.index("--cord") + 1]) / 1000.0 if "--cord" in args else 0.002
    os.makedirs(out, exist_ok=True)
    base = None
    if "--baseline" in args:
        base = {}
        for ln in open(args[args.index("--baseline") + 1]):
            t = ln.split()
            if t and t[0] == "BASELINE":
                base[t[1]] = dict((x.split("=")[0], float(x.split("=")[1])) for x in t[2:])
    lines = []
    tail = []
    up = np.array((0.0, 0.0, 1.0))
    for side in ("R", "L"):
        sk = Skin(bpy.data.objects[side + SKIN])
        arch = bpy.data.objects.get("veins_%s" % side + SKIN)
        before = Skin(arch, live=False).pos if arch is not None else None
        sets = sets_of(side)
        pre = Skin(arch, live=False) if arch is not None else sk
        floor = set_med(pre, sets[1])
        pre_old = set_med(pre, sets[0]) - floor
        crests = {}
        max_r_back = max((q[2] for p in sets[1] for q in p), default=1.0)
        ratios = []
        ids = np.zeros(len(sk.pos), dtype=bool)
        for label, paths in zip(("old", "new"), sets):
            crests[label] = []
            for i, p in enumerate(paths):
                pts = [(q[0], q[1]) for q in p]
                idx, dirs = centre(sk, pts)
                c = crest_of(sk, pts, idx, dirs)
                if c:
                    crests[label].append(med(c))
                lines.append("PATH %s %s %d crest %s n %d (centre %d)" % (
                    side, label, i, "%.5f" % med(c) if c else "n/a", len(c), len(idx)))
                if label == "new" and c:
                    want = vein * min(1.0, med([q[2] for q in p]) / max_r_back)
                    ratios.append((med(c) - floor) / want if want > 0 else 0.0)
                    lines[-1] += " net %.5f gate %.5f %s" % (
                        med(c) - floor, 0.5 * want, "PASS" if med(c) - floor >= 0.5 * want else "FAIL")
                if label == "new":
                    ids |= covered(sk, pts, [q[2] for q in p])
            c = crests[label]
            lines.append("SET %s %s paths %d with samples %d crest min %.5f max %.5f" % (
                side, label, len(paths), len(c), min(c, default=0.0), max(c, default=0.0)))
        lines.append("VEINS %s new paths gated %d pass %d median ratio %.3f; old residual %.5f"
                     " (listed, not gated)" % (
                         side, len(ratios), sum(1 for x in ratios if x >= 0.5), med(ratios),
                         med(crests["old"]) - floor))
        old_m, new_m = med(crests["old"]) - floor, med(crests["new"]) - floor
        ref = base[side]["old_relief"] if base is not None else pre_old
        nt, ot = 1.6 * ref, 0.2 * ref
        lines.append("HAND %s floor=%.5f old_relief=%.5f new_relief=%.5f new_target=%.5f"
                     " old_target=%.5f%s" % (
                         side, floor, old_m, new_m, nt, ot,
                         "" if base is None else " new %s old %s" % (
                             "PASS" if new_m >= nt else "FAIL", "PASS" if old_m <= ot else "FAIL")))
        cand = np.nonzero(sk.dorsal(up))[0]
        dors = np.array(hand_frame(side).dors)
        sk.misses = 0
        if before is None:
            lines.append("cords: no veins_ archive yet (crest measured like a vein)")
        for name, pts, rs, seg in cords(side, sk):
            idx, dirs = centre(sk, pts, rs)
            c = crest_of(sk, pts, idx, dirs, before)
            crest = med(c) if c else None
            g = cord * (1 - (0.002 / (2.26 * rs[1])) ** 2) ** 2 * 0.9
            off, proj = cord_off(sk, cand, dors, pts, seg)
            if off > 0.0068 and name == "middle":
                lines.append("SAMPLES %s middle %s" % (side, " ".join("(%.4f,%.4f)" % tuple(c) for c in proj)))
            ids |= covered(sk, pts, rs)
            lines.append("CORD %s %s r(0.5) %.4f crest %s gate %.4f %s cord_off %.4f %s (centre %d)" % (
                side, name, rs[1], "%.5f" % crest if crest is not None else "n/a", g,
                "n/a" if crest is None else ("PASS" if crest >= g else "FAIL"),
                off, "PASS" if off <= 0.0068 else "FAIL", len(idx)))
        lines.append("MISSES %s %d" % (side, sk.misses))
        part = np.nonzero(ids)[0]
        lines.append("IDS %s skin %s" % (side, " ".join(str(int(i)) for i in part)))
        lines.append("IDSCOUNT %s skin %d" % (side, len(part)))
        tail.append("BASELINE %s old_relief=%.5f floor=%.5f" % (side, ref, floor))
    lines += tail
    with open(os.path.join(out, "relief.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    for x in lines:
        if not x.startswith("IDS "):
            print(x)


if __name__ == "__main__":
    main(bl_result.args())
    bl_result.write("relief")
