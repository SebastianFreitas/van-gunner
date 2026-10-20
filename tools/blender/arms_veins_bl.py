"""`arms.py step veins`: lowers the old baked vein relief, raises the traced paths (plan D37-D38).

Runs through `arms_step_bl.py` (`prepare("veins")` archives the parts, a re-run restores them).
The live vein sets become copies of `vein_set_<side>_next.tres`; the old live sets are kept once
as `resources/arms/archive/vein_set_<side>_baked.tres`. Skin vertex moves: the baked layer
(0.014 m x h_old, GDScript `ArmVeinField.sample` on the baked pack, scaled by k so the old crest
matches the p4-1 baseline) comes off, the traced paths go on as millimetre relief (`--vein MM` default 1.5, `--cord MM` default 2.0, D89).
"""
import math
import os
import re
import shutil
import sys
from types import SimpleNamespace

import bpy
import numpy as np

import arms_step_bl as S  # noqa: E402
from arms_cords_bl import centre, cords, polyline  # noqa: E402
from arms_frame_bl import chart  # noqa: E402
from arms_relief_bl import read_paths  # noqa: E402
from arms_veinsplice import NAME, PALM, RES  # noqa: E402
from arm_names import SKIN

MAX_R = 0.006
FADE_LEN = 0.012
RELIEF_M = 0.014
VEIN_MM = 1.5
CORD_MM = 2.0
BASE_OLD = {"R": 0.00424, "L": 0.01338}  # p4-2b baseline old_relief (net of the hand's floor)
CAP = 0.006  # safety: a move over this blocks the step


def pack_of(path: str, skip: int = 0) -> np.ndarray:
    """`ArmVeinSet.pack` of a vein set .tres (minus its first `skip` paths): rows (x, v, r, hf),
    (0, 0, -1, 0) between paths."""
    paths = read_paths(path)[skip:]
    with open(path) as fh:
        fl = re.search(r"^free_ends = PackedInt32Array\((.*)\)$", fh.read(), re.M).group(1)
    flags = [int(x) for x in fl.split(",")] if fl.strip() else []
    out = []
    for i, pts in enumerate(paths):
        if len(pts) < 2:
            continue
        f = flags[i + skip] if i + skip < len(flags) else 0
        cum = [0.0]
        for a, b in zip(pts, pts[1:]):
            cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        total = cum[-1]
        stops = list(cum)
        if total > FADE_LEN * 3.0:
            for k in (0.34, 0.67):
                if f & 1:
                    stops.append(FADE_LEN * k)
                if f & 2:
                    stops.append(total - FADE_LEN * k)
        for s in sorted(stops):
            j = next((k for k in range(1, len(pts)) if s <= cum[k] or k == len(pts) - 1), 1)
            span = max(cum[j] - cum[j - 1], 0.00001)
            t = min(max((s - cum[j - 1]) / span, 0.0), 1.0)
            p = [pts[j - 1][k] + (pts[j][k] - pts[j - 1][k]) * t for k in range(3)]
            hf = 1.0
            if f & 1:
                hf = min(hf, smooth(s / FADE_LEN))
            if f & 2:
                hf = min(hf, smooth((total - s) / FADE_LEN))
            out.append((p[0], p[1], p[2] * (0.4 + 0.6 * hf), hf))
        out.append((0.0, 0.0, -1.0, 0.0))
    return np.array(out)


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def smax(a: np.ndarray, b: np.ndarray, blend: float = 0.3) -> np.ndarray:
    """`ArmVeinField._smax`, a zero input adds nothing."""
    gap = np.maximum(blend - np.abs(a - b), 0.0)
    out = np.maximum(a, b) + gap * gap / (4.0 * blend)
    return np.where(a <= 0.0, b, np.where(b <= 0.0, a, out))


def field(ch: np.ndarray, pack: np.ndarray, old: bool, max_r: float = MAX_R) -> np.ndarray:
    """Per vertex height over a packed set: `old` is the baked tube sqrt(1 - q^2) profile of
    `ArmVeinField.sample` (capped at 1); else w (r / max_r) (1 - q^2)^2 with q = d / (2.26 r), max_r the pack's largest r (D87).
    Path maxima are blended by the smooth max. A new path's weight is capped at 1 (palm paths)."""
    total = np.zeros(len(ch))
    best = np.zeros(len(ch))
    for i in range(len(pack) - 1):
        a, b = pack[i], pack[i + 1]
        if a[2] < 0.0 or b[2] < 0.0:
            if a[2] < 0.0:
                total = smax(total, best)
                best = np.zeros(len(ch))
            continue
        ab = b[:2] - a[:2]
        rel = ch[:, :2] - a[:2]
        t = np.clip(rel @ ab / max(float(ab @ ab), 1e-7), 0.0, 1.0)
        d = np.hypot(*(rel - t[:, None] * ab).T)
        r = a[2] + (b[2] - a[2]) * t
        w = a[3] + (b[3] - a[3]) * t
        if old:
            q = d / np.maximum(r, 1e-5)
            h = np.where(q < 1.0, w * (r / MAX_R) * np.sqrt(np.maximum(1.0 - q * q, 0.0)), 0.0)
        else:
            q = d / (2.26 * np.maximum(r, 1e-5))
            h = np.where(q < 1.0, w * np.minimum(r / max_r, 1.0) * (1.0 - q * q) ** 2, 0.0)
        best = np.maximum(best, h)
    total = smax(total, best)
    return np.minimum(total, 1.0) if old else total


def cord_h(ch: np.ndarray, side: str) -> np.ndarray:
    """Per-vertex finger-cord height (0..1): one tapered
    (1 - q^2)^2 ridge per finger on `cords()`' three chart points, smax-blended."""
    total = np.zeros(len(ch))
    for name, pts, rs, _ in cords(side):
        d, _, _, rr = polyline(ch[:, :2], pts, list(rs))
        q = d / (2.26 * np.maximum(rr, 1e-5))
        total = smax(total, np.where(q < 1.0, (1.0 - q * q) ** 2, 0.0))
    return total


def archive_sets(lines: list) -> None:
    arch = os.path.join(RES, "archive")
    os.makedirs(arch, exist_ok=True)
    for nm in NAME.values():
        live = os.path.join(RES, "vein_set_%s.tres" % nm)
        baked = os.path.join(arch, "vein_set_%s_baked.tres" % nm)
        if not os.path.exists(baked):
            shutil.copyfile(live, baked)
            lines.append("archived %s" % os.path.basename(baked))
        shutil.copyfile(os.path.join(RES, "vein_set_%s_next.tres" % nm), live)


def main(args) -> None:
    vein = float(args[args.index("--vein") + 1]) / 1000.0 if "--vein" in args else VEIN_MM / 1000.0
    cord = float(args[args.index("--cord") + 1]) / 1000.0 if "--cord" in args else CORD_MM / 1000.0
    S.prepare("veins")
    lines = []
    plan = []
    blocked = []
    k = k_r = 0.0
    for side in "RL":
        part = S.Part(side + SKIN)
        me = part.ob.data
        nrm = np.empty(len(part.co) * 3)
        me.vertices.foreach_get("normal", nrm)
        nrm = nrm.reshape(-1, 3)
        ch = np.array(chart(part.ob))
        mask = ch[:, 2] > 0
        nm = NAME[side]
        live = os.path.join(RES, "vein_set_%s.tres" % nm)
        bk = os.path.join(RES, "archive", "vein_set_%s_baked.tres" % nm)
        if not os.path.exists(bk):
            bk = live
        nx = os.path.join(RES, "vein_set_%s_next.tres" % nm)
        baked = pack_of(bk)
        new = pack_of(nx)
        h_old = field(ch, baked, True) * ch[:, 2]
        ns = SimpleNamespace(ch=ch)
        idx = np.zeros(len(ch), dtype=bool)
        for p in read_paths(bk):
            idx[centre(ns, [(q[0], q[1]) for q in p])[0]] = True
        med = float(np.median(h_old[idx])) if idx.any() else 0.0
        if side == "R":  # R first: one k for both hands, never above 1 (D85, D86)
            k_r = BASE_OLD["R"] / (RELIEF_M * med) if med > 0 else 0.0
            k = min(1.0, k_r)
        max_r = float(pack_of(nx, len(PALM[side]))[:, 2].max())  # traced back veins only
        h_vein = field(ch, new, False, max_r)
        up = smax(vein * h_vein, cord * cord_h(ch, side), max(0.3 * cord, 1e-9))  # metres
        under = (up > 0) & ~mask
        move = np.where(mask, up, 0.0) - k * RELIEF_M * h_old
        d = part.grouped(nrm * move[:, None])
        mm = np.linalg.norm(d, axis=1)
        mx = float(np.abs(move).max())
        mu = float(up.max())  # the raised relief alone: the baked removal alone reaches 8.5 mm
        if k > 2.5 or mu > CAP:
            blocked.append("VEINS BLOCK %s k=%.4f raise_mm=%.3f" % (side, k, 1000 * mu))
        plan.append((side, part, d, k, med, idx, mm, under))
        lines.append("%s vein %.2f mm cord %.2f mm max_r_back %.5f max move %.3f mm" % (
            side, 1000 * vein, 1000 * cord, max_r, 1000 * mx))
    if blocked:
        print("\n".join(blocked))
        sys.exit(1)
    archive_sets(lines)
    lines.append("k=%.4f (k_R=%.4f)" % (k, k_r))
    for side, part, d, k, med, idx, mm, under in plan:
        n = part.write(part.co + d)
        lines.append("%s k %.4f (median h_old %.4f over %d sample vertices)" % (
            side, k, med, int(idx.sum())))
        lines.append("%s moved %d vertices, max |move| %.3f mm, seam_moved %d" % (
            side, n, 1000 * float(mm.max()), part.seam_moved))
        lines.append("%s moved over 5 mm %d, over 10 mm %d" % (
            side, int((mm > 0.005).sum()), int((mm > 0.0100001).sum())))
        lines.append("%s masked under a path (not moved) %d: %s" % (
            side, int(under.sum()), " ".join(str(i) for i in np.nonzero(under)[0])))
    print("\n".join("VEINS " + ln for ln in lines))
    S.finish()
