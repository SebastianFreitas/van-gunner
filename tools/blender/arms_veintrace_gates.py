"""The four practical gates and their fallback moves for arms_veintrace (no bpy)."""
from __future__ import annotations

import math

import numpy as np

from arms_veingates import HEADS, SPAN  # noqa: E402
from arms_veinsplice import PALM, pack_of, read_old  # noqa: E402
import arms_veintrace_data as D  # noqa: E402

W_TO_R = 4.53  # full width at half height = 4.53 r (research 05 Mapping)
VEIN_MAX = 160


def _length(a, b) -> float:
    return math.hypot((b[0] - a[0]) * SPAN, b[1] - a[1]) / SPAN


def _near(cx: Ctx, s: float, lat: float) -> tuple:
    """(skin index, skin distance, finger/web distance) of the point in the (s x span, lat) plane."""
    q = np.array([s * SPAN, lat])
    d = np.hypot(*(cx.xy - q).T)
    j = int(np.argmin(d))
    return j, float(d[j]), float(np.hypot(*(cx.oxy - q).T).min())


def _ok_a(cx: Ctx, s: float, lat: float) -> bool:
    _, ds, do = _near(cx, s, lat)
    return ds <= do and cx.snap_s(s, lat) <= 1.0 + 1e-9


def _ok_c(cx: Ctx, s: float, lat: float) -> bool:
    return float(cx.wt[_near(cx, s, lat)[0]]) < 0.25


def _slide(cx: Ctx, pts: list, i: int, ok) -> bool:
    """Moves point i along its path toward the wrist by the smallest step that passes ok."""
    lo = abs(pts[i - 1][0]) if i > 0 else 9.0
    hi = abs(pts[i + 1][0]) if i + 1 < len(pts) else 9.0
    d = 1 if hi < lo else -1
    j = i
    while 0 <= j + d < len(pts):
        a, b = pts[j], pts[j + d]
        n = max(1, math.ceil(_length(a, b) / 0.005))
        for k in range(1, n + 1):
            t = k / n
            q = tuple(a[m] + (b[m] - a[m]) * t for m in range(3))
            if ok(cx, q[0], q[1]):
                if d > 0:
                    pts[i:j + d + (1 if k == n else 0)] = [q]
                else:
                    pts[j + d + (0 if k == n else 1):i + 1] = [q]
                return True
        j += d
    return False


def _push_b(cx: Ctx, pts: list, i: int) -> bool:
    """G-b fallback: out of the disc along the head-to-point line by the smallest move."""
    s, lat, r = pts[i]
    for hs, hl, disc in HEADS.values():
        dx, dy = s * SPAN - hs * SPAN, lat - hl
        need = disc + r * W_TO_R / 2
        dist = math.hypot(dx, dy)
        if dist < need:
            f = (need + 1e-6) / max(dist, 1e-9)
            pts[i] = (hs + dx * f / SPAN, hl + dy * f, r)
    return True


def _push_shared(cx: Ctx, res: dict, dup: dict) -> None:
    """G-b fallback once on each shared point, the moved position written into every holder."""
    for old in [k for k, c in dup.items() if c > 1]:
        for q in res["paths"].values():
            for i, p in enumerate(q["pts"]):
                if p[:2] == old and _bad(cx, "b", q["pts"], i, q["free"]):
                    new = list(q["pts"])
                    _push_b(cx, new, i)
                    mv = new[i]
                    for q2 in res["paths"].values():
                        q2["pts"] = [(mv[0], mv[1], x[2]) if x[:2] == old else x
                                     for x in q2["pts"]]
                    dup[mv[:2]] = dup.pop(old)
                    break
            else:
                continue
            break


def _fails(cx: Ctx, res: dict) -> dict:
    out = {"a": [], "b": [], "c": [], "d": []}
    for name, q in res["paths"].items():
        pts = q["pts"]
        for i, p in enumerate(pts):
            j, ds, do = _near(cx, p[0], p[1])
            if not _ok_a(cx, p[0], p[1]):
                out["a"].append("%s#%d v%d" % (name, i, cx.t["ids"][j]))
            for hn, (hs, hl, disc) in HEADS.items():
                if math.hypot((p[0] - hs) * SPAN, p[1] - hl) < disc + p[2] * W_TO_R / 2 - 1e-9:
                    out["b"].append("%s#%d %s v%d" % (name, i, hn, cx.t["ids"][j]))
        for k, on in enumerate(q["free"]):
            p = pts[0 if k == 0 else -1]
            if on and not _ok_c(cx, p[0], p[1]):
                out["c"].append("%s#%s v%d" % (name, "0" if k == 0 else "end",
                                               cx.t["ids"][_near(cx, p[0], p[1])[0]]))
    for br, end, tr in res["joins"]:
        if res["paths"][br]["pts"][end][:2] not in [p[:2] for p in res["paths"][tr]["pts"]]:
            out["d"].append("join %s -> %s not shared" % (br, tr))
    for tr, s_c in D.CONTINUES[res["side"]].items():
        r = [p for p in res["paths"][tr]["pts"] if abs(p[0] - s_c) <= 0.05]
        out["d"] += ["%s r step >15%% at s %.3f" % (tr, b[0]) for a, b in zip(r, r[1:])
                     if abs(b[2] - a[2]) > 0.15 * a[2]]
    for br, end, _ in res["joins"]:
        if end == 0 and br in res["start_r"] and \
                res["paths"][br]["pts"][0][2] < res["start_r"][br] * (1 - 1e-6):
            out["d"].append("%s starts below its listed width" % br)
    pk = _pack(cx, res)
    if pk > VEIN_MAX:
        out["d"].append("pack %d > %d" % (pk, VEIN_MAX))
    return out


def _pack(cx: Ctx, res: dict) -> int:
    old, oflags, _ = read_old(res["side"])
    ps = [old[i] for i in PALM[res["side"]]]
    fl = [oflags[i] for i in PALM[res["side"]]]
    for q in res["paths"].values():
        ps.append([cx.mesh.chart(cx.side, p[:2]) + (p[2],) for p in q["pts"]])
        fl.append(q["free"][0] | (q["free"][1] << 1))
    return pack_of(ps, fl)

def _bad(cx: Ctx, gate: str, pts: list, i: int, free: tuple) -> bool:
    s, lat, r = pts[i]
    if gate == "a":
        return not _ok_a(cx, s, lat)
    if gate == "c":
        return bool(free[0] if i == 0 else free[1] if i == len(pts) - 1 else 0) \
            and not _ok_c(cx, s, lat)
    return any(math.hypot((s - hs) * SPAN, lat - hl) < disc + r * W_TO_R / 2 - 1e-9
               for hs, hl, disc in HEADS.values())
