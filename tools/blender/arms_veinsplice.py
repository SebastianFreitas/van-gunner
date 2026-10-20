"""Splices the old vein paths onto Set v2 and writes resources/arms/vein_set_<side>_next.tres (no bpy)."""
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.normpath(os.path.join(HERE, "..", "..", "resources", "arms"))
NAME = {"R": "right", "L": "left"}
PALM_X = 1.05  # chart x below which a baked path is wrist or forearm
ROPE_X = 1.2  # a forearm rope ends before this x; past it the traced back veins take over
PALM_SIGN = {"R": -1, "L": 1}  # sign of v on the palm side (the back of the hand is the other)
FADE3 = 0.036  # ArmVeinSet.FADE_LEN * 3: shorter paths get no eased end points


def read_old(side: str) -> tuple:
    """(paths, flags, text) of the archived vein_set_<side>_baked.tres (never the live set, which
    already holds a splice); paths are lists of (x, v, r)."""
    with open(os.path.join(RES, "archive", "vein_set_%s_baked.tres" % NAME[side])) as fh:
        text = fh.read()
    body = re.search(r"^paths = Array\[PackedVector3Array\]\(\[(.*)\]\)$", text, re.M).group(1)
    paths = []
    for p in re.findall(r"PackedVector3Array\(([^)]*)\)", body):
        v = [float(x) for x in p.split(",")]
        paths.append([tuple(v[i:i + 3]) for i in range(0, len(v), 3)])
    fl = re.search(r"^free_ends = PackedInt32Array\((.*)\)$", text, re.M).group(1)
    return paths, [int(x) for x in fl.split(",")], text


def palm_indices(side: str) -> tuple:
    """Indices of the baked paths kept verbatim: those that start below PALM_X and either lie on
    the palm side or are forearm ropes (end below ROPE_X); the rest are dorsal and are traced."""
    keep = []
    for i, pts in enumerate(read_old(side)[0]):
        if min(p[0] for p in pts) >= PALM_X:
            continue
        mean_v = sum(p[1] for p in pts) / len(pts)
        if mean_v * PALM_SIGN[side] > 0 or max(p[0] for p in pts) < ROPE_X:
            keep.append(i)
    return tuple(keep)


PALM = {s: palm_indices(s) for s in NAME}  # baked indices kept verbatim


def pack_of(paths: list, flags: list) -> int:
    """ArmVeinSet.pack's count: points + 1 per path + 2 per free end on a path over .036."""
    n = 0
    for pts, f in zip(paths, flags):
        total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:]))
        n += len(pts) + 1
        if total > FADE3:
            n += 2 * ((f & 1) + ((f >> 1) & 1))
    return n


def _fmt(paths: list, flags: list) -> tuple:
    ps = ", ".join("PackedVector3Array(%s)" % ", ".join(
        "%.4f, %.4f, %.5f" % p for p in pts) for pts in paths)
    return "paths = Array[PackedVector3Array]([%s])" % ps, \
        "free_ends = PackedInt32Array(%s)" % ", ".join(str(f) for f in flags)


def splice_write(side: str, P: dict, chart_fn) -> list:
    """Writes the _next set: the old palm paths verbatim, then every path of P (s, lat, r).

    chart_fn((s, lat)) -> (x, v) is the mesh chart. Every old dorsal path leaves; the joins are
    shared points inside P already, so no point is moved or merged here."""
    old, oflags, text = read_old(side)
    paths = [old[i] for i in PALM[side]]
    flags = [oflags[i] for i in PALM[side]]
    for q in P.values():
        paths.append([chart_fn(p[:2]) + (p[2],) for p in q["pts"]])
        flags.append(q.get("free", (0, 0))[0] | (q.get("free", (0, 0))[1] << 1))
    pk = pack_of(paths, flags)
    pl, fl = _fmt(paths, flags)
    text = re.sub(r"^paths = .*$", lambda m: pl, text, flags=re.M)
    text = re.sub(r"^free_ends = .*$", lambda m: fl, text, flags=re.M)
    with open(os.path.join(RES, "vein_set_%s_next.tres" % NAME[side]), "w", newline="\n") as fh:
        fh.write(text)
    return ["TRES %s paths %d pack %d" % (side, len(paths), pk)]
