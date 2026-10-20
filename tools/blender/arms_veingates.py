# Copy of .claude/plans/research/hands-blender-review-04/gates.py; edit the research file and re-copy.
"""Gate checker for research 04's vein sets (hand frame s, lat; r chart). Chart fit from survey.txt.

Copied from Temp/vg-hbr/veinfix (D45). Every fail starts "G<n> " (its research 04 gate; G0 = a
data error). check(..., mesh=None) runs Gates 1-8 and 10 on the fit; with a mesh object
(phase 3 spec 2: .chart(side, p) -> (x, v), .weight(side, p) -> max finger/thumb weight of the
nearest skin vertex, .cover(side, chart_pts, r) -> skin vertices within 2.26 r of them) the chart
comes from the mesh and Gate 3's weights and Gate 9 run too. blocking(fails) is the stop rule
(D46): everything except turns <= 35 deg and join angles."""
import math
MESH = None
SPAN = 0.1649
FIT = {"R": ((1.1188, .1655, -.1226), (.0578, -.0130, -.5367)),
       "L": ((1.1176, .1667, -.1244), (-.0578, .0108, .5002))}
HEADS = {"index": (.953, .0526, .0197), "middle": (1.0, 0.0, .0240),
         "ring": (1.009, -.0507, .0194), "pinky": (.842, -.0918, .0172)}
ORDER = ["index", "middle", "ring", "pinky"]


def m(p): return (p[0] * SPAN, p[1])
def chart(side, p):
    if MESH is not None:
        return MESH.chart(side, p)
    (a, b, c), (d, e, f) = FIT[side]
    return (a + b * p[0] + c * p[1], d + e * p[0] + f * p[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def norm(a): return math.hypot(a[0], a[1])
def ang(a, b):
    c = (a[0] * b[0] + a[1] * b[1]) / (norm(a) * norm(b) + 1e-15)
    return math.degrees(math.acos(max(-1, min(1, c))))
def lineang(a, b):
    x = ang(a, b)
    return min(x, 180 - x)
def segdist(p, a, b):
    ab = sub(b, a)
    t = max(0, min(1, ((p[0]-a[0])*ab[0] + (p[1]-a[1])*ab[1]) / (ab[0]**2 + ab[1]**2)))
    q = (a[0] + t * ab[0], a[1] + t * ab[1])
    return norm(sub(p, q)), t
def inter(p1, p2, q1, q2):
    d = (p2[0]-p1[0])*(q2[1]-q1[1]) - (p2[1]-p1[1])*(q2[0]-q1[0])
    if abs(d) < 1e-15:
        return None
    t = ((q1[0]-p1[0])*(q2[1]-q1[1]) - (q1[1]-p1[1])*(q2[0]-q1[0])) / d
    u = ((q1[0]-p1[0])*(p2[1]-p1[1]) - (q1[1]-p1[1])*(p2[0]-p1[0])) / d
    return (t, u) if 0 <= t <= 1 and 0 <= u <= 1 else None


def cords(side):
    out = {k: ((.15 * HEADS[k][0], .15 * HEADS[k][1]), HEADS[k][:2]) for k in ORDER}
    def at(k, t):
        a, b = out[k]
        return (a[0] + t * (b[0]-a[0]), a[1] + t * (b[1]-a[1]))
    rr = {}
    for i, k in enumerate(ORDER):
        nb = [ORDER[j] for j in (i-1, i+1) if 0 <= j < 4]
        def r_at(t):
            sp = min(abs(chart(side, at(k, t))[1] - chart(side, at(n, t))[1]) for n in nb)
            return min(.006, sp / 4.52)
        r5, r1 = r_at(.5), r_at(1.0)
        rr[k] = (lambda t, r5=r5, r1=r1: r5 if t <= .5 else r5 + (t - .5) / .5 * (r1 - r5))
    return out, rr


def samples(side, pts, step=.001):
    out = []
    acc = 0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i+1]
        L = norm(sub(chart(side, b[:2]), chart(side, a[:2])))
        n = max(1, int(L / step))
        for j in range(n):
            t = j / n
            p = (a[0] + t*(b[0]-a[0]), a[1] + t*(b[1]-a[1]))
            out.append((p, chart(side, p), a[2] + t*(b[2]-a[2]), acc + t * L))
        acc += L
    b = pts[-1]
    out.append((b[:2], chart(side, b[:2]), b[2], acc))
    return out


def check(side, P, verbatim_pack, rcord_override=None, mesh=None):
    global MESH
    MESH = mesh
    try:
        return _check(side, P, verbatim_pack, mesh)
    finally:
        MESH = None


def blocking(fails):
    """D46: what stops the phase; turns <= 35 deg and join angles are listed for phase 6."""
    out = []
    for f in fails:
        if f.startswith("G6 ") and " join angle " in f:
            continue
        if f.startswith("G2 ") and float(f.split(" turn ")[1].split()[0]) <= 35:
            continue
        out.append(f)
    return out


def _check(side, P, verbatim_pack, mesh):
    """P: name -> dict(pts, free=(start,end), apex=i, trunk=bool, joins=(trunk, i) for the LAST point,
    first=(trunk, i) when the FIRST point is a join (cross-link), link=bool, arm=n leading fork-arm points)."""
    fails, info = [], []
    cl, rc = cords(side)
    info.append("cord r(.5)/r(1): " + " ".join("%s %.4f/%.4f" % (k, rc[k](.5), rc[k](1)) for k in ORDER))
    def flow(name, i):
        ap = P[name].get("apex")
        return -1 if (ap is not None and i <= ap) else 1
    def down_dir(name, i):
        pts = [m(p) for p in P[name]["pts"]]
        dn = flow(name, i)
        nxt, prv = i + dn, i - dn
        vs = []
        if 0 <= nxt < len(pts):
            vs.append(sub(pts[nxt], pts[i]))
        if 0 <= prv < len(pts) and not (P[name].get("apex") == i):
            vs.append(sub(pts[i], pts[prv]))
        return (sum(v[0] / norm(v) for v in vs), sum(v[1] / norm(v) for v in vs))
    def up_idx(name, i):
        return i - flow(name, i)
    for n, q in P.items():
        pts = [m(p) for p in q["pts"]]
        worst = 0
        for i in range(1, len(pts) - 1):
            t = ang(sub(pts[i], pts[i-1]), sub(pts[i+1], pts[i]))
            worst = max(worst, t)
            if t > 25:
                fails.append("G2 %s turn %.1f at %d" % (n, t, i))
        cw = 9
        for p in q["pts"]:
            for k, (hs, hl, R) in HEADS.items():
                d = norm(sub(m(p), m((hs, hl)))) - R
                cw = min(cw, d)
                if d < 0:
                    fails.append("G3 %s in %s disc by %.4f at %s" % (n, k, -d, p[:2]))
        info.append("%s: turn max %.1f, crest clear min %.4f" % (n, worst, cw))
    murray = {}
    jang = {}
    for n, q in P.items():
        for key, last in (("joins", True), ("first", False)):
            j = q.get(key)
            if not j:
                continue
            tn, ti = j
            tp = P[tn]["pts"][ti]
            me_p = q["pts"][-1] if last else q["pts"][0]
            if norm(sub(m(tp), m(me_p))) > 1e-4:
                fails.append("G0 %s join point off %s[%d]" % (n, tn, ti))
            pts = [m(p) for p in q["pts"]]
            d = sub(pts[-1], pts[-2]) if last else sub(pts[1], pts[0])
            a = ang(d, down_dir(tn, ti))
            jang[(n, key)] = a
            info.append("%s %s %s[%d]: join %.1f" % (n, "into" if last else "from", tn, ti, a))
            if not 20 <= a <= 75:
                fails.append("G6 %s join angle %.1f" % (n, a))
            if last and not q.get("link"):
                murray.setdefault((tn, ti), []).append(me_p[2])
    for (tn, ti), rbs in murray.items():
        rj = P[tn]["pts"][ti][2]
        ru = P[tn]["pts"][up_idx(tn, ti)][2]
        ratio = rj**3 / (ru**3 + sum(r**3 for r in rbs))
        info.append("Murray %s[%d] %.4f^3/(%.4f^3+%s) = %.2f" % (tn, ti, rj, ru, "+".join("%.4f^3" % r for r in rbs), ratio))
        if not .7 <= ratio <= 1.3:
            fails.append("G7 Murray %s[%d] %.2f" % (tn, ti, ratio))
    for n, q in P.items():
        pts = q["pts"]
        for i in range(len(pts)):
            u = up_idx(n, i)
            if 0 <= u < len(pts) and pts[i][2] < pts[u][2] - 1e-9 and (q.get("apex") is not None or q.get("trunk")):
                fails.append("G8 %s r falls downstream at %d" % (n, i))
    S = {n: samples(side, q["pts"]) for n, q in P.items()}
    jp = {}
    for n, q in P.items():
        for key, last in (("joins", True), ("first", False)):
            j = q.get(key)
            if j:
                c = chart(side, (q["pts"][-1] if last else q["pts"][0])[:2])
                # D53: two joining veins stay under 2.26 (ra + rb) for that over sin(angle)
                ra = (q["pts"][-1] if last else q["pts"][0])[2]
                rb = P[j[0]]["pts"][j[1]][2]
                ex = max(.012, 2.26 * (ra + rb) / math.sin(math.radians(max(jang.get((n, key), 90), 1))))
                jp.setdefault(n, []).append((c, ex))
                jp.setdefault(j[0], []).append((c, ex))
    names = list(P)
    for a in range(len(names)):
        for b in range(a + 1, len(names)):
            na, nb = names[a], names[b]
            js = jp.get(na, []) + jp.get(nb, [])
            A = [p for p in S[na] if not any(norm(sub(p[1], j)) < ex for j, ex in js)]
            B = [p for p in S[nb] if not any(norm(sub(p[1], j)) < ex for j, ex in js)]
            worst, wp = 9, None
            for pa in A:
                for pb in B:
                    d = norm(sub(pa[1], pb[1])) - 2.26 * (pa[2] + pb[2])
                    if d < worst:
                        worst, wp = d, (tuple(round(x, 3) for x in pa[0]), tuple(round(x, 3) for x in pb[0]))
            if worst < 0:
                fails.append("G4 sep %s-%s short %.4f at %s" % (na, nb, -worst, wp))
            elif worst < .002:
                info.append("sep %s-%s margin %.4f" % (na, nb, worst))
    for n, q in P.items():
        pts = q["pts"]
        for k in ORDER:
            a, b = cl[k]
            ca, cb = chart(side, a), chart(side, b)
            xs = []
            for i in range(len(pts) - 1):
                if inter(m(pts[i]), m(pts[i+1]), m(a), m(b)):
                    xs.append((i, lineang(sub(m(pts[i+1]), m(pts[i])), sub(m(b), m(a)))))
            for i, x in xs:
                info.append("%s crosses %s seg %d at %.1f deg" % (n, k, i, x))
                if x < 30:
                    fails.append("G5 %s crosses %s at %.1f" % (n, k, x))
            if len(xs) > 1:
                fails.append("G5 %s crosses %s %d times" % (n, k, len(xs)))
            bad, worst = [], 9
            for p, c, r, _ in S[n]:
                d, t = segdist(c, ca, cb)
                g = d - (rc[k](t) + r)
                if g < 0:
                    bad.append(p)
                worst = min(worst, g)
            if bad and not xs:
                fails.append("G5 %s in %s band by %.4f near %s" % (n, k, -worst, tuple(round(x, 3) for x in bad[len(bad)//2])))
            elif not xs and worst < .0015:
                info.append("%s off %s band margin %.4f" % (n, k, worst))
    pack = verbatim_pack
    for n, q in P.items():
        L = S[n][-1][3]
        fl = q.get("free", (0, 0))
        pack += len(q["pts"]) + 1 + (2 * (fl[0] + fl[1]) if L > .036 else 0)
    info.append("pack %d (verbatim %d)" % (pack, verbatim_pack))
    if pack > 160:
        fails.append("G1 pack %d" % pack)
    for n, q in P.items():  # Gate 8b: r at s -.30 and beyond >= the trunk's max on the hand
        if q.get("apex") is None and not q.get("trunk"):
            continue
        pts = q["pts"]
        top = max(p[2] for p in pts if p[0] > -.30 + 1e-9)
        for i, p in enumerate(pts):
            if p[0] <= -.30 + 1e-9 and p[2] < top - 1e-9:
                fails.append("G8 %s r %.4f at %d under the hand max %.4f" % (n, p[2], i, top))
    for n, q in P.items():  # Gate 10 (D47), metres in the (s x span, lat) plane
        pts = [m(p) for p in q["pts"]]
        if len(pts) < 3 or q.get("link"):
            continue
        idx = range(max(1, q.get("arm", 0) + 1), len(pts) - 1)
        if not idx:
            continue
        good = 0
        for i in idx:
            h = segdist(pts[i], pts[i-1], pts[i+1])[0]
            d = norm(sub(pts[i+1], pts[i-1]))
            if h > .005:
                fails.append("G10 %s %d off %.1f mm > 5" % (n, i, h * 1000))
            elif h >= .002:
                good += 1
            elif d >= .018:
                fails.append("G10 %s %d off %.1f mm < 2 with neighbours %.0f mm apart" % (n, i, h * 1000, d * 1000))
        if not good:
            fails.append("G10 %s no meander point" % n)
    if mesh is None:
        info.append("G3 weights, G9 cover: not checked (fit; spec 2 runs them on the mesh)")
        return fails, info
    for n, q in P.items():  # Gate 3 weights and Gate 9 cover, mesh only
        pts, fl, arm = q["pts"], q.get("free", (0, 0)), q.get("arm", 0)
        for i, p in enumerate(pts):
            lim = .25 if (i < arm or (i == 0 and fl[0]) or (i == len(pts) - 1 and fl[1])) else .5
            w = mesh.weight(side, p[:2])
            if w >= lim:
                fails.append("G3 %s %d weight %.2f >= %.2f" % (n, i, w, lim))
        sl = {}
        for p, c, r, acc in samples(side, pts):
            sl.setdefault(int(acc / .004), []).append((c, r))
        for k, v in sl.items():
            c = mesh.cover(side, [x[0] for x in v], max(x[1] for x in v))
            if c < 6:
                fails.append("G9 %s slice %d cover %d < 6" % (n, k, c))
    return fails, info
