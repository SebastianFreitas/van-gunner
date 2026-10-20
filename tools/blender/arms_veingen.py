"""Seeded organic vein generator: writes resources/arms/vein_set_<side>_next.tres (pure Python).

Veins are grown in the hand frame of arms_veingates (X = s * SPAN metres along the hand, Y = lat, the
thumb side +) and mapped to the skin chart with its fit. Per side: a dorsal arch across the
metacarpals, tributaries to the knuckle gaps (some fork), three forearm veins (cephalic, median,
basilic) with cross-links, a few side twigs and one faint palm vein. Spline-smoothed meander,
uneven spacing, radius taper and noise, free ends at every tip. Same seed gives the same bytes.
"""
import math
import pathlib
import random

from arms_veingates import HEADS, SPAN, blocking, chart, check
from arms_veinsplice import PALM

ROOT = pathlib.Path(__file__).resolve().parents[2]
SEEDS = {"R": 23, "L": 11}
FADE_LEN = 0.012  # ArmVeinSet.FADE_LEN
VEIN_MAX = 512  # ArmMaterials.VEIN_MAX
MAX_TURN = 30.0  # degrees per segment in the chart
R_MIN, R_MAX = 0.0006, 0.0025
MED_ARCH_Y = (-.014, -.010)  # lat of the median vein's start on the arch (the middle-ring gap)
MED_END_Y = (-.045, -.035)  # lat of its far end, ulnar of the pinky cord
FORK_ANG = (10, 20)  # degrees: fork twigs stay inside the gap between cords
SIDE_ANG = (50, 75)  # degrees: forearm side twigs leave their parent steeply
SIDE_LEN = (.025, .045)


def smooth(t):
    return t * t * (3 - 2 * t)


def spline(ctrl, rng, step=0.011):
    """Catmull-Rom through ctrl, resampled at uneven arc steps; ends are exact."""
    c = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    c[0] = (2 * ctrl[0][0] - ctrl[1][0], 2 * ctrl[0][1] - ctrl[1][1])
    c[-1] = (2 * ctrl[-1][0] - ctrl[-2][0], 2 * ctrl[-1][1] - ctrl[-2][1])
    dense = []
    for i in range(1, len(c) - 2):
        p0, p1, p2, p3 = c[i - 1], c[i], c[i + 1], c[i + 2]
        for k in range(40):
            t = k / 40
            dense.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t
                                      + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                      + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    dense.append(ctrl[-1])
    return resample(dense, rng, step)


def resample(dense, rng, step):
    out = [dense[0]]
    want = step * rng.uniform(0.7, 1.3)
    acc = 0.0
    for a, b in zip(dense, dense[1:]):
        acc += math.dist(a, b)
        if acc >= want:
            out.append(b)
            acc = 0.0
            want = step * rng.uniform(0.7, 1.3)
    if out[-1] != dense[-1]:
        if len(out) > 2 and math.dist(out[-1], dense[-1]) < step * 0.4:
            out.pop()
        out.append(dense[-1])
    return out


def meander_run(x0, y0, x1, y1, rng, joined_start=True, bend=0.0, amp=1.0):
    """Vein from (x0, y0) to (x1, y1) as y(x): a smooth blend plus two low-frequency waves."""
    n = max(8, int(abs(x1 - x0) / 0.012))
    a1, l1, f1 = rng.uniform(.004, .006), rng.uniform(.13, .2), rng.uniform(0, 6.28)
    a2, l2, f2 = rng.uniform(.0012, .0025), rng.uniform(.06, .09), rng.uniform(0, 6.28)
    xs = sorted({x0 + (x1 - x0) * k / n + rng.uniform(-.2, .2) * (x1 - x0) / n * (0 < k < n)
                 for k in range(n + 1)}, reverse=x1 < x0)
    pts = []
    for x in xs:
        u = (x - x0) / (x1 - x0)
        taper = smooth(min(1.0, abs(x - x0) / 0.05)) if joined_start else 1.0
        y = y0 + (y1 - y0) * smooth(u) + bend * (1 - (1 - u) ** 2) * (1 - u)
        y += amp * taper * (a1 * math.sin(6.283 * x / l1 + f1) + a2 * math.sin(6.283 * x / l2 + f2))
        pts.append((x, y))
    pts[0], pts[-1] = (x0, y0), (pts[-1][0], pts[-1][1])
    return pts


def radii(pts, r0, r1, rng):
    total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:])) or 1e-9
    ph, acc, out = rng.uniform(0, 6.28), 0.0, []
    for k, p in enumerate(pts):
        if k:
            acc += math.dist(pts[k - 1], p)
        r = r0 + (r1 - r0) * (acc / total)
        out.append(round(max(R_MIN, min(R_MAX, r * (1 + 0.1 * math.sin(ph + acc * 90) + rng.uniform(-.07, .07)))), 5))
    return out


def in_disc(p, margin=0.0012):
    for hs, hl, r in HEADS.values():
        if math.dist(p, (hs * SPAN, hl)) < r + margin:
            return True
    return False


def trim_discs(pts):
    """Cut a junction-first branch at the first point that touches a finger head disc."""
    for k, p in enumerate(pts):
        if in_disc(p):
            return pts[:k]
    return pts


def nearest(pts, y=None, x=None):
    key = (lambda p: abs(p[1] - y)) if y is not None else (lambda p: abs(p[0] - x))
    return min(range(len(pts)), key=lambda k: key(pts[k]))


def build(side, seed):
    rng = random.Random(seed)
    P = []  # dicts: n, pts (hand frame), r0, r1, free (bit 1 start, 2 end)

    def add(n, pts, r0, r1, free, joins=None, first=None, link=False):
        """joins = (path, index) the last point sits on, first = the same for the first point."""
        P.append(dict(n=n, pts=pts, r=radii(pts, r0, r1, rng), free=free, joins=joins, first=first, link=link))
        return pts

    # Dorsal arch, radial end first: bows distally, its ends run along the hand axis.
    ts = [k / 12 for k in range(13)]
    top = rng.uniform(.56, .62)
    ctrl = [((.44 + (top - .44) * math.sin(math.pi * t) ** .9 + rng.uniform(-.006, .006) * (0 < t < 1)) * SPAN,
             .070 - t * .160 + rng.uniform(-.0015, .0015) * (0 < t < 1)) for t in ts]
    arch = add("arch", spline(ctrl, rng, .0055), .0017, .0014, 0)
    # Tributaries to the knuckle gaps (and the thumb web), each from a fork point F to the arch.
    gaps = [(.082, .60), (.021, .76), (-.0196, .78), (-.057, .72)]  # centres between the finger cords
    forks = rng.sample(range(4), rng.choice((2, 3)))
    attach_used = []
    for i, (gl, gs) in enumerate(gaps):
        F = ((gs + rng.uniform(-.02, .02)) * SPAN, gl + rng.uniform(-.002, .002))
        j = nearest(arch, y=F[1] * .52 / gs + rng.uniform(-.002, .002))  # runs down the gap between cords
        while j in attach_used or j + 1 in attach_used or j - 1 in attach_used:
            j = min(len(arch) - 2, max(1, j + rng.choice((-2, 2))))
        attach_used.append(j)
        A = arch[j]
        mid = [(F[0] + (A[0] - F[0]) * f + rng.uniform(-.001, .001), F[1] + (A[1] - F[1]) * f + rng.uniform(-.001, .001))
               for f in (.35, .68)]
        tpts = add("trib%d" % i, spline([F] + mid + [A], rng, .007), .0010, .0013, 0, joins=("arch", j))
        if i in forks:
            for sgn in (1, -1):
                ang = math.atan2(gl, gs * SPAN) + math.radians(rng.uniform(*FORK_ANG)) * sgn  # fanned like the cords
                ln = rng.uniform(.02, .03)
                d = (math.cos(ang), math.sin(ang))
                tip = (F[0] + d[0] * ln, F[1] + d[1] * ln)
                tw = trim_discs(spline([F, (F[0] + d[0] * ln * .5, F[1] + d[1] * ln * .5 + rng.uniform(-.002, .002)), tip], rng, .008))
                if len(tw) >= 3:
                    add("twig%d%s" % (i, "ab"[sgn < 0]), tw[::-1], .0007, .0009, 1, joins=("trib%d" % i, 0))
        else:
            dx = rng.uniform(.012, .022)
            tip = (F[0] + dx, F[1] + dx * gl / (gs * SPAN) + rng.uniform(-.003, .003))
            tw = trim_discs(spline([F, ((F[0] + tip[0]) / 2, (F[1] + tip[1]) / 2), tip], rng, .008))
            if len(tw) >= 3:
                add("tip%d" % i, tw[::-1], .0007, .0010, 1, joins=("trib%d" % i, 0))
    # Forearm veins drain the arch; X goes negative toward the elbow.
    mj = nearest(arch, y=rng.uniform(*MED_ARCH_Y))
    xs_end = [-rng.uniform(1.25, 1.5) * SPAN for _ in range(3)]
    fa = {}
    fa["ceph"] = add("ceph", meander_run(arch[0][0], arch[0][1], xs_end[0], rng.uniform(.035, .06), rng), .0022, .0018, 2, first=("arch", 0))
    # The median vein leaves its gap and crosses the ring and pinky cords once each, steeply (G5).
    A = arch[mj]
    dive = [A, (A[0] - .02, A[1] - .022 + rng.uniform(-.002, .002)), (A[0] - .045, A[1] - .045 + rng.uniform(-.002, .002)),
            (A[0] - .08, A[1] - .056 + rng.uniform(-.002, .002))]
    head = spline(dive, rng, .011)
    tail = meander_run(head[-1][0], head[-1][1], xs_end[1], rng.uniform(*MED_END_Y), rng)
    fa["med"] = add("med", head + tail[1:], .0017, .0014, 2, first=("arch", mj))
    fa["bas"] = add("bas", meander_run(arch[-1][0], arch[-1][1], xs_end[2], rng.uniform(-.085, -.065), rng), .0021, .0017, 2, first=("arch", len(arch) - 1))
    # Cross-links between neighbouring forearm veins (one or two) and side twigs.
    def link(name, na, nb, a, b, xa, xb):
        ia, ib = nearest(a, x=xa), nearest(b, x=xb)
        pa, pb = a[ia], b[ib]
        d = (pb[0] - pa[0], pb[1] - pa[1])
        nrm = (-d[1], d[0])
        ln = math.hypot(*nrm) or 1
        s1, s2 = rng.uniform(.0005, .001), rng.uniform(.0005, .001)
        c = [pa, (pa[0] + d[0] * .33 + nrm[0] / ln * s1, pa[1] + d[1] * .33 + nrm[1] / ln * s1),
             (pa[0] + d[0] * .67 - nrm[0] / ln * s2, pa[1] + d[1] * .67 - nrm[1] / ln * s2), pb]
        add(name, spline(c, rng, .012), .0010, .0010, 0, joins=(nb, ib), first=(na, ia), link=True)
    link("x1", "ceph", "med", fa["ceph"], fa["med"], -rng.uniform(.5, .7) * SPAN, -rng.uniform(.8, 1.0) * SPAN)
    xm = -rng.uniform(.5, .9) * SPAN
    link("x2", "med", "bas", fa["med"], fa["bas"], xm, xm + rng.uniform(-.1, .1) * SPAN)
    for k, nm in enumerate(rng.sample(["ceph", "med", "bas", "ceph", "bas"], 4)):
        par = fa[nm]
        j = rng.randrange(6, len(par) - 5)
        ang = math.radians(rng.uniform(*SIDE_ANG))
        sgn = {"ceph": 1, "bas": -1}.get(nm, 1)  # outward, away from the neighbour vein
        ln = rng.uniform(*SIDE_LEN)
        tip = (par[j][0] + ln * math.cos(ang), par[j][1] + sgn * ln * math.sin(ang))
        mid = (par[j][0] + ln * .5 * math.cos(ang), par[j][1] + sgn * ln * .5 * math.sin(ang) + rng.uniform(-.003, .003))
        add("side%d" % k, spline([par[j], mid, tip], rng, .009)[::-1], .0007, .0010, 1, joins=(nm, j))
    # Network cross-connections between neighbouring tributaries.
    ids = [p for p in P if p["n"].startswith("trib")]
    for a, b in zip(ids, ids[1:]):
        if rng.random() < .55:
            ja, jb = nearest(a["pts"], x=(.74 + rng.uniform(-.02, .02)) * SPAN), nearest(b["pts"], x=(.74 + rng.uniform(-.02, .02)) * SPAN)
            pa, pb = a["pts"][ja], b["pts"][jb]
            add("net%d" % len(P), spline([pa, ((pa[0] + pb[0]) / 2 + rng.uniform(-.003, .003), (pa[1] + pb[1]) / 2 + rng.uniform(-.003, .003)), pb], rng, .008), .0008, .0008, 0, joins=(b["n"], jb), first=(a["n"], ja), link=True)
    for p in P:  # a fork stem nothing grows from ends free
        if p["n"].startswith("trib") and not any(o is not p and p["pts"][0] in o["pts"] for o in P):
            p["free"] |= 1
    # The faint palm veins come first: the readers (arms_veins_bl, arms_relief_bl) skip the first
    # len(PALM[side]) paths of a _next set as the baked palm paths, so write exactly that many.
    # Palm side is right -v, left +v.
    sg = -1 if side == "R" else 1
    out = []
    for k in range(len(PALM[side])):
        pp = meander_run(1.10, sg * (.055 + .02 * (k - 1)), .90 + .02 * k, sg * (rng.uniform(.045, .06) + .02 * (k - 1)),
                         rng, joined_start=False, amp=.5)
        pp = [(round(x, 4), round(y, 4)) for x, y in pp]
        out.append(dict(n="palm%d" % k, free=3, pts=[(x, y, r) for (x, y), r in zip(pp, radii(pp, .0010, .0008, rng))]))
    # Mapped to the chart; hand keeps the (s, lat, r) points arms_veingates.check reads.
    for p in P:
        out.append(dict(n=p["n"], free=p["free"], joins=p["joins"], first=p["first"], link=p["link"],
                        hand=[(x / SPAN, y, r) for (x, y), r in zip(p["pts"], p["r"])],
                        pts=[(*[round(c, 4) for c in chart(side, (x / SPAN, y))], r) for (x, y), r in zip(p["pts"], p["r"])]))
    return out


def packed_count(paths):
    n = 0
    for p in paths:
        pts = p["pts"]
        tot = sum(math.dist(a[:2], b[:2]) for a, b in zip(pts, pts[1:]))
        n += len(pts) + 1 + (2 * ((p["free"] & 1) + (p["free"] >> 1)) if tot > FADE_LEN * 3 else 0)
    return n


def gates(side, paths):
    """Returns the list of failures."""
    f = []
    allp = [q[:2] for p in paths for q in p["pts"]]
    for p in paths:
        pts = p["pts"]
        if len(pts) < 3:
            f.append("%s: under 3 points" % p["n"])
        for a, b, c in zip(pts, pts[1:], pts[2:]):
            u, v = (b[0] - a[0], b[1] - a[1]), (c[0] - b[0], c[1] - b[1])
            den = (math.hypot(*u) * math.hypot(*v)) or 1e-12
            t = math.degrees(math.acos(max(-1, min(1, (u[0] * v[0] + u[1] * v[1]) / den))))
            if t > MAX_TURN:
                f.append("%s: turn %.1f at (%.3f,%.3f)" % (p["n"], t, b[0], b[1]))
        for q in pts:
            if not (R_MIN <= q[2] <= R_MAX) or not (0.78 < q[0] < 1.34) or abs(q[1]) > .13:
                f.append("%s: point out of range %s" % (p["n"], q))
        for end, bit in ((0, 1), (-1, 2)):  # a joined end must sit on another path
            if not p["free"] & bit and "hand" in p:
                e = pts[end][:2]
                if not any(e == q[:2] for o in paths if o is not p for q in o["pts"]):
                    f.append("%s: joined end %d floats" % (p["n"], end))
    if packed_count(paths) > VEIN_MAX * 0.7:
        f.append("packed %d over 70 percent of %d" % (packed_count(paths), VEIN_MAX))
    # The hand-frame gates of arms_veingates (G2-G7, G10) on the generated paths; the palm paths are
    # chart-only. Not applied: G1 (its 160 cap is stale, the pack check above uses VEIN_MAX) and the
    # join angle and the 25-35 degree turn band, which blocking() leaves out as phase-6 notes.
    P = {p["n"]: dict(pts=p["hand"], free=(p["free"] & 1, p["free"] >> 1), joins=p["joins"], first=p["first"],
                      link=p["link"]) for p in paths if "hand" in p}
    # G7 (Murray) is left out: its flow model has one apex per path and reads a fork stem's upstream
    # point as the path's last point, and these radii are a taper with noise, not derived from branch cubes.
    # G10 keeps only its too-wiggly (> 5 mm) check: its 2 mm minimum asks the old sparse pattern for a
    # zigzag at every point, which a dense smooth spline (points 11 mm apart) cannot show.
    f += [x for x in blocking(check(side, P, 0)[0]) if not x.startswith(("G1 ", "G7 "))
          and not (x.startswith("G10 ") and ("< 2 " in x or "no meander" in x))]
    return f


def write(side, paths):
    name = "left" if side == "L" else "right"
    body = ", ".join("PackedVector3Array(%s)" % ", ".join("%.4f, %.4f, %.5f" % q for q in p["pts"]) for p in paths)
    text = ('[gd_resource type="Resource" script_class="ArmVeinSet" load_steps=2 format=3]\n\n'
            '[ext_resource type="Script" path="res://scripts/player/arms/arm_vein_set.gd" id="1_veinset"]\n\n'
            '[resource]\nscript = ExtResource("1_veinset")\n'
            "paths = Array[PackedVector3Array]([%s])\n" % body
            + "free_ends = PackedInt32Array(%s)\n" % ", ".join(str(p["free"]) for p in paths))
    path = ROOT / "resources" / "arms" / ("vein_set_%s_next.tres" % name)
    path.write_bytes(text.encode())
    return path


def preview(sets, out_dir):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(2, 1, figsize=(14, 10))
    for ax, side in zip(axes, "LR"):
        for p in sets[side]:
            pts = p["pts"]
            for a, b in zip(pts, pts[1:]):
                ax.plot([a[0], b[0]], [a[1], b[1]], color="#2a6f8c", lw=a[2] * 1500, solid_capstyle="round")
            ax.plot(pts[0][0], pts[0][1], ".", color="red" if p["free"] & 1 else "k", ms=3)
            ax.plot(pts[-1][0], pts[-1][1], ".", color="red" if p["free"] & 2 else "k", ms=3)
        for hs, hl, r in HEADS.values():
            cx, cy = chart(side, (hs, hl))
            ax.add_patch(plt.Circle((cx, cy), r, fill=False, color="#999"))
        ax.set_title("%s arm chart (x along arm, v around); red = free end" % ("left" if side == "L" else "right"))
        ax.set_aspect("equal")
        ax.set_xlim(0.8, 1.34)
    fig.tight_layout()
    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    fig.savefig(out / "veingen_preview.png", dpi=110)
    return out / "veingen_preview.png"


def main(argv):
    sets, bad = {}, 0
    for side in "LR":
        paths = build(side, SEEDS[side])
        sets[side] = paths
        fails = gates(side, paths)
        pts = [q for p in paths for q in p["pts"]]
        forks = sum(1 for p in paths if p["n"].startswith("twig"))
        print("%s %s: %d paths, %d points, packed %d of %d, %d twig forks, r %.5f-%.5f, gate fails %d"
              % (side, write(side, paths).name, len(paths), len(pts), packed_count(paths), VEIN_MAX, forks // 2,
                 min(q[2] for q in pts), max(q[2] for q in pts), len(fails)))
        for x in fails[:12]:
            print("  FAIL", x)
        bad += len(fails)
    if argv:
        print("preview", preview(sets, argv[0]))
    print("RESULT veingen: ok" if not bad else "RESULT veingen: FAIL %d gate fails" % bad)
    return 1 if bad else 0
